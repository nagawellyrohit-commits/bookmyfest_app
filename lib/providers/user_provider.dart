import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? _fullName;
  String? _email;
  String? _phone;
  String? _role;
  String? _collegeId;
  String? _collegeName;
  bool _isVerified = false;
  String? _department;
  bool _isFinalYear = false;
  bool _isPendingDeletion = false;

  // Getters
  String? get token => _token;
  String? get userId => _userId;
  String? get fullName => _fullName;
  String? get email => _email;
  String? get phone => _phone;
  String? get role => _role;
  String? get collegeId => _collegeId;
  String? get collegeName => _collegeName;
  bool get isVerified => _isVerified;
  String? get department => _department;
  bool get isFinalYear => _isFinalYear;
  bool get isPendingDeletion => _isPendingDeletion;

  bool get isLoggedIn => _token != null;

  // Set user session after successful login or profile lookup
  void setSession(String token, Map<String, dynamic> userMap) {
    _token = token;
    _userId = userMap['id'];
    _fullName = userMap['fullName'] ?? userMap['full_name'];
    _email = userMap['email'];
    _phone = userMap['phone'];
    _role = userMap['role'];
    _collegeId = userMap['collegeId'] ?? userMap['college_id'];

    // College relationship parse
    if (userMap['college'] != null) {
      _collegeName = userMap['college']['name'];
    }

    _isVerified = userMap['isVerified'] ?? userMap['is_verified'] ?? false;
    _department = userMap['department'];
    _isFinalYear = userMap['isFinalYear'] ?? userMap['is_final_year'] ?? false;
    _isPendingDeletion =
        userMap['isPendingDeletion'] ?? userMap['is_pending_deletion'] ?? false;

    // Persist session details asynchronously
    _saveSessionToPrefs(token, userMap);

    notifyListeners();
  }

  // Clear session on logout
  void logout() {
    _token = null;
    _userId = null;
    _fullName = null;
    _email = null;
    _phone = null;
    _role = null;
    _collegeId = null;
    _collegeName = null;
    _isVerified = false;
    _department = null;
    _isFinalYear = false;
    _isPendingDeletion = false;

    // Clear session details from persistent storage
    _clearSessionInPrefs();

    notifyListeners();
  }

  Future<void> _saveSessionToPrefs(String token, Map<String, dynamic> userMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_data', jsonEncode(userMap));
    } catch (e) {
      // Ignore cache storage errors
    }
  }

  Future<void> _clearSessionInPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('user_data');
    } catch (e) {
      // Ignore cache storage errors
    }
  }

  // Load session from persistent storage on app launch
  Future<bool> loadSessionFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final userDataStr = prefs.getString('user_data');
      if (token != null && userDataStr != null) {
        final userMap = jsonDecode(userDataStr) as Map<String, dynamic>;
        _token = token;
        _userId = userMap['id'];
        _fullName = userMap['fullName'] ?? userMap['full_name'];
        _email = userMap['email'];
        _phone = userMap['phone'];
        _role = userMap['role'];
        _collegeId = userMap['collegeId'] ?? userMap['college_id'];

        if (userMap['college'] != null) {
          _collegeName = userMap['college']['name'];
        }

        _isVerified = userMap['isVerified'] ?? userMap['is_verified'] ?? false;
        _department = userMap['department'];
        _isFinalYear = userMap['isFinalYear'] ?? userMap['is_final_year'] ?? false;
        _isPendingDeletion =
            userMap['isPendingDeletion'] ?? userMap['is_pending_deletion'] ?? false;

        notifyListeners();
        return true;
      }
    } catch (e) {
      // Ignore cache load errors
    }
    return false;
  }
}
