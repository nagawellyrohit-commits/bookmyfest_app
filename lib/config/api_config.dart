import 'package:flutter/foundation.dart';

class ApiConfig {
  // Define your backend URL here.
  // Replace this with your Render URL (e.g. "https://college-connect-api.onrender.com/api") to go live!
  static const String _productionBaseUrl =
      "https://bookmyfest-app.onrender.com/api"; // Leave empty to use local environment defaults

  static String get baseUrl {
    if (_productionBaseUrl.isNotEmpty) {
      return _productionBaseUrl;
    }

    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? "localhost" : Uri.base.host;
      return "http://$host:5001/api";
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? "http://10.0.2.2:5001/api"
        : "http://localhost:5001/api";
  }
}
