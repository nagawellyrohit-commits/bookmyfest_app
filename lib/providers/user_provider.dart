import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {

  String username = "";

  void setUsername(String name) {
    username = name;
    notifyListeners();
  }
}