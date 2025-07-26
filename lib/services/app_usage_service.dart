import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'dart:math' show max;
import 'package:app_usage/app_usage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_apps/device_apps.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../data/db_helper.dart';

class AppUsageService extends ChangeNotifier {
  List<dynamic> _usageData = [];
  bool _hasUsageAccess = false;
  int _appOpenCount = 0;
  DateTime? _appStartTime;
  int _totalUsageSeconds = 0;
  final DBHelper _dbHelper = DBHelper();
  String? _currentPackageName;

  static const String baseUrl = 'https://portfolio-bjatv9ae2-jonas-kimmerinfos-projects.vercel.app/api/appusage';
  static const String appOpenCountKey = 'app_open_count';
  static const String lastOpenDateKey = 'last_open_date';
  static const String totalUsageSecondsKey = 'total_usage_seconds';

  List<dynamic> get usageData => _usageData;
  bool get hasUsageAccess => _hasUsageAccess;
  int get appOpenCount => _appOpenCount;

  AppUsageService() {
    _initialize();
  }

Future<void> _initialize() async {
  print('AppUsageService: Initialisierung...');
  final prefs = await SharedPreferences.getInstance();
  
  try {
    final lastDate = prefs.getString(lastOpenDateKey);
    _appOpenCount = prefs.getInt(appOpenCountKey) ?? 0;
    _totalUsageSeconds = prefs.getInt(totalUsageSecondsKey) ?? 0;
    
    print('AppUsageService: Geladene Werte: lastDate=$lastDate, _appOpenCount=$_appOpenCount, _totalUsageSeconds=$_totalUsageSeconds');
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (lastDate != today) {
      print('AppUsageService: Neuer Tag erkannt ($today vs $lastDate), setze App-Zähler zurück');
      _appOpenCount = 0;
    }
    
    _appOpenCount++;
    print('AppUsageService: App-Zähler erhöht auf $_appOpenCount');
    
    _appStartTime = DateTime.now();
    
    await prefs.setInt(appOpenCountKey, _appOpenCount);
    await prefs.setString(lastOpenDateKey, today);
    
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      await prefs.setString('current_package_name', packageInfo.packageName);
      await prefs.setString('current_app_name', packageInfo.appName);
      
      _currentPackageName = packageInfo.packageName;
      print('AppUsageService: Aktuelles Paket ist $_currentPackageName');
      
      print('AppUsageService: Werte nach Speicherung: _appOpenCount=$_appOpenCount');
    } catch (e) {
      print('AppUsageService: Konnte Paketinfo nicht abrufen: $e');
    }
    
    await _recordAppStart();
    
    checkUsagePermission();
    print('AppUsageService: Initialisierung abgeschlossen. Öffnungen heute: $_appOpenCount');
    
    notifyListeners();
  } catch (e) {
    print('AppUsageService: Fehler bei der Initialisierung: $e');
    _appOpenCount = 1;
    _totalUsageSeconds = 0;
    _appStartTime = DateTime.now();
    notifyListeners();
  }
}

  Future<void> _recordAppStart() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await _dbHelper.saveAppUsageData(
        packageInfo.packageName,
        packageInfo.appName,
        DateTime.now().millisecondsSinceEpoch
      );
      print("AppUsageService: App-Start aufgezeichnet: ${packageInfo.appName}");
    } catch (e) {
      print("AppUsageService: Fehler beim Aufzeichnen des App-Starts: $e");
    }
  }

  Future<String> _getUniqueDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id ?? 'unknown_android_device';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios_device';
      }
    } catch (e) {
      print('AppUsageService: Fehler beim Abrufen der Geräte-ID: $e');
    }
    return 'unknown_device';
  }

  Future<bool> syncAppUsageData() async {
    try {
      final deviceId = await _getUniqueDeviceId();
      final unsyncedData = await _dbHelper.getUnsyncedAppUsageData();
      
      if (unsyncedData.isEmpty) {
        print('AppUsageService: Keine unsynced App-Nutzungsdaten');
        return true;
      }

      print('AppUsageService: Synchronisiere ${unsyncedData.length} App-Nutzungsdatensätze');

      final formattedData = unsyncedData.map((item) => {
        'deviceId': deviceId,
        'packageName': item['packageName'],
        'appName': item['appName'],
        'usageDuration': item['usageDuration'],
        'openCount': item['openCount'],
        'timestamp': item['timestamp']
      }).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/bulk'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(formattedData)
      );

      print('AppUsageService: Server-Antwort: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _dbHelper.markAppUsageDataAsSynced(unsyncedData);
        print('AppUsageService: App-Nutzungsdaten erfolgreich synchronisiert');
        return true;
      } else {
        print('AppUsageService: Synchronisationsfehler: ${response.body}');
        return false;
      }
    } catch (e) {
      print('AppUsageService: Kritischer Synchronisationsfehler: $e');
      return false;
    }
  }

  Future<void> checkUsagePermission() async {
    if (Platform.isIOS) {
      _hasUsageAccess = true;
      await fetchUsageData();
    } else if (Platform.isAndroid) {
      try {
        await AppUsage().getAppUsage(
          DateTime.now().subtract(Duration(hours: 1)),
          DateTime.now(),
        );
        _hasUsageAccess = true;
        await fetchUsageData();
      } catch (e) {
        _hasUsageAccess = false;
        print("AppUsageService: Keine Berechtigung für App-Nutzung: $e");
      }
    }
    notifyListeners();
  }

  Future<void> fetchUsageData() async {
    print('AppUsageService: Lade Nutzungsdaten...');
    try {
      if (Platform.isIOS) {
        final appUsageData = await _dbHelper.getAppUsageForUI();
        
        if (appUsageData['count'] > 0 && appUsageData['data'].isNotEmpty) {
          final appData = appUsageData['data'][0];
          
          Duration currentSessionDuration = Duration.zero;
          if (_appStartTime != null) {
            currentSessionDuration = DateTime.now().difference(_appStartTime!);
          }
          
          final int openCount = max(_appOpenCount, 1);
          
          final int totalUsageSeconds = max(
            appData['usageDuration'] + currentSessionDuration.inSeconds,
            currentSessionDuration.inSeconds
          );
          
          _usageData = [{
            'packageName': appData['packageName'],
            'appName': appData['appName'],
            'usage': Duration(seconds: totalUsageSeconds),
            'openCount': openCount,
          }];
          
          print('AppUsageService: iOS - Nutzungsdaten geladen: $_usageData');
        } else {
          Duration currentSessionDuration = Duration.zero;
          if (_appStartTime != null) {
            currentSessionDuration = DateTime.now().difference(_appStartTime!);
          }
          
          try {
            final packageInfo = await PackageInfo.fromPlatform();
            _usageData = [{
              'packageName': packageInfo.packageName,
              'appName': packageInfo.appName,
              'usage': currentSessionDuration,
              'openCount': max(_appOpenCount, 1),
            }];
            
            print('AppUsageService: iOS - Fallback-Nutzungsdaten erstellt: $_usageData');
          } catch (e) {
            print('AppUsageService: Konnte keine Fallback-Daten erstellen: $e');
          }
        }
      } else if (Platform.isAndroid) {
        final DateTime endDate = DateTime.now();
        final DateTime startDate = endDate.subtract(Duration(days: 1));
        
        print('AppUsageService: Android - Lade Nutzungsdaten für Zeitraum $startDate bis $endDate');
        
        final List<AppUsageInfo> appUsageInfo = await AppUsage().getAppUsage(startDate, endDate);
        final List<Application> installedApps = await DeviceApps.getInstalledApplications(
          includeAppIcons: true,
          includeSystemApps: false,
          onlyAppsWithLaunchIntent: true,
        );
        
        print('AppUsageService: Android - ${appUsageInfo.length} Apps mit Nutzungsdaten gefunden');
        
        // Sammle Daten für alle Apps
        List<Map<String, dynamic>> processedApps = [];
        
        for (var info in appUsageInfo) {
          Application? app;
          
          try {
            app = installedApps.firstWhere(
              (installedApp) => installedApp.packageName == info.packageName,
              orElse: () => null as Application,
            );
          } catch (e) {
            print('AppUsageService: App nicht gefunden: ${info.packageName}');
          }
          
          final appName = app?.appName ?? info.packageName;
          
          // Speichere auch in der Datenbank
          await _dbHelper.saveAppUsageDataMap({
            'packageName': info.packageName,
            'appName': appName,
            'usageDuration': info.usage.inSeconds,
            'openCount': info.packageName == _currentPackageName ? _appOpenCount : 1,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
          
          // Bestimme Öffnungszahl: Verwende den aktuellen Zähler für die laufende App
          int appOpenCount = 1; // Standard für andere Apps
          
          if (info.packageName == _currentPackageName) {
            appOpenCount = max(_appOpenCount, 1); 
            print('AppUsageService: Aktuelle App gefunden mit $appOpenCount Öffnungen');
          }
          
          // Stelle sicher, dass die Nutzungsdauer einen sinnvollen Wert hat
          Duration usageDuration = info.usage;
          if (info.packageName == _currentPackageName && _appStartTime != null) {
            final currentSessionDuration = DateTime.now().difference(_appStartTime!);
            if (info.usage < currentSessionDuration) {
              usageDuration = currentSessionDuration;
              print('AppUsageService: Nutzungsdauer angepasst auf aktuelle Session: ${usageDuration.inSeconds}s');
            }
          }
          
          processedApps.add({
            'packageName': info.packageName,
            'appName': appName,
            'usage': usageDuration,
            'openCount': appOpenCount,
          });
        }
        
        // Falls keine Daten für die aktuelle App gefunden wurden, füge sie hinzu
        if (!processedApps.any((app) => app['packageName'] == _currentPackageName) && _currentPackageName != null) {
          try {
            final packageInfo = await PackageInfo.fromPlatform();
            Duration currentSessionDuration = Duration.zero;
            if (_appStartTime != null) {
              currentSessionDuration = DateTime.now().difference(_appStartTime!);
            }
            
            processedApps.add({
              'packageName': packageInfo.packageName,
              'appName': packageInfo.appName,
              'usage': currentSessionDuration,
              'openCount': max(_appOpenCount, 1),
            });
            
            print('AppUsageService: Aktuelle App zu den Daten hinzugefügt: ${packageInfo.appName}');
          } catch (e) {
            print('AppUsageService: Konnte aktuelle App nicht hinzufügen: $e');
          }
        }
        
        _usageData = processedApps;
        print('AppUsageService: Android - Nutzungsdaten verarbeitet: ${_usageData.length} Apps');
      }
      
      notifyListeners();
    } catch (e) {
      print('AppUsageService: Fehler beim Abrufen der Nutzungsdaten: $e');
      
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        Duration currentSessionDuration = Duration.zero;
        if (_appStartTime != null) {
          currentSessionDuration = DateTime.now().difference(_appStartTime!);
        }
        
        _usageData = [{
          'packageName': packageInfo.packageName,
          'appName': packageInfo.appName,
          'usage': currentSessionDuration,
          'openCount': max(_appOpenCount, 1),
        }];
        
        print('AppUsageService: Fallback-Nutzungsdaten nach Fehler: $_usageData');
        notifyListeners();
      } catch (fallbackError) {
        print('AppUsageService: Konnte keine Fallback-Daten erstellen: $fallbackError');
      }
    }
  }

  void onAppPaused() async {
    print('AppUsageService: App pausiert');
    if (_appStartTime != null) {
      final now = DateTime.now();
      final usageTime = now.difference(_appStartTime!);
      
      final prefs = await SharedPreferences.getInstance();
      _totalUsageSeconds += usageTime.inSeconds;
      
      // Verhindere negative oder unrealistisch große Werte
      if (_totalUsageSeconds < 0) {
        _totalUsageSeconds = 0;
      } else if (_totalUsageSeconds > 86400) { 
        _totalUsageSeconds = 86400;
      }
      
      await prefs.setInt(totalUsageSecondsKey, _totalUsageSeconds);
      await prefs.setInt(appOpenCountKey, _appOpenCount);
      
      print("AppUsageService: Nutzungszeit dieser Sitzung: ${usageTime.inSeconds} Sekunden");
      print("AppUsageService: Gesamtnutzungszeit: $_totalUsageSeconds Sekunden");
      
      await saveCurrentAppUsage();
      
      final packageInfo = await PackageInfo.fromPlatform();
      await _dbHelper.updateAppUsageData(
        packageInfo.packageName,
        now.millisecondsSinceEpoch
      );
    }
  }

  Future<void> saveCurrentAppUsage() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      
      Duration currentSessionDuration = Duration.zero;
      if (_appStartTime != null) {
        currentSessionDuration = DateTime.now().difference(_appStartTime!);
      }
      
      // Stelle sicher, dass _totalUsageSeconds ein sinnvoller Wert ist
      int totalDuration = _totalUsageSeconds;
      if (totalDuration <= 0) {
        totalDuration = currentSessionDuration.inSeconds;
      }
      
      final usageData = {
        'packageName': packageInfo.packageName,
        'appName': packageInfo.appName,
        'usageDuration': totalDuration,
        'openCount': max(_appOpenCount, 1),
        'timestamp': DateTime.now().millisecondsSinceEpoch
      };
      
      print("AppUsageService: Speichere App-Nutzungsdaten: $usageData");
      
      await _dbHelper.saveAppUsageDataMap(usageData);
    } catch (e) {
      print('AppUsageService: Fehler beim Speichern der App-Nutzungsdaten: $e');
    }
  }

  Future<void> requestUsagePermission() async {
    if (Platform.isAndroid) {
      try {
        await AppUsage().getAppUsage(
          DateTime.now().subtract(Duration(hours: 1)),
          DateTime.now(),
        );
        _hasUsageAccess = true;
        fetchUsageData();
      } catch (e) {
        _hasUsageAccess = false;
        print("AppUsageService: Keine Berechtigung für App-Nutzung: $e");
      }
    } else if (Platform.isIOS) {
      // Für iOS spezifische Berechtigungslogik
      _hasUsageAccess = true;
      fetchUsageData();
    }
    
    notifyListeners();
  }

  void onAppResumed() {
    _appStartTime = DateTime.now();
    print("AppUsageService: App wurde wieder aufgenommen um: $_appStartTime");
    fetchUsageData();
  }
}