import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';
import '../data/db_helper.dart'; 

class DeviceInfoService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static final DBHelper _dbHelper = DBHelper();

  /// Einhandmodus ändern und speichern
  static Future<void> setOneHandMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOneHandMode', value);
  }

  /// Bevorzugte Hand ändern und speichern
  static Future<void> setRightHanded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isRightHanded', value);
  }

  /// Holt rohe Gerätedaten vom Device und speichert sie
  static Future<DeviceInfo> getDeviceInfo(BuildContext context) async {
    String model = 'Unknown';
    String manufacturer = 'Unknown';
    String osVersion = 'Unknown';
    double brightness = 0.0;

    // Bildschirmhelligkeit
    try {
      final brightnessProvider = ScreenBrightness();
      brightness = await brightnessProvider.current;
    } catch (e) {
      brightness = 0.0;
    }

    // Plattformabhängige Infos
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      model = iosInfo.model ?? 'iPhone';
      manufacturer = 'Apple';
      osVersion = iosInfo.systemVersion ?? 'Unknown';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      model = androidInfo.model ?? 'Unknown';
      manufacturer = androidInfo.manufacturer ?? 'Unknown';
      osVersion = androidInfo.version.release ?? 'Unknown';
    } else {
      model = 'Unsupported';
      manufacturer = 'Unsupported';
      osVersion = 'Unsupported';
    }

    // Zusätzliche UI-abhängige Daten
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;

    // Einhandmodus und bevorzugte Hand aus den SharedPreferences laden
    final prefs = await SharedPreferences.getInstance();
    bool isOneHandMode = prefs.getBool('isOneHandMode') ?? false;
    bool isRightHanded = prefs.getBool('isRightHanded') ?? true;

    final deviceInfo = DeviceInfo(
      model: model,
      manufacturer: manufacturer,
      osVersion: osVersion,
      screenBrightness: brightness,
      isPortrait: isPortrait,
      isOneHandMode: isOneHandMode,
      isRightHanded: isRightHanded,
    );

    // Speichere Geräteinfo in der Datenbank
    await _dbHelper.saveDeviceInfo(deviceInfo);

    return deviceInfo;
  }

  static Map<String, String> getFormattedDeviceData(DeviceInfo deviceInfo) {
    final brightnessPercent = (deviceInfo.screenBrightness * 100).toStringAsFixed(0);
    final brightnessValue = (deviceInfo.screenBrightness * 255).round().toString();
    return {
      'Modell': deviceInfo.model,
      'Hersteller': deviceInfo.manufacturer,
      'OS-Version': deviceInfo.osVersion,
      'Bildschirmhelligkeit': '$brightnessPercent% ($brightnessValue/255)',
      'Ausrichtung': deviceInfo.isPortrait ? 'Hochformat' : 'Querformat',
      'Einhandmodus': deviceInfo.isOneHandMode ? 'Aktiviert' : 'Deaktiviert',
      'Bevorzugte Hand': deviceInfo.isRightHanded ? 'Rechtshänder' : 'Linkshänder',
    };
  }
}