import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/touch_point.dart';
import '../data/db_helper.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

class TouchSyncService with ChangeNotifier {
  // Korrigierte URL
static const String _baseUrl = 'https://portfolio-bjatv9ae2-jonas-kimmerinfos-projects.vercel.app/api';
  
  // Abhängigkeiten
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
  
  TouchSyncService() {
    _loadSettings();
    if (_isAutoSyncEnabled) {
      startPeriodicSync();
    }
  }
  
  // Einstellungen laden
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoSyncEnabled = prefs.getBool('touch_auto_sync_enabled') ?? true;
    _syncIntervalMinutes = prefs.getInt('touch_sync_interval') ?? 5;
    final lastSyncTimeString = prefs.getString('touch_last_sync_time');
    if (lastSyncTimeString != null) {
      _lastSyncTime = DateTime.parse(lastSyncTimeString);
    }
    notifyListeners();
  }
  
  // Einstellungen speichern
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('touch_auto_sync_enabled', _isAutoSyncEnabled);
    await prefs.setInt('touch_sync_interval', _syncIntervalMinutes);
    if (_lastSyncTime != null) {
      await prefs.setString('touch_last_sync_time', _lastSyncTime!.toIso8601String());
    }
  }
  
  // Periodische Synchronisation starten
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (_) => syncTouchData()
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
  
  // Touch-Daten mit dem Server synchronisieren
  Future<bool> syncTouchData() async {
    if (_isSyncing) {
      print('Touch-Synchronisation läuft bereits');
      return false;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      final unsyncedTouchData = await _dbHelper.getUnsyncedTouchData();
      
      if (unsyncedTouchData.isEmpty) {
        print('Keine Touch-Daten zum Synchronisieren');
        _isSyncing = false;
        notifyListeners();
        return true;
      }
      
      // Batch-Größe für die Übertragung
      const int batchSize = 50;
      bool allSuccess = true;
      
      // Sende Daten in Batches
      for (int i = 0; i < unsyncedTouchData.length; i += batchSize) {
        final end = (i + batchSize < unsyncedTouchData.length) 
            ? i + batchSize 
            : unsyncedTouchData.length;
        
        final batch = unsyncedTouchData.sublist(i, end);
        
        // Vorbereitung der Daten für den Server
        List<Map<String, dynamic>> batchData = [];
        
        for (var point in batch) {
          Map<String, dynamic> dataPoint = {
            'deviceId': await _generateUniqueDeviceId(),
            'timestamp': point.timestamp,
            'x': point.x,
            'y': point.y,
            'type': point.type,
            'direction': point.direction,
          };
          
          // Füge zusätzliche Felder basierend auf dem Typ hinzu
          if (point.type == 'swipe') {
            dataPoint['endX'] = point.endX;
            dataPoint['endY'] = point.endY;
          } else if (point.type == 'longpress') {
            dataPoint['durationMs'] = point.durationMs;
          }
          
          batchData.add(dataPoint);
        }
        
        // Korrektes Format für den Server
        final requestBody = json.encode({'touchData': batchData});
        
        print('Sende Touch-Daten (Batch ${i ~/ batchSize + 1}/${(unsyncedTouchData.length / batchSize).ceil()}) an $_baseUrl/touch');
        print('Anfragedaten (ersten 2 Einträge): ${json.encode({'touchData': batchData.take(2).toList()})}');
        
        final response = await http.post(
          Uri.parse('$_baseUrl/touch'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );
        
        print('Touch-Daten-Antwort: ${response.statusCode} ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Markiere Batch als synchronisiert
          await _dbHelper.markTouchDataAsSynced(batch);
        } else {
          print('Fehler beim Synchronisieren der Touch-Daten (Batch ${i ~/ batchSize + 1}): ${response.statusCode} ${response.body}');
          allSuccess = false;
        }
      }
      
      // Aktualisiere letzte Synchronisationszeit bei Erfolg
      if (allSuccess) {
        _lastSyncTime = DateTime.now();
        await _saveSettings();
      }
      
      return allSuccess;
    } catch (e) {
      print('Fehler beim Synchronisieren der Touch-Daten: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  // Hilfsmethode zum Abrufen der eindeutigen Geräte-ID
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
  
  // Überprüfe, ob der Server erreichbar ist
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
  
  // Cleanup
  void dispose() {
    stopPeriodicSync();
    super.dispose();
  }
}