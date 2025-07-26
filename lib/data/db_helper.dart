import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import '../models/device_info.dart';
import '../models/sensor_data.dart';
import '../models/touch_point.dart';
import '../models/eye_tracking_data.dart';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

class DBHelper {
  static Database? _database;
  static const String dbName = 'adaptive_ui_data.db';
  
  // Singleton-Muster: Wir stellen sicher, dass nur eine Instanz der Datenbank existiert
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  // Datenbank initialisieren
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), dbName);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }
  
  // Tabellen erstellen
  Future<void> _createTables(Database db, int version) async {
    // Geräteinfo-Tabelle
    await db.execute('''
      CREATE TABLE device_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model TEXT NOT NULL,
        manufacturer TEXT NOT NULL,
        os_version TEXT NOT NULL,
        screen_brightness REAL NOT NULL,
        is_portrait INTEGER NOT NULL,
        is_one_hand_mode INTEGER NOT NULL,
        is_right_handed INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');
    
    // Sensordaten-Tabelle
    await db.execute('''
      CREATE TABLE sensor_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accel_x REAL NOT NULL,
        accel_y REAL NOT NULL,
        accel_z REAL NOT NULL,
        gyro_x REAL NOT NULL,
        gyro_y REAL NOT NULL,
        gyro_z REAL NOT NULL,
        mag_x REAL NOT NULL,
        mag_y REAL NOT NULL,
        mag_z REAL NOT NULL,
        light_level REAL NOT NULL,
        is_near INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');
    
    // Touch-Daten-Tabelle
    await db.execute('''
      CREATE TABLE touch_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        type TEXT NOT NULL,
        direction TEXT,
        end_x REAL,
        end_y REAL,
        duration_ms INTEGER,
        synced INTEGER DEFAULT 0
      )
    ''');
    
    // Eye-Tracking-Daten-Tabelle
    await db.execute('''
      CREATE TABLE eye_tracking_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        is_user_looking INTEGER NOT NULL,
        direction TEXT,
        eye_position TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
    
    // App-Nutzungs-Tabelle
    await db.execute('''
      CREATE TABLE app_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration INTEGER,
        open_count INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 0
      )
    ''');
  }
  
  // === Geräteinfo-Methoden ===
  
  // Speichern von Geräteinfo
  Future<int> saveDeviceInfo(DeviceInfo info) async {
    final db = await database;
    
    return await db.insert(
      'device_info',
      {
        'model': info.model,
        'manufacturer': info.manufacturer,
        'os_version': info.osVersion,
        'screen_brightness': info.screenBrightness,
        'is_portrait': info.isPortrait ? 1 : 0,
        'is_one_hand_mode': info.isOneHandMode ? 1 : 0,
        'is_right_handed': info.isRightHanded ? 1 : 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'synced': 0
      },
    );
  }
  
  // Abrufen von nicht synchronisierten Geräteinfos
  Future<List<DeviceInfo>> getUnsyncedDeviceInfo() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'device_info',
      where: 'synced = ?',
      whereArgs: [0],
    );
    
    return List.generate(maps.length, (i) {
      return DeviceInfo(
        model: maps[i]['model'],
        manufacturer: maps[i]['manufacturer'],
        osVersion: maps[i]['os_version'],
        screenBrightness: maps[i]['screen_brightness'],
        isPortrait: maps[i]['is_portrait'] == 1,
        isOneHandMode: maps[i]['is_one_hand_mode'] == 1,
        isRightHanded: maps[i]['is_right_handed'] == 1,
      );
    });
  }
  
  // Markieren von Geräteinfos als synchronisiert
Future<void> markDeviceInfoAsSynced(List<DeviceInfo> deviceInfos) async {
  final db = await database;
  
  // Begin transaction
  await db.transaction((txn) async {
    for (var deviceInfo in deviceInfos) {
      // Effizientere Abfrage mit LIMIT 1
      final List<Map<String, dynamic>> results = await txn.query(
        'device_info',
        columns: ['id'],
        where: 'model = ? AND manufacturer = ? AND os_version = ? AND synced = 0',
        whereArgs: [deviceInfo.model, deviceInfo.manufacturer, deviceInfo.osVersion],
        limit: 1
      );
      
      if (results.isNotEmpty) {
        await txn.update(
          'device_info',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [results.first['id']]
        );
        print('Gerät mit ID ${results.first['id']} als synchronisiert markiert');
      }
    }
  });
  
  print('Alle Geräteinfos erfolgreich als synchronisiert markiert');
}
  
  // === Sensordaten-Methoden ===
  
  // Speichern von Sensordaten
  Future<int> saveSensorData(SensorData data) async {
    final db = await database;
    
    return await db.insert(
      'sensor_data',
      {
        'accel_x': data.accelX,
        'accel_y': data.accelY,
        'accel_z': data.accelZ,
        'gyro_x': data.gyroX,
        'gyro_y': data.gyroY,
        'gyro_z': data.gyroZ,
        'mag_x': data.magX,
        'mag_y': data.magY,
        'mag_z': data.magZ,
        'light_level': data.lightLevel,
        'is_near': data.isNear ? 1 : 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'synced': 0
      },
    );
  }
  
  // Abrufen von nicht synchronisierten Sensordaten
  Future<List<SensorData>> getUnsyncedSensorData() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'sensor_data',
      where: 'synced = ?',
      whereArgs: [0],
      limit: 500, 
    );
    
    return List.generate(maps.length, (i) {
      return SensorData(
        accelX: maps[i]['accel_x'],
        accelY: maps[i]['accel_y'],
        accelZ: maps[i]['accel_z'],
        gyroX: maps[i]['gyro_x'],
        gyroY: maps[i]['gyro_y'],
        gyroZ: maps[i]['gyro_z'],
        magX: maps[i]['mag_x'],
        magY: maps[i]['mag_y'],
        magZ: maps[i]['mag_z'],
        lightLevel: maps[i]['light_level'],
        isNear: maps[i]['is_near'] == 1,
      );
    });
  }
  
  // Markieren von Sensordaten als synchronisiert
Future<void> markSensorDataAsSynced(List<SensorData> sensorDataList) async {
  final db = await database;
  
  await db.transaction((txn) async {
    for (var data in sensorDataList) {
      final List<Map<String, dynamic>> results = await txn.query(
        'sensor_data',
        columns: ['id'],
        where: 'accel_x = ? AND accel_y = ? AND accel_z = ? AND synced = 0',
        whereArgs: [data.accelX, data.accelY, data.accelZ],
        limit: 1 
      );
      
      if (results.isNotEmpty) {
        await txn.update(
          'sensor_data',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [results.first['id']]
        );
        print('Sensordaten mit ID ${results.first['id']} als synchronisiert markiert');
      }
    }
  });
  
  print('Sensordaten erfolgreich als synchronisiert markiert');
}
  
  // === Touch-Daten-Methoden ===
  
  // Speichern von Touch-Daten
  Future<int> saveTouchData(TouchPoint data) async {
    final db = await database;
    
    return await db.insert(
      'touch_data',
      {
        'timestamp': data.timestamp,
        'x': data.x,
        'y': data.y,
        'type': data.type,
        'direction': data.direction,
        'end_x': data.endX,
        'end_y': data.endY,
        'duration_ms': data.durationMs,
        'synced': 0
      },
    );
  }
  
  // Abrufen von nicht synchronisierten Touch-Daten
  Future<List<TouchPoint>> getUnsyncedTouchData() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'touch_data',
      where: 'synced = ?',
      whereArgs: [0],
      limit: 500,
    );
    
    return List.generate(maps.length, (i) {
      return TouchPoint(
        timestamp: maps[i]['timestamp'],
        x: maps[i]['x'],
        y: maps[i]['y'],
        type: maps[i]['type'],
        direction: maps[i]['direction'],
        endX: maps[i]['end_x'],
        endY: maps[i]['end_y'],
        durationMs: maps[i]['duration_ms'],
      );
    });
  }
  
  // Markieren von Touch-Daten als synchronisiert
  Future<void> markTouchDataAsSynced(List<TouchPoint> touchDataList) async {
    final db = await database;
    
    final Batch batch = db.batch();
    final int count = touchDataList.length;
    
    if (count > 0) {
      batch.rawUpdate('''
        UPDATE touch_data 
        SET synced = 1 
        WHERE id IN (
          SELECT id FROM touch_data 
          WHERE synced = 0 
          ORDER BY timestamp ASC 
          LIMIT ?
        )
      ''', [count]);
    }
    
    await batch.commit(noResult: true);
  }
  
  // === Eye-Tracking-Daten-Methoden ===
  
  // Speichern von Eye-Tracking-Daten
  Future<int> saveEyeTrackingData(EyeTrackingData data) async {
    final db = await database;
    
    String? eyePositionJson;
    if (data.eyePosition != null) {
      eyePositionJson = json.encode(data.eyePosition);
    }
    
    return await db.insert(
      'eye_tracking_data',
      {
        'timestamp': data.timestamp.millisecondsSinceEpoch,
        'is_user_looking': data.isUserLooking ? 1 : 0,
        'direction': data.direction,
        'eye_position': eyePositionJson,
        'synced': 0
      },
    );
  }
  
  // Abrufen von nicht synchronisierten Eye-Tracking-Daten
  Future<List<EyeTrackingData>> getUnsyncedEyeTrackingData() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'eye_tracking_data',
      where: 'synced = ?',
      whereArgs: [0],
      limit: 300,
    );
    
    return List.generate(maps.length, (i) {
      Map<String, double>? eyePosition;
      
      if (maps[i]['eye_position'] != null) {
        final eyePositionData = json.decode(maps[i]['eye_position']);
        eyePosition = Map<String, double>.from(eyePositionData);
      }
      
      return EyeTrackingData(
        timestamp: DateTime.fromMillisecondsSinceEpoch(maps[i]['timestamp']),
        isUserLooking: maps[i]['is_user_looking'] == 1,
        direction: maps[i]['direction'],
        eyePosition: eyePosition,
      );
    });
  }
  
  // Markieren von Eye-Tracking-Daten als synchronisiert
  Future<void> markEyeTrackingDataAsSynced(List<EyeTrackingData> eyeTrackingDataList) async {
    final db = await database;
    
    final Batch batch = db.batch();
    final int count = eyeTrackingDataList.length;
    
    if (count > 0) {
      batch.rawUpdate('''
        UPDATE eye_tracking_data 
        SET synced = 1 
        WHERE id IN (
          SELECT id FROM eye_tracking_data 
          WHERE synced = 0 
          ORDER BY timestamp ASC 
          LIMIT ?
        )
      ''', [count]);
    }
    
    await batch.commit(noResult: true);
  }
  
  // === App-Usage-Methoden ===
  
  // Speichern von App-Nutzungsdaten
  Future<int> saveAppUsageData(String packageName, String appName, int startTime) async {
    final db = await database;
    
    print("Speichere App-Start: $packageName, $appName, $startTime");
    
    return await db.insert(
      'app_usage',
      {
        'package_name': packageName,
        'app_name': appName,
        'start_time': startTime,
        'end_time': null,
        'duration': null,
        'open_count': 1,
        'synced': 0
      },
    );
  }
  
  // Aktualisieren von App-Nutzungsdaten (wenn App geschlossen wird)
  Future<int> updateAppUsageData(String packageName, int endTime) async {
    final db = await database;
    
    print("Aktualisiere App-Ende: $packageName, $endTime");
    
    final List<Map<String, dynamic>> maps = await db.query(
      'app_usage',
      where: 'package_name = ? AND end_time IS NULL',
      whereArgs: [packageName],
      orderBy: 'start_time DESC',
      limit: 1,
    );
    
    if (maps.isEmpty) {
      print("Kein offener Eintrag für $packageName gefunden");
      return 0; 
    }
    
    final int id = maps[0]['id'];
    final int startTime = maps[0]['start_time'];
    final int duration = endTime - startTime;
    
    print("Gefundener Eintrag ID: $id, Start: $startTime, Dauer: $duration");
    
    return await db.update(
      'app_usage',
      {
        'end_time': endTime,
        'duration': duration,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // Abrufen von nicht synchronisierten App-Nutzungsdaten für die Synchronisierung mit dem Server
  Future<List<Map<String, dynamic>>> getUnsyncedAppUsageData() async {
    final db = await database;
    
    print("Abfrage von unsynced App-Nutzungsdaten gestartet");
    
    final List<Map<String, dynamic>> dbResults = await db.query(
      'app_usage',
      where: 'synced = ?',
      whereArgs: [0],
    );
    
    print("Gefundene unsynced App-Nutzungsdaten: ${dbResults.length}");
    
    return dbResults.map((row) => {
      'packageName': row['package_name'],
      'appName': row['app_name'],
      'timestamp': row['start_time'],
      'usageDuration': row['duration'] ?? 0,
      'openCount': row['open_count'] ?? 1,
      'deviceId': 'this_device',
      'id': row['id']
    }).toList();
  }
  
  // Abrufen der App-Nutzungsdaten für die UI
Future<Map<String, dynamic>> getAppUsageForUI() async {
  final db = await database;
  
  print("Abfrage aller App-Nutzungsdaten für die UI gestartet");
  
  try {
    final latestAppData = await db.query(
      'app_usage',
      orderBy: 'start_time DESC',
      limit: 1
    );
    
    if (latestAppData.isEmpty) {
      print("Keine App-Nutzungsdaten gefunden");
      return {
        "success": true,
        "count": 0,
        "data": []
      };
    }
    
    String packageName = latestAppData[0]['package_name'] as String;
    String appName = latestAppData[0]['app_name'] as String;
    
    final totalDurationResult = await db.rawQuery(
      'SELECT SUM(duration) as total_duration FROM app_usage WHERE package_name = ? AND duration IS NOT NULL',
      [packageName]
    );
    
    // Zählen aller App-Öffnungen heute für diese App
    final today = DateTime.now().toIso8601String().split('T')[0];
    final startOfDay = DateTime.parse('${today}T00:00:00').millisecondsSinceEpoch;
    
    final todayOpenCountResult = await db.rawQuery(
      'SELECT COUNT(*) as today_opens FROM app_usage WHERE package_name = ? AND start_time >= ?',
      [packageName, startOfDay]
    );
    
    int totalDuration = Sqflite.firstIntValue(totalDurationResult) ?? 0;
    int todayOpenCount = Sqflite.firstIntValue(todayOpenCountResult) ?? 0;
    
    print("Gefundene App-Daten:");
    print("  App: $appName ($packageName)");
    print("  Gesamtnutzungsdauer: $totalDuration Sekunden");
    print("  Öffnungen heute: $todayOpenCount");
    
    if (todayOpenCount == 0) {
      todayOpenCount = 1;
      print("  Öffnungen heute korrigiert auf Mindestwert: $todayOpenCount");
    }
    
    // Formatierte Daten zurückgeben
    return {
      "success": true,
      "count": 1,
      "data": [
        {
          "packageName": packageName,
          "appName": appName,
          "usageDuration": totalDuration > 0 ? totalDuration : 60, 
          "openCount": todayOpenCount,
          "timestamp": DateTime.now().millisecondsSinceEpoch
        }
      ]
    };
  } catch (e) {
    print("Fehler bei getAppUsageForUI: $e");
    return {
      "success": true,
      "count": 0,
      "data": []
    };
  }
}
  
  // Markieren von App-Nutzungsdaten als synchronisiert
  Future<void> markAppUsageDataAsSynced(List<Map<String, dynamic>> appUsageDataList) async {
    final db = await database;
    
    final Batch batch = db.batch();
    
    for (var data in appUsageDataList) {
      if (data.containsKey('id')) {
        batch.update(
          'app_usage',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [data['id']],
        );
      }
    }
    
    await batch.commit(noResult: true);
  }

  Future<int> saveAppUsageDataMap(Map<String, dynamic> data) async {
    print("Speichere App-Nutzungsdaten: $data"); 
    final db = await database;
    
    final timestamp = data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
    
    return await db.insert(
      'app_usage',
      {
        'package_name': data['packageName'],
        'app_name': data['appName'],
        'start_time': timestamp,
        'end_time': timestamp,  
        'duration': data['usageDuration'] ?? 0,
        'open_count': data['openCount'] ?? 1,
        'synced': 0
      },
    );
  }
  
  // Debug-Methode zum Anzeigen aller App-Nutzungsdaten
  Future<void> debugPrintAppUsageData() async {
    final db = await database;
    
    final List<Map<String, dynamic>> allData = await db.query('app_usage');
    
    print("==== APP USAGE DATENBANK DEBUG ====");
    print("Anzahl der Einträge: ${allData.length}");
    
    for (var row in allData) {
      print("ID: ${row['id']}");
      print("  Paket: ${row['package_name']}");
      print("  App: ${row['app_name']}");
      print("  Start: ${DateTime.fromMillisecondsSinceEpoch(row['start_time'])}");
      if (row['end_time'] != null) {
        print("  Ende: ${DateTime.fromMillisecondsSinceEpoch(row['end_time'])}");
      } else {
        print("  Ende: null");
      }
      print("  Dauer: ${row['duration']} Sekunden");
      print("  Öffnungen: ${row['open_count']}");
      print("  Synced: ${row['synced']}");
      print("-------------------------------");
    }
  }

Future<void> debugPrintDeviceInfo() async {
  final db = await database;
  
  final List<Map<String, dynamic>> allData = await db.query('device_info');
  
  print("==== DEVICE INFO DATENBANK DEBUG ====");
  print("Anzahl der Einträge: ${allData.length}");
  
  for (var row in allData) {
    print("ID: ${row['id']}");
    print("  Modell: ${row['model']}");
    print("  Hersteller: ${row['manufacturer']}");
    print("  OS-Version: ${row['os_version']}");
    print("  Synced: ${row['synced']}");
    print("-------------------------------");
  }
}
  
  Future<void> debugPrintSensorData() async {
  final db = await database;
  
  final List<Map<String, dynamic>> allData = await db.query('sensor_data');
  
  print("==== SENSOR DATENBANK DEBUG ====");
  print("Anzahl der Einträge: ${allData.length}");
  
  for (var row in allData) {
    print("ID: ${row['id']}");
    print("  AccelX: ${row['accel_x']}");
    print("  AccelY: ${row['accel_y']}");
    print("  AccelZ: ${row['accel_z']}");
    print("  Timestamp: ${DateTime.fromMillisecondsSinceEpoch(row['timestamp'])}");
    print("  Synced: ${row['synced']}");
    print("-------------------------------");
  }
}
  // Abrufen der Anzahl unsynchronisierter Daten pro Tabelle
  Future<int> getUnsyncedDataCount(String tableName) async {
    final db = await database;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE synced = 0'
    );
    
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  Future<void> clearAllData() async {
    final db = await database;
    
    await db.delete('device_info');
    await db.delete('sensor_data');
    await db.delete('touch_data');
    await db.delete('eye_tracking_data');
    await db.delete('app_usage');
  }
  
  // Datenbank schließen
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
} 