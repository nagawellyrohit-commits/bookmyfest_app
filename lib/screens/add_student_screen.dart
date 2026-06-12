import 'package:flutter/material.dart';
import '../models/student.dart';

class AddStudentScreen extends StatefulWidget {
  final Student? student;

  const AddStudentScreen({
    super.key,
    this.student,
  });

  @override
  State<AddStudentScreen> createState() =>
      _AddStudentScreenState();
}

class _AddStudentScreenState
    extends State<AddStudentScreen> {

  final nameController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.student != null) {
      nameController.text = widget.student!.name;
      emailController.text = widget.student!.email;
    }
  }

  void saveStudent() {
    Student student = Student(
      name: nameController.text,
      email: emailController.text,
    );

    Navigator.pop(context, student);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.student == null
              ? "Add Student"
              : "Edit Student",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Name",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: saveStudent,
              child: Text(
                widget.student == null
                    ? "Save"
                    : "Update",
              ),
            ),
          ],
        ),
      ),
    );
  }
}