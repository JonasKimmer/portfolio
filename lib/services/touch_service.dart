import 'package:flutter/material.dart';
import '../models/touch_point.dart';
import '../data/db_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TouchService extends ChangeNotifier {
  final List<TouchPoint> _touchPoints = [];
  Offset? _swipeStartPosition;
  int? _longPressStartTime;
  final DBHelper _dbHelper = DBHelper();
  
  TouchService() {
    // Lese zu Beginn alle unsynced Touch-Daten aus der SQLite-Datenbank
    _loadUnsyncedTouchPoints();
  }
  
  Future<void> _loadUnsyncedTouchPoints() async {
    try {
      final unsyncedPoints = await _dbHelper.getUnsyncedTouchData();
      _touchPoints.addAll(unsyncedPoints);
      notifyListeners();
      print('${unsyncedPoints.length} Touch-Punkte aus der Datenbank geladen');
    } catch (e) {
      print('Fehler beim Laden der Touch-Daten: $e');
    }
  }
  
  void addTouchPoint(double x, double y, String type, [String? direction]) {
    final touchPoint = TouchPoint(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      x: x,
      y: y,
      type: type,
      direction: direction,
    );
    
    // In-Memory-Speicher
    _touchPoints.add(touchPoint);
    
    // In SQLite-Datenbank speichern
    _dbHelper.saveTouchData(touchPoint).then((id) {
      print('Touch-Punkt in SQLite gespeichert mit ID: $id');
    }).catchError((error) {
      print('Fehler beim Speichern des Touch-Punkts: $error');
    });
    
    notifyListeners();
  }
  
  // Methoden für Swipes
  void startSwipe(double x, double y) {
    _swipeStartPosition = Offset(x, y);
    print("Swipe gestartet an Position: ($x, $y)");
  }
  
  void endSwipe(double x, double y, String direction) {
    if (_swipeStartPosition != null) {
      final touchPoint = TouchPoint(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        x: _swipeStartPosition!.dx,
        y: _swipeStartPosition!.dy,
        endX: x,
        endY: y,
        type: 'swipe',
        direction: direction,
      );
      
      // In-Memory-Speicher
      _touchPoints.add(touchPoint);
      
      // In SQLite-Datenbank speichern
      _dbHelper.saveTouchData(touchPoint).then((id) {
        print('Swipe in SQLite gespeichert mit ID: $id');
      }).catchError((error) {
        print('Fehler beim Speichern des Swipes: $error');
      });
      
      print("Swipe beendet: Start(${_swipeStartPosition!.dx}, ${_swipeStartPosition!.dy}), Ende($x, $y), Richtung: $direction");
      _swipeStartPosition = null;
      notifyListeners();
    } else {
      print("Fehler: Swipe-Ende ohne Start erkannt");
    }
  }
  
  // Methoden für lange Drucks
  void startLongPress(double x, double y) {
    _longPressStartTime = DateTime.now().millisecondsSinceEpoch;
    print("Langer Druck gestartet an Position: ($x, $y)");
  }
  
  void endLongPress(double x, double y) {
    if (_longPressStartTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final duration = now - _longPressStartTime!;
      
      final touchPoint = TouchPoint(
        timestamp: now,
        x: x,
        y: y,
        type: 'longpress',
        durationMs: duration,
      );
      
      // In-Memory-Speicher
      _touchPoints.add(touchPoint);
      
      // In SQLite-Datenbank speichern
      _dbHelper.saveTouchData(touchPoint).then((id) {
        print('Langer Druck in SQLite gespeichert mit ID: $id');
      }).catchError((error) {
        print('Fehler beim Speichern des langen Drucks: $error');
      });
      
      print("Langer Druck beendet: Position($x, $y), Dauer: $duration ms");
      _longPressStartTime = null;
      notifyListeners();
    } else {
      print("Fehler: Langer Druck-Ende ohne Start erkannt");
    }
  }
  
  List<TouchPoint> getAllTouchPoints() {
    return List.unmodifiable(_touchPoints);
  }
  
  int getTotalCount() {
    return _touchPoints.length;
  }
  
  int getCountByType(String type) {
    return _touchPoints.where((point) => point.type == type).length;
  }
  
  // Details für Swipes abrufen
  List<Map<String, dynamic>> getSwipeDetails() {
    return _touchPoints
      .where((point) => point.type == 'swipe')
      .map((point) => {
        'start': {'x': point.x, 'y': point.y},
        'end': {'x': point.endX, 'y': point.endY},
        'direction': point.direction,
      }).toList();
  }
  
  // Details für lange Drucks abrufen
  List<Map<String, dynamic>> getLongPressDetails() {
    return _touchPoints
      .where((point) => point.type == 'longpress')
      .map((point) => {
        'position': {'x': point.x, 'y': point.y},
        'duration': point.durationMs,
      }).toList();
  }
  
  void clearData() {
    _touchPoints.clear();
    notifyListeners();
  }

  // Die manuelle Synchronisationsmethode kann entfernt werden, da die Synchronisation
  // jetzt zentral über den DataSyncService erfolgt
  // Falls Sie sie trotzdem behalten wollen, ändern Sie den API-Pfad:
  
  Future<void> syncTouchData() async {
    try {
      final touchPoints = getAllTouchPoints();
      
      if (touchPoints.isEmpty) {
        print('Keine Touch-Daten zum Synchronisieren');
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:3000/api/touch'), // URL geändert von /api/touch/bulk
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'touchData': touchPoints.map((point) => {
          'timestamp': point.timestamp,
          'x': point.x,
          'y': point.y,
          'type': point.type,
          'direction': point.direction,
          'endX': point.endX,
          'endY': point.endY,
          'durationMs': point.durationMs
        }).toList()})
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Touch-Daten erfolgreich synchronisiert');
        // Wir löschen die Daten nicht mehr, da sie jetzt vom DataSyncService als synchronisiert markiert werden
        // clearData(); 
      } else {
        print('Synchronisation fehlgeschlagen: ${response.body}');
      }
    } catch (e) {
      print('Fehler bei der Synchronisation: $e');
    }
  }
}