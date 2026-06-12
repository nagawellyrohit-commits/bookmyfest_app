import 'package:flutter/material.dart';

import '../services/api_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() =>
      _UsersScreenState();
}

class _UsersScreenState
    extends State<UsersScreen> {

  final ApiService apiService =
      ApiService();

  late Future<List<dynamic>>
      usersFuture;

  @override
  void initState() {
    super.initState();

    usersFuture =
        apiService.getUsers();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Users",
        ),
      ),

      body: FutureBuilder(
        future: usersFuture,

        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {

            return const Center(
              child:
                  Text("Error"),
            );
          }

          final users =
              snapshot.data!;

          return ListView.builder(
            itemCount: users.length,

            itemBuilder:
                (context, index) {

              return ListTile(
                title: Text(
                  users[index]['name'],
                ),

                subtitle: Text(
                  users[index]['email'],
                ),
              );
            },
          );
        },
      ),
    );
  }
}