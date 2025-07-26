import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sensor_data.dart';
import '../data/db_helper.dart';

class SensorSyncService with ChangeNotifier {
static const String _baseUrl = 'https://portfoliojonaskimmer.netlify.app/.netlify/functions/api';
  
  // Abhängigkeiten
  final DBHelper _dbHelper;
  
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
  SensorSyncService({
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
    _isAutoSyncEnabled = prefs.getBool('sensor_auto_sync_enabled') ?? true;
    _syncIntervalMinutes = prefs.getInt('sensor_sync_interval') ?? 5;
    final lastSyncTimeString = prefs.getString('sensor_last_sync_time');
    if (lastSyncTimeString != null) {
      _lastSyncTime = DateTime.parse(lastSyncTimeString);
    }
    notifyListeners();
  }
  
  // Einstellungen speichern
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sensor_auto_sync_enabled', _isAutoSyncEnabled);
    await prefs.setInt('sensor_sync_interval', _syncIntervalMinutes);
    if (_lastSyncTime != null) {
      await prefs.setString('sensor_last_sync_time', _lastSyncTime!.toIso8601String());
    }
  }
  
  // Periodische Synchronisation starten
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (_) => syncSensorData()
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
  
  // Sensordaten synchronisieren
  Future<bool> syncSensorData() async {
    if (_isSyncing) {
      print('SensorSyncService: Synchronisation läuft bereits');
      return false;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      print('SensorSyncService: Starte Synchronisation der Sensordaten');
      final unsyncedSensorData = await _dbHelper.getUnsyncedSensorData();
      
      print('SensorSyncService: Gefundene unsynced SensorData: ${unsyncedSensorData.length}');
      
      if (unsyncedSensorData.isEmpty) {
        print('SensorSyncService: Keine Sensordaten zum Synchronisieren');
        _isSyncing = false;
        notifyListeners();
        return true;
      }
      
      // Ermittle Device-ID für die Zuordnung
      final deviceId = await _getDeviceId();
      print('SensorSyncService: Verwende Geräte-ID: $deviceId');
      
      // Batch-Größe für die Übertragung
      const int batchSize = 50;
      bool allSuccess = true;
      
      // Sende Daten in Batches, um große Datenmengen zu handhaben
      for (int i = 0; i < unsyncedSensorData.length; i += batchSize) {
        final end = (i + batchSize < unsyncedSensorData.length) 
            ? i + batchSize 
            : unsyncedSensorData.length;
        
        final batch = unsyncedSensorData.sublist(i, end);
        
        // Individuelle Sensoreinträge senden (ähnlich wie bei Device-Sync)
        for (var sensorData in batch) {
          try {
            final jsonData = _convertSensorDataToJson(sensorData);
            jsonData['deviceId'] = deviceId;
            
            final requestBody = json.encode(jsonData);
            
            print('SensorSyncService: Sende Sensordaten an $_baseUrl/sensor');
            
            final response = await http.post(
              Uri.parse('$_baseUrl/sensor'),
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            ).timeout(const Duration(seconds: 10));
            
            print('SensorSyncService: Sensordaten-Antwort Code: ${response.statusCode}');
            
            if (response.statusCode == 200 || response.statusCode == 201) {
              print('SensorSyncService: Sensordaten erfolgreich gesendet');
            } else {
              print('SensorSyncService: Fehler beim Senden - Status: ${response.statusCode}');
              print('SensorSyncService: Fehlerdetails: ${response.body}');
              allSuccess = false;
            }
          } catch (e) {
            print('SensorSyncService: Fehler bei Sensordaten-Übertragung: $e');
            allSuccess = false;
          }
        }
        
        // Nach erfolgreicher Übertragung eines Batches als synchronisiert markieren
        if (allSuccess) {
          await _dbHelper.markSensorDataAsSynced(batch);
          print('SensorSyncService: Batch mit ${batch.length} Sensordaten als synchronisiert markiert');
        }
      }
      
      // Aktualisiere letzte Synchronisationszeit bei Erfolg
      if (allSuccess) {
        _lastSyncTime = DateTime.now();
        await _saveSettings();
        print('SensorSyncService: Synchronisation abgeschlossen und Zeitstempel aktualisiert');
      }
      
      return allSuccess;
    } catch (e) {
      print('SensorSyncService: Kritischer Fehler bei Sensordaten-Synchronisation: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Hilfsfunktion zur Konvertierung von SensorData in JSON
  Map<String, dynamic> _convertSensorDataToJson(SensorData data) {
    // Erzeuge den korrekten JSON-Format, der mit dem Mongoose-Schema übereinstimmt
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'accelerometer': {
        'x': data.accelX,
        'y': data.accelY,
        'z': data.accelZ
      },
      'gyroscope': {
        'x': data.gyroX,
        'y': data.gyroY,
        'z': data.gyroZ
      },
      'magnetometer': {
        'x': data.magX,
        'y': data.magY,
        'z': data.magZ
      },
      'lightSensor': data.lightLevel,
      'proximitySensor': data.isNear
    };
  }

  // Hilfsfunktion zum Abrufen der Geräte-ID
  Future<String> _getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      
      if (deviceId == null || deviceId.isEmpty) {
        // Fallback: Generiere eine neue ID falls keine existiert
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', deviceId);
      }
      
      return deviceId;
    } catch (e) {
      print('SensorSyncService: Fehler beim Abrufen der Geräte-ID: $e');
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  // Cleanup
  @override
  void dispose() {
    stopPeriodicSync();
    super.dispose();
  }
}