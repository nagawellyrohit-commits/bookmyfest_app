import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:student_app/config/api_config.dart';

class EventService {
  static String get baseUrl => ApiConfig.baseUrl;

  // Helpers to get request headers
  Map<String, String> _headers(String token) => {
    "Content-Type": "application/json",
    "Authorization": "Bearer $token",
  };

  // Fetch all events (filtered by college automatically for coordinators/admins)
  Future<List<dynamic>> getEvents(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/events"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(responseData['message'] ?? 'Failed to load events');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Fetch specific event details
  Future<Map<String, dynamic>> getEventDetails(
    String token,
    String eventId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/events/$eventId"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(
        responseData['message'] ?? 'Failed to load event details',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Create a new event
  Future<Map<String, dynamic>> createEvent(
    String token,
    Map<String, dynamic> eventData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events"),
        headers: _headers(token),
        body: jsonEncode(eventData),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(responseData['message'] ?? 'Failed to create event');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Update event
  Future<Map<String, dynamic>> updateEvent(
    String token,
    String eventId,
    Map<String, dynamic> eventData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/events/$eventId"),
        headers: _headers(token),
        body: jsonEncode(eventData),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'] ?? responseData;
      }
      throw Exception(responseData['message'] ?? 'Failed to update event');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Delete event
  Future<void> deleteEvent(String token, String eventId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/events/$eventId"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to delete event');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Register for an event
  Future<Map<String, dynamic>> registerForEvent(
    String token,
    String eventId, {
    required String registrationType,
    String? paymentReference,
    int? groupSize,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events/$eventId/register"),
        headers: _headers(token),
        body: jsonEncode({
          "registrationType": registrationType,
          "paymentReference": paymentReference,
          "groupSize": groupSize,
        }),
      );
      final responseData = jsonDecode(response.body);
      if ((response.statusCode == 201 || response.statusCode == 200) &&
          responseData['success'] == true) {
        return responseData;
      }
      throw Exception(responseData['message'] ?? 'Registration failed');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Unregister from an event
  Future<void> unregisterFromEvent(
    String token,
    String eventId,
    String regId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/events/$eventId/registrations/$regId"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to unregister');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Fetch registrations (Coordinator/Admin view)
  Future<List<dynamic>> getEventRegistrations(
    String token,
    String eventId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/events/$eventId/registrations"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(
        responseData['message'] ?? 'Failed to load registrations',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Fetch pending payment registrations (Coordinator/Admin view)
  Future<List<dynamic>> getPendingPayments(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/events/pending-payments"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(
        responseData['message'] ?? 'Failed to load pending payments',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Confirm registration payment (Coordinator action)
  Future<void> confirmPayment(
    String token,
    String eventId,
    String regId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events/$eventId/registrations/$regId/confirm"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to confirm payment');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Scan QR code to mark attendance
  Future<Map<String, dynamic>> scanQrCode(
    String token,
    String eventId,
    String qrCode,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events/$eventId/scan"),
        headers: _headers(token),
        body: jsonEncode({"qrCode": qrCode}),
      );
      final responseData = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          responseData['success'] == true) {
        return responseData;
      }
      throw Exception(responseData['message'] ?? 'Failed to verify QR scan');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Fetch attendance logs
  Future<List<dynamic>> getEventAttendance(String token, String eventId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/events/$eventId/attendance"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(responseData['message'] ?? 'Failed to load attendance');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Manually verify attendance override
  Future<void> verifyAttendance(
    String token,
    String eventId,
    String attendanceId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events/$eventId/attendance/$attendanceId/verify"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(
          responseData['message'] ?? 'Failed to verify attendance',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Get AI suggested certificate templates
  Future<List<dynamic>> getCertificateSuggestions(
    String token,
    String eventId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/events/$eventId/certificates/suggestions"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(
        responseData['message'] ?? 'Failed to load certificate suggestions',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Approve a certificate template
  Future<void> approveCertificateTemplate(
    String token,
    String eventId,
    Map<String, dynamic> template,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events/$eventId/certificates/approve"),
        headers: _headers(token),
        body: jsonEncode(template),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(
          responseData['message'] ?? 'Failed to approve template',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Super Admin view final-year job profiles
  Future<List<dynamic>> getJobProfiles(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/job-profiles"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(
        responseData['message'] ?? 'Failed to load final year profiles',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Super Admin view ALL job profiles (regardless of passing/final year status)
  Future<List<dynamic>> getAllJobProfiles(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/all-job-profiles"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(
        responseData['message'] ?? 'Failed to load all job profiles',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Super Admin view all student accounts
  Future<List<dynamic>> getAllStudents(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/students"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(responseData['message'] ?? 'Failed to load students');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Super Admin view all faculty admin accounts
  Future<List<dynamic>> getAllFaculties(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/faculties"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(responseData['message'] ?? 'Failed to load faculties');
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Super Admin view all coordinator accounts
  Future<List<dynamic>> getAllCoordinators(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/coordinators"),
        headers: _headers(token),
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

  // Get pending event approvals (Faculty Admin)
  Future<List<dynamic>> getPendingEventApprovals(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/events/pending-approvals"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      }
      throw Exception(
        responseData['message'] ?? 'Failed to load pending event approvals',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Approve updates
  Future<void> approveEventUpdate(String token, String eventId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events/$eventId/approve-update"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to approve updates');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Discard updates / reject event with a reason
  Future<void> rejectEventUpdate(
    String token,
    String eventId, {
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events/$eventId/reject-update"),
        headers: _headers(token),
        body: jsonEncode({"reason": reason}),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to reject updates');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Approve delete
  Future<void> approveEventDelete(String token, String eventId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events/$eventId/approve-delete"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(
          responseData['message'] ?? 'Failed to approve deletion',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Discard delete
  Future<void> rejectEventDelete(String token, String eventId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/events/$eventId/reject-delete"),
        headers: _headers(token),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to reject deletion');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
