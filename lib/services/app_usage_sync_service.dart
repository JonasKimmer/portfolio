import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db_helper.dart';

class AppUsageSyncService with ChangeNotifier {
  static const String _baseUrl = 'http://localhost:3000/api';

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
  AppUsageSyncService({
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
    _isAutoSyncEnabled = prefs.getBool('app_usage_auto_sync_enabled') ?? true;
    _syncIntervalMinutes = prefs.getInt('app_usage_sync_interval') ?? 5;
    final lastSyncTimeString = prefs.getString('app_usage_last_sync_time');
    if (lastSyncTimeString != null) {
      _lastSyncTime = DateTime.parse(lastSyncTimeString);
    }
    notifyListeners();
  }
  
  // Einstellungen speichern
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_usage_auto_sync_enabled', _isAutoSyncEnabled);
    await prefs.setInt('app_usage_sync_interval', _syncIntervalMinutes);
    if (_lastSyncTime != null) {
      await prefs.setString('app_usage_last_sync_time', _lastSyncTime!.toIso8601String());
    }
  }
  
  // Periodische Synchronisation starten
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (_) => syncAppUsageData()
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
  
  // App-Nutzungsdaten synchronisieren
  Future<bool> syncAppUsageData() async {
    if (_isSyncing) {
      print('App-Nutzungs-Synchronisation läuft bereits');
      return false;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      final unsyncedAppUsageData = await _dbHelper.getUnsyncedAppUsageData();
      
      if (unsyncedAppUsageData.isEmpty) {
        print('Keine App-Nutzungsdaten zum Synchronisieren');
        _isSyncing = false;
        notifyListeners();
        return true;
      }
      
      // Batch-Größe für die Übertragung
      const int batchSize = 50;
      bool allSuccess = true;
      
      // Sende Daten in Batches
      for (int i = 0; i < unsyncedAppUsageData.length; i += batchSize) {
        final end = (i + batchSize < unsyncedAppUsageData.length) 
            ? i + batchSize 
            : unsyncedAppUsageData.length;
        
        final batch = unsyncedAppUsageData.sublist(i, end);
        
        // Format der Daten anpassen, um mit dem Server-Modell übereinzustimmen
        final formattedData = batch.map((item) => {
          'deviceId': 'this_device', 
          'packageName': item['packageName'],
          'appName': item['appName'],
          'usageDuration': item['usageDuration'],
          'openCount': item['openCount'],
          'timestamp': item['timestamp'],
          '_id': item['id'] 
        }).toList();
        
        // Direktes Senden der Daten
        final requestBody = json.encode(formattedData);
        
        print('Sende App-Nutzungsdaten (Batch ${i ~/ batchSize + 1}/${(unsyncedAppUsageData.length / batchSize).ceil()}) an $_baseUrl/appusage');
        print('Anfragedaten (ersten 2 Einträge): ${json.encode(formattedData.take(2).toList())}');
        
        final response = await http.post(
          Uri.parse('$_baseUrl/appusage'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );
        
        print('App-Nutzungsdaten-Antwort: ${response.statusCode} ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Markiere Batch als synchronisiert
          await _dbHelper.markAppUsageDataAsSynced(batch);
        } else {
          print('Fehler beim Synchronisieren der App-Nutzungsdaten (Batch ${i ~/ batchSize + 1}): ${response.statusCode} ${response.body}');
          allSuccess = false;
        }
      }
      
      // Aktualisiere letzte Synchronisationszeit
      if (allSuccess) {
        _lastSyncTime = DateTime.now();
        await _saveSettings();
      }
      
      return allSuccess;
    } catch (e) {
      print('Fehler beim Synchronisieren der App-Nutzungsdaten: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  // Cleanup
  void dispose() {
    stopPeriodicSync();
    super.dispose();
  }
}