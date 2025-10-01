import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _photoUrl;
  File? _newImageFile;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email == null) return;

    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance.collection('users').doc(email).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _nameController.text = data['name'] ?? '';
          _emailController.text = email;
          _photoUrl = data['photoUrl'];
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User document not found!")),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      debugPrint("Error loading profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading profile: $e")),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final currentEmail = user.email ?? '';
    String? imageUrl = _photoUrl;

    try {
      // Upload new profile picture if selected
      if (_newImageFile != null) {
        final ref =
            FirebaseStorage.instance.ref().child('profilePictures/$currentEmail.jpg');
        await ref.putFile(_newImageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      // If email changed → handle carefully
      final newEmail = _emailController.text.trim();
      if (newEmail != currentEmail) {
        try {
          await user.updateEmail(newEmail);

          // Move Firestore doc to new email ID
          final oldDoc = FirebaseFirestore.instance.collection('users').doc(currentEmail);
          final newDoc = FirebaseFirestore.instance.collection('users').doc(newEmail);

          final snapshot = await oldDoc.get();
          if (snapshot.exists) {
            await newDoc.set({
              ...snapshot.data() as Map<String, dynamic>,
              'username': _usernameController.text.trim(),
              'name': _nameController.text.trim(),
              'photoUrl': imageUrl,
            });
            await oldDoc.delete();
          }
        } catch (e) {
          debugPrint("Error updating email: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Please re-login to update your email.")),
            );
          }
          return;
        }
      } else {
        // Just update existing Firestore doc
        await FirebaseFirestore.instance.collection('users').doc(currentEmail).update({
          'username': _usernameController.text.trim(),
          'name': _nameController.text.trim(),
          'photoUrl': imageUrl,
        });
      }

      if (mounted) {
        Navigator.pop(context, {
          'username': _usernameController.text.trim(),
          'name': _nameController.text.trim(),
          'photoUrl': imageUrl,
        });
      }
    } catch (e) {
      debugPrint("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving profile: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(title: const Text("Edit Profile")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _newImageFile != null
                              ? FileImage(_newImageFile!)
                              : (_photoUrl != null
                                  ? NetworkImage(_photoUrl!)
                                  : null),
                          backgroundColor: Colors.grey[300],
                          child: (_photoUrl == null && _newImageFile == null)
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: "Username",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Name",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "Required";
                        if (!v.contains('@')) return "Enter valid email";
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save Changes"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
