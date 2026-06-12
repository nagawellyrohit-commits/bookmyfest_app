import 'package:flutter/material.dart';
import '../models/student.dart';
import 'add_student_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Student> students = [];

  void addStudent(Student student) {
    setState(() {
      students.add(student);
    });
  }

  void editStudent(int index, Student student) {
    setState(() {
      students[index] = student;
    });
  }

  void deleteStudent(int index) {
    setState(() {
      students.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student App")),
      body: students.isEmpty
          ? const Center(child: Text("No Students Added"))
          : ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    title: Text(students[index].name),
                    subtitle: Text(students[index].email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final updatedStudent = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddStudentScreen(student: students[index]),
                              ),
                            );

                            if (updatedStudent != null) {
                              editStudent(index, updatedStudent);
                            }
                          },
                        ),

                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            deleteStudent(index);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final student = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddStudentScreen()),
          );

          if (student != null) {
            addStudent(student);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
