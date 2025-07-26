import 'package:flutter/material.dart';

class AppConfig extends ChangeNotifier {
  // Beispielhafte Konfigurationsparameter
  String apiUrl = "https://example.com/api";
  bool isDebugMode = true;

  // Methode zum Aktualisieren der API-URL
  void updateApiUrl(String newUrl) {
    apiUrl = newUrl;
    notifyListeners();
  }

  // Methode zum Umschalten des Debug-Modus
  void toggleDebugMode() {
    isDebugMode = !isDebugMode;
    notifyListeners();
  }
}
