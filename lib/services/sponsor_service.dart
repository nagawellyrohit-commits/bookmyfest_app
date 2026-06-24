import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:student_app/config/api_config.dart';

class SponsorService {
  static String get baseUrl => ApiConfig.baseUrl;

  // Fetch all sponsors (public endpoint)
  Future<List<dynamic>> fetchSponsors() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/sponsors"),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      } else {
        throw Exception(responseData['message'] ?? 'Failed to load sponsors');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Create a new sponsor (Super Admin required)
  Future<Map<String, dynamic>> createSponsor(
    String token, {
    required String name,
    String? subtitle,
    required String logoUrl,
  }) async {
    try {
      final payload = {
        "name": name.trim(),
        "subtitle": subtitle?.trim(),
        "logoUrl": logoUrl.trim(),
      };

      final response = await http.post(
        Uri.parse("$baseUrl/sponsors"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201 && responseData['success'] == true) {
        return responseData['data'];
      } else {
        throw Exception(responseData['message'] ?? 'Failed to create sponsor');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update an existing sponsor (Super Admin required)
  Future<Map<String, dynamic>> updateSponsor(
    String token,
    String id, {
    String? name,
    String? subtitle,
    String? logoUrl,
  }) async {
    try {
      final payload = {
        if (name != null) "name": name.trim(),
        if (subtitle != null) "subtitle": subtitle.trim(),
        if (logoUrl != null) "logoUrl": logoUrl.trim(),
      };

      final response = await http.put(
        Uri.parse("$baseUrl/sponsors/$id"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      } else {
        throw Exception(responseData['message'] ?? 'Failed to update sponsor');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Delete a sponsor (Super Admin required)
  Future<void> deleteSponsor(String token, String id) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/sponsors/$id"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to delete sponsor');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
