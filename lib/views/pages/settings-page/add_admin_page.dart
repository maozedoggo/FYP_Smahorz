import 'package:flutter/material.dart';

class AddAdminPage extends StatelessWidget {
  final List<String> members;
  const AddAdminPage({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 240, 241),
      appBar: AppBar(title: const Text("Vote for Admin")),
      body: ListView.builder(
        itemCount: members.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(members[index]),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, members[index]);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Vote"),
              ),
            ),
          );
        },
      ),
    );
  }
}
