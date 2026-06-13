import 'package:flutter/material.dart';

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

    notifyListeners();
  }
}