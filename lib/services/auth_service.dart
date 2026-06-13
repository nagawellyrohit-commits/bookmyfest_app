import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Use localhost:5001 for Web/iOS Simulator.
  // For Android emulator, you can change this to http://10.0.2.2:5001/api
  static const String baseUrl = "http://localhost:5001/api";

  // Login a user
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "password": password,
        }),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to log in');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Register a user
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String role,
    required String collegeName,
    required String department,
    required String idProofUrl,
    required bool isFinalYear,
    String? resumeUrl,
  }) async {
    try {
      final payload = {
        "fullName": fullName.trim(),
        "email": email.trim(),
        "password": password,
        "phone": phone.trim(),
        "role": role,
        "collegeName": collegeName.trim(),
        "department": department.trim(),
        "idProofUrl": idProofUrl.trim(),
        "isFinalYear": isFinalYear,
        if (isFinalYear && resumeUrl != null) "resumeUrl": resumeUrl.trim(),
      };

      final response = await http.post(
        Uri.parse("$baseUrl/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201 && responseData['success'] == true) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to register');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Get pending coordinators (Faculty Admin)
  Future<List<dynamic>> getPendingCoordinators(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth/pending-coordinators"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(responseData['message'] ?? 'Failed to load coordinators');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Approve a coordinator (Faculty Admin)
  Future<void> verifyCoordinator(String token, String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/coordinators/$userId/verify"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Verification failed');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
