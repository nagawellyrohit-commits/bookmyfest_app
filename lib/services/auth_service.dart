import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:student_app/config/api_config.dart';

class AuthService {
  static String get baseUrl => ApiConfig.baseUrl;

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
    bool? isParent,
    String? parentStudentName,
    String? parentStudentCollege,
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
        "resumeUrl": resumeUrl?.trim(),
        if (role == 'student' && studentId != null)
          "studentId": studentId.trim(),
        "businessName": businessName?.trim(),
        "description": description?.trim(),
        "contactPhone": contactPhone?.trim(),
        "websiteUrl": websiteUrl?.trim(),
        "instagramUrl": instagramUrl?.trim(),
        "linkedinUrl": linkedinUrl?.trim(),
        "branch": branch?.trim(),
        "passingYear": passingYear,
        "isParent": isParent ?? false,
        "parentStudentName": parentStudentName?.trim(),
        "parentStudentCollege": parentStudentCollege?.trim(),
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
        "studentId": studentId?.trim(),
        "resumeUrl": resumeUrl?.trim(),
        "businessName": businessName?.trim(),
        "description": description?.trim(),
        "contactPhone": contactPhone?.trim(),
        "websiteUrl": websiteUrl?.trim(),
        "instagramUrl": instagramUrl?.trim(),
        "linkedinUrl": linkedinUrl?.trim(),
        "branch": branch?.trim(),
        "passingYear": passingYear,
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

  // Upload a PDF file to the backend
  Future<String> uploadPdf(List<int> fileBytes, String fileName) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/auth/upload"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType('application', 'pdf'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['fileUrl'];
      } else {
        throw Exception(responseData['message'] ?? 'Failed to upload PDF');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Upload an image file to the backend
  Future<String> uploadImage(List<int> fileBytes, String fileName) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/auth/upload-image"),
      );

      // Determine content type based on extension
      String mimeSub = 'jpeg';
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.png')) {
        mimeSub = 'png';
      } else if (lowerName.endsWith('.webp')) {
        mimeSub = 'webp';
      } else if (lowerName.endsWith('.gif')) {
        mimeSub = 'gif';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', mimeSub),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['fileUrl'];
      } else {
        throw Exception(responseData['message'] ?? 'Failed to upload image');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Forgot Password - Step 1: Send Verification Code
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email.trim()}),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to send reset code');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Forgot Password - Step 2: Verify Code
  Future<Map<String, dynamic>> verifyResetCode(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/verify-reset-code"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email.trim(), "code": code.trim()}),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Invalid code or verification failed');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Forgot Password - Step 3: Reset Password
  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "code": code.trim(),
          "newPassword": newPassword,
        }),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
