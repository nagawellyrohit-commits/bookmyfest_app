import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static const String baseUrl =
      "https://jsonplaceholder.typicode.com";

  Future<List<dynamic>> getUsers() async {

    final response =
        await http.get(
      Uri.parse(
        "$baseUrl/users",
      ),
    );

    if (response.statusCode == 200) {

      return jsonDecode(
        response.body,
      );
    }

    throw Exception(
      "Failed to load users",
    );
  }
}