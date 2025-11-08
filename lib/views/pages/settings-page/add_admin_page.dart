import 'package:flutter/material.dart';

class AddAdminPage extends StatelessWidget {
  final List<String> members; // list of member emails
  const AddAdminPage({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 240, 241),
      appBar: AppBar(title: const Text("Promote Member to Admin")),
      body: members.isEmpty
          ? const Center(child: Text("No members available to promote."))
          : ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final uid = members[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: FutureBuilder(
                      future: Future.microtask(() => true).then(
                        (_) => uid,
                      ), // placeholder - we return email immediately
                      builder: (context, snapshot) {
                        // If you want to show username instead of UID, you can fetch user doc here.
                        return Text(uid);
                      },
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        // Return selected UID back to caller for promotion
                        Navigator.pop(context, uid);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text("Promote"),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
