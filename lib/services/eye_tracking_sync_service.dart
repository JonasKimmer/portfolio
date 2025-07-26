import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

import '../models/eye_tracking_data.dart';
import '../data/db_helper.dart';

class EyeTrackingSyncService with ChangeNotifier {
static const String _baseUrl = 'https://portfolio-bjatv9ae2-jonas-kimmerinfos-projects.vercel.app/api';

  // Abhängigkeiten
  final DBHelper _dbHelper;
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
  
  // Konstruktor
  EyeTrackingSyncService({
    DBHelper? dbHelper,
    bool autoSyncEnabled = true,
    int syncIntervalMinutes = 5
  }) : 
    _dbHelper = dbHelper ?? DBHelper(),
    _isAutoSyncEnabled = autoSyncEnabled,
    _syncIntervalMinutes = syncIntervalMinutes {
    _loadSettings();
    if (_isAutoSyncEnabled) {
      startPeriodicSync();
    }
  }
  
  // Einstellungen laden
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoSyncEnabled = prefs.getBool('eye_tracking_auto_sync_enabled') ?? true;
    _syncIntervalMinutes = prefs.getInt('eye_tracking_sync_interval') ?? 5;
    final lastSyncTimeString = prefs.getString('eye_tracking_last_sync_time');
    if (lastSyncTimeString != null) {
      _lastSyncTime = DateTime.parse(lastSyncTimeString);
    }
    notifyListeners();
  }
  
  // Einstellungen speichern
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eye_tracking_auto_sync_enabled', _isAutoSyncEnabled);
    await prefs.setInt('eye_tracking_sync_interval', _syncIntervalMinutes);
    if (_lastSyncTime != null) {
      await prefs.setString('eye_tracking_last_sync_time', _lastSyncTime!.toIso8601String());
    }
  }
  
  // Periodische Synchronisation starten
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (_) => syncEyeTrackingData()
    );
  }
  
  // Periodische Synchronisation stoppen
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  // Synchronisationseinstellungen aktualisieren
  Future<void> updateSyncSettings({
    bool? autoSyncEnabled,
    int? syncInterval
  }) async {
    if (autoSyncEnabled != null) {
      _isAutoSyncEnabled = autoSyncEnabled;
      autoSyncEnabled ? startPeriodicSync() : stopPeriodicSync();
    }
    
    if (syncInterval != null) {
      _syncIntervalMinutes = syncInterval;
      if (_isAutoSyncEnabled) {
        stopPeriodicSync();
        startPeriodicSync();
      }
    }
    
    await _saveSettings();
    notifyListeners();
  }
  
  // Eye-Tracking-Daten synchronisieren
  Future<bool> syncEyeTrackingData() async {
    if (_isSyncing) {
      print('Eye-Tracking-Synchronisation läuft bereits');
      return false;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      // Server-Verbindung prüfen
      if (!await isServerReachable()) {
        print('Server ist nicht erreichbar. Synchronisation abgebrochen.');
        _isSyncing = false;
        notifyListeners();
        return false;
      }
      
      final unsyncedEyeTrackingData = await _dbHelper.getUnsyncedEyeTrackingData();
      
      if (unsyncedEyeTrackingData.isEmpty) {
        print('Keine Eye-Tracking-Daten zum Synchronisieren');
        _isSyncing = false;
        notifyListeners();
        return true;
      }
      
      print('Gefundene ungesynchronisierte Eye-Tracking-Daten: ${unsyncedEyeTrackingData.length}');
      
      // Batch-Größe für die Übertragung
      const int batchSize = 50; 
      bool allSuccess = true;
      
      // Sende Daten in Batches
      for (int i = 0; i < unsyncedEyeTrackingData.length; i += batchSize) {
        final end = (i + batchSize < unsyncedEyeTrackingData.length) 
            ? i + batchSize 
            : unsyncedEyeTrackingData.length;
        
        final batch = unsyncedEyeTrackingData.sublist(i, end);
        
        // Bereite Daten für den Server vor
        List<Map<String, dynamic>> batchData = [];
        
        for (var data in batch) {
          final deviceId = await _generateUniqueDeviceId();
          
          // Erstelle eine Kopie der Daten mit deviceId
          Map<String, dynamic> dataMap = data.toMap();
          dataMap['deviceId'] = deviceId;
          
          // Stelle sicher, dass Timestamp korrekt formatiert ist
          if (dataMap['timestamp'] is DateTime) {
            dataMap['timestamp'] = dataMap['timestamp'].toIso8601String();
          }
          
          batchData.add(dataMap);
        }
        
        // Korrektes Format für den Server
        final requestBody = json.encode({'eyeTrackingData': batchData});
        
        print('Sende Eye-Tracking-Daten (Batch ${i ~/ batchSize + 1}/${(unsyncedEyeTrackingData.length / batchSize).ceil()}) an $_baseUrl/eyetracking');
        print('Anfragedaten (ersten 2 Einträge): ${json.encode({'eyeTrackingData': batchData.take(2).toList()})}');
        
        final response = await http.post(
          Uri.parse('$_baseUrl/eyetracking'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );
        
        print('Eye-Tracking-Daten-Antwort: ${response.statusCode} ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Markiere Batch als synchronisiert
          await _dbHelper.markEyeTrackingDataAsSynced(batch);
          print('Batch ${i ~/ batchSize + 1} erfolgreich synchronisiert und als synced markiert');
        } else {
          print('Fehler beim Synchronisieren der Eye-Tracking-Daten (Batch ${i ~/ batchSize + 1}): ${response.statusCode} ${response.body}');
          allSuccess = false;
        }
      }
      
      // Aktualisiere letzte Synchronisationszeit
      if (allSuccess) {
        _lastSyncTime = DateTime.now();
        await _saveSettings();
        print('Alle Eye-Tracking-Daten erfolgreich synchronisiert');
      } else {
        print('Eye-Tracking-Synchronisation teilweise fehlgeschlagen');
      }
      
      return allSuccess;
    } catch (e) {
      print('Fehler beim Synchronisieren der Eye-Tracking-Daten: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  // Hilfsmethode zur Erzeugung einer eindeutigen Geräte-ID
  Future<String> _generateUniqueDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      
      if (deviceId != null) {
        return deviceId;
      }
      
      // Versuche, eine gerätespezifische ID zu generieren
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id ?? 'android_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Speichere die ID für zukünftige Verwendung
      await prefs.setString('device_id', deviceId);
      return deviceId;
    } catch (e) {
      print('Fehler beim Generieren der Geräte-ID: $e');
      // Fallback zu einer zeitbasierten ID
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  // Überprüfen, ob der Server erreichbar ist
  Future<bool> isServerReachable() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ping'))
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Server nicht erreichbar: $e');
      return false;
    }
  }
  
  // Gib den aktuellen Synchronisationsstatus als Text zurück
  String getSyncStatusText() {
    if (_isSyncing) {
      return 'Synchronisierung läuft...';
    } else if (_lastSyncTime != null) {
      final formattedTime = '${_lastSyncTime!.hour.toString().padLeft(2, '0')}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}';
      final formattedDate = '${_lastSyncTime!.day.toString().padLeft(2, '0')}.${_lastSyncTime!.month.toString().padLeft(2, '0')}.${_lastSyncTime!.year}';
      return 'Letzte Synchronisierung: $formattedDate um $formattedTime Uhr';
    } else {
      return 'Noch keine Synchronisierung durchgeführt';
    }
  }
  
  // Cleanup
  void dispose() {
    stopPeriodicSync();
    super.dispose();
  }
}