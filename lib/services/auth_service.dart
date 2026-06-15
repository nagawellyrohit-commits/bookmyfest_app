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
        body: jsonEncode({"email": email.trim(), "password": password}),
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
    String? studentId,
    String? businessName,
    String? description,
    String? contactPhone,
    String? websiteUrl,
    String? instagramUrl,
    String? linkedinUrl,
    String? branch,
    int? passingYear,
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
        "resumeUrl": ?resumeUrl?.trim(),
        if (role == 'student' && studentId != null)
          "studentId": studentId.trim(),
        "businessName": ?businessName?.trim(),
        "description": ?description?.trim(),
        "contactPhone": ?contactPhone?.trim(),
        "websiteUrl": ?websiteUrl?.trim(),
        "instagramUrl": ?instagramUrl?.trim(),
        "linkedinUrl": ?linkedinUrl?.trim(),
        "branch": ?branch?.trim(),
        "passingYear": ?passingYear,
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

  // Delete a coordinator (Faculty Admin / Super Admin)
  Future<void> deleteCoordinator(String token, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/auth/coordinators/$userId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(
          responseData['message'] ?? 'Failed to delete coordinator',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Get pending faculties (Super Admin only)
  Future<List<dynamic>> getPendingFaculties(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth/pending-faculties"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(
        responseData['message'] ?? 'Failed to load pending faculties',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Approve a faculty admin (Super Admin only)
  Future<void> verifyFaculty(String token, String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/faculties/$userId/verify"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to verify faculty');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Get current user profile details
  Future<Map<String, dynamic>> getMe(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth/me"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(responseData['message'] ?? 'Failed to get profile');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update student profile
  Future<Map<String, dynamic>> updateProfile(
    String token, {
    required String fullName,
    required String phone,
    required String department,
    String? studentId,
    String? resumeUrl,
    String? businessName,
    String? description,
    String? contactPhone,
    String? websiteUrl,
    String? instagramUrl,
    String? linkedinUrl,
    String? branch,
    int? passingYear,
  }) async {
    try {
      final payload = {
        "fullName": fullName.trim(),
        "phone": phone.trim(),
        "department": department.trim(),
        "studentId": ?studentId?.trim(),
        "resumeUrl": ?resumeUrl?.trim(),
        "businessName": ?businessName?.trim(),
        "description": ?description?.trim(),
        "contactPhone": ?contactPhone?.trim(),
        "websiteUrl": ?websiteUrl?.trim(),
        "instagramUrl": ?instagramUrl?.trim(),
        "linkedinUrl": ?linkedinUrl?.trim(),
        "branch": ?branch?.trim(),
        "passingYear": ?passingYear,
      };

      final response = await http.put(
        Uri.parse("$baseUrl/auth/me/profile"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData;
      }
      throw Exception(responseData['message'] ?? 'Failed to update profile');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
