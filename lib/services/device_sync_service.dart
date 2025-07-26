import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; 
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

import '../models/device_info.dart';
import '../data/db_helper.dart';

class DeviceSyncService with ChangeNotifier {
  static const String _baseUrl = 'https://portfoliojonaskimmer.netlify.app/.netlify/functions/api';

  final DBHelper _dbHelper = DBHelper();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Synchronisationsstatus
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  bool _isAutoSyncEnabled = true;
  int _syncIntervalMinutes = 5;
  Timer? _syncTimer;
  
  // Getter für Status
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  int get syncInterval => _syncIntervalMinutes;
  
  DeviceSyncService() {
    print('DeviceSyncService: Initialisierung gestartet');
    _loadSettings();
    if (_isAutoSyncEnabled) {
      startPeriodicSync();
    }
    print('DeviceSyncService: Initialisierung abgeschlossen');
  }
  
  // Einstellungen laden
  Future<void> _loadSettings() async {
    try {
      print('DeviceSyncService: Lade Einstellungen');
      final prefs = await SharedPreferences.getInstance();
      _isAutoSyncEnabled = prefs.getBool('device_auto_sync_enabled') ?? true;
      _syncIntervalMinutes = prefs.getInt('device_sync_interval') ?? 5;
      final lastSyncTimeString = prefs.getString('device_last_sync_time');
      if (lastSyncTimeString != null) {
        _lastSyncTime = DateTime.parse(lastSyncTimeString);
      }
      notifyListeners();
      print('DeviceSyncService: Einstellungen geladen - AutoSync: $_isAutoSyncEnabled, Intervall: $_syncIntervalMinutes min');
    } catch (e) {
      print('DeviceSyncService: Fehler beim Laden der Einstellungen: $e');
    }
  }
  
  // Einstellungen speichern
  Future<void> _saveSettings() async {
    try {
      print('DeviceSyncService: Speichere Einstellungen');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('device_auto_sync_enabled', _isAutoSyncEnabled);
      await prefs.setInt('device_sync_interval', _syncIntervalMinutes);
      if (_lastSyncTime != null) {
        await prefs.setString('device_last_sync_time', _lastSyncTime!.toIso8601String());
      }
      print('DeviceSyncService: Einstellungen gespeichert');
    } catch (e) {
      print('DeviceSyncService: Fehler beim Speichern der Einstellungen: $e');
    }
  }
  
  // Periodische Synchronisation starten
  void startPeriodicSync() {
    print('DeviceSyncService: Starte periodische Synchronisation alle $_syncIntervalMinutes Minuten');
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (_) {
        print('DeviceSyncService: Periodische Synchronisation ausgelöst');
        syncDeviceInfo();
      }
    );
  }
  
  // Periodische Synchronisation stoppen
  void stopPeriodicSync() {
    print('DeviceSyncService: Stoppe periodische Synchronisation');
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  // Synchronisationseinstellungen aktualisieren
  Future<void> updateSyncSettings({
    bool? autoSyncEnabled,
    int? syncInterval
  }) async {
    print('DeviceSyncService: Aktualisiere Synchronisationseinstellungen');
    if (autoSyncEnabled != null) {
      _isAutoSyncEnabled = autoSyncEnabled;
      autoSyncEnabled ? startPeriodicSync() : stopPeriodicSync();
      print('DeviceSyncService: AutoSync auf $autoSyncEnabled gesetzt');
    }
    
    if (syncInterval != null) {
      _syncIntervalMinutes = syncInterval;
      print('DeviceSyncService: Synchronisationsintervall auf $_syncIntervalMinutes Minuten gesetzt');
      if (_isAutoSyncEnabled) {
        stopPeriodicSync();
        startPeriodicSync();
      }
    }
    
    await _saveSettings();
    notifyListeners();
    print('DeviceSyncService: Synchronisationseinstellungen aktualisiert');
  }
  
  // Geräteinfo mit dem Server synchronisieren - Verbesserte Fehlerbehandlung
Future<bool> syncDeviceInfo() async {
  if (_isSyncing) {
    print('DeviceSyncService: Bereits eine Synchronisation im Gange, überspringe...');
    return false;
  }
  
  try {
    print('DeviceSyncService: Starte Synchronisation der Geräteinformationen');
    _isSyncing = true;
    notifyListeners();
    
    final unsyncedDeviceInfos = await _dbHelper.getUnsyncedDeviceInfo();
    
    print('DeviceSyncService: Gefundene unsynced DeviceInfos: ${unsyncedDeviceInfos.length}');
    
    if (unsyncedDeviceInfos.isEmpty) {
      print('DeviceSyncService: Keine Geräteinfos zum Synchronisieren');
      _isSyncing = false;
      notifyListeners();
      return true;
    }
    
    // Generiere eindeutige Geräte-ID
    final deviceId = await _generateUniqueDeviceId();
    print('DeviceSyncService: Generierte Geräte-ID: $deviceId');
    
    bool allSuccess = true;
    
    for (var deviceInfo in unsyncedDeviceInfos) {
      try {
        final jsonData = deviceInfo.toJson();
        jsonData['deviceId'] = deviceId;
        
        final requestBody = json.encode(jsonData);
        
        print('DeviceSyncService: Sende Geräteinfo an $_baseUrl/device');
        
        final response = await http.post(
          Uri.parse('$_baseUrl/device'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        ).timeout(Duration(seconds: 10));
        
        print('DeviceSyncService: Geräteinfo-Antwort Code: ${response.statusCode}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          print('DeviceSyncService: Erfolgreiche Antwort vom Server für ein Gerät.');
          
          List<DeviceInfo> syncedList = [deviceInfo];
          await _dbHelper.markDeviceInfoAsSynced(syncedList);
          
        } else {
          print('DeviceSyncService: Server-Fehlerantwort für ein Gerät: ${response.statusCode}');
          print('DeviceSyncService: Fehlermeldung vom Server: ${response.body}');
          allSuccess = false;
        }
      } catch (itemError) {
        print('DeviceSyncService: Fehler bei der Verarbeitung eines Geräteinfos: $itemError');
        allSuccess = false;
      }
    }
    
    // Aktualisiere LastSyncTime nur wenn mindestens ein Datensatz erfolgreich war
    if (allSuccess) {
      _lastSyncTime = DateTime.now();
      await _saveSettings();
    }
    
    _isSyncing = false;
    notifyListeners();
    return allSuccess;
    
  } catch (e) {
    print('DeviceSyncService: Kritischer Fehler bei Geräteinfo-Synchronisation: $e');
    _isSyncing = false;
    notifyListeners();
    return false;
  }
}
  
  // Eindeutige Geräte-ID generieren - mit besserer Fehlerbehandlung
  Future<String> _generateUniqueDeviceId() async {
    try {
      print('DeviceSyncService: Generiere eindeutige Geräte-ID');
      
      if (Platform.isAndroid) {
        try {
          final androidInfo = await _deviceInfo.androidInfo;
          final id = androidInfo.id ?? 'unknown_android_id';
          print('DeviceSyncService: Android-ID generiert: $id');
          return id;
        } catch (androidError) {
          print('DeviceSyncService: Fehler bei Android-ID-Generierung: $androidError');
          return 'android_${DateTime.now().millisecondsSinceEpoch}';
        }
      } else if (Platform.isIOS) {
        try {
          final iosInfo = await _deviceInfo.iosInfo;
          final id = iosInfo.identifierForVendor ?? 'unknown_ios_id';
          print('DeviceSyncService: iOS-ID generiert: $id');
          return id;
        } catch (iosError) {
          print('DeviceSyncService: Fehler bei iOS-ID-Generierung: $iosError');
          return 'ios_${DateTime.now().millisecondsSinceEpoch}';
        }
      } else {
        print('DeviceSyncService: Unbekannte Plattform, generiere Timestamp-basierte ID');
        return 'generic_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      print('DeviceSyncService: Genereller Fehler bei Geräte-ID-Generierung: $e');
      return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  // Manuell eine Geräteinformation erzeugen und in der Datenbank speichern (für Tests)
  Future<void> createAndSaveDeviceInfo() async {
    try {
      print('DeviceSyncService: Erstelle und speichere Test-DeviceInfo');
      
      final testInfo = DeviceInfo(
        model: 'Test_Model',
        manufacturer: 'Test_Manufacturer',
        osVersion: 'Test_OS',
        screenBrightness: 0.7,
        isPortrait: true,
        isOneHandMode: false,
        isRightHanded: true,
      );
      
      await _dbHelper.saveDeviceInfo(testInfo);
      print('DeviceSyncService: Test-DeviceInfo gespeichert');
    } catch (e) {
      print('DeviceSyncService: Fehler beim Erstellen und Speichern der Test-DeviceInfo: $e');
    }
  }
  
  // Debug-Methode: Zeige Status der Geräteinformationen in der Datenbank
  Future<void> debugDeviceInfoStatus() async {
    try {
      final unsyncedCount = await _dbHelper.getUnsyncedDataCount('device_info');
      print('DeviceSyncService DEBUG: Unsynced DeviceInfo-Einträge: $unsyncedCount');
      
      await _dbHelper.debugPrintDeviceInfo();
    } catch (e) {
      print('DeviceSyncService DEBUG: Fehler bei Status-Debug: $e');
    }
  }
  
  // Cleanup
  void dispose() {
    print('DeviceSyncService: Dispose aufgerufen');
    stopPeriodicSync();
    super.dispose();
  }
}