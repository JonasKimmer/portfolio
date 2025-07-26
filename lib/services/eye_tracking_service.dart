import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../data/db_helper.dart';
import '../models/eye_tracking_data.dart';

class EyeTrackingService with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  bool _isTracking = false;
  List<EyeTrackingData> _eyeTrackingData = [];
  int _blinkCount = 0;
  double _gazePositionX = 0.5;
  double _gazePositionY = 0.5;
  
  // Für die Heatmap
  List<List<int>> _heatmapGrid = [];
  final int heatmapRows = 10;
  final int heatmapCols = 10;
  
  // Für Blinzelerkennung
  bool _wasBlinking = false;
  
  // Getters
  bool get isTracking => _isTracking;
  List<EyeTrackingData> get eyeTrackingData => List.unmodifiable(_eyeTrackingData);
  int get blinkCount => _blinkCount;
  double get gazePositionX => _gazePositionX;
  double get gazePositionY => _gazePositionY;
  
  // Initialisierung
  EyeTrackingService() {
    _initializeHeatmapGrid();
    _loadUnsyncedEyeTrackingData();
  }
  
  Future<void> _loadUnsyncedEyeTrackingData() async {
    try {
      final unsyncedData = await _dbHelper.getUnsyncedEyeTrackingData();
      _eyeTrackingData = unsyncedData;
      notifyListeners();
      print('${unsyncedData.length} Eye-Tracking-Datensätze aus der Datenbank geladen');
    } catch (e) {
      print('Fehler beim Laden der Eye-Tracking-Daten: $e');
    }
  }
  
  void _initializeHeatmapGrid() {
    _heatmapGrid = List.generate(
      heatmapRows, 
      (_) => List.generate(heatmapCols, (_) => 0)
    );
  }
  
  // Tracking starten
  void startTracking() {
    if (!_isTracking) {
      _isTracking = true;
      //_eyeTrackingData = []; // Wir löschen nicht mehr, um vorhandene Daten zu behalten
      _blinkCount = 0;
      _initializeHeatmapGrid();
      notifyListeners();
    }
  }
  
  // Tracking stoppen
  void stopTracking() {
    if (_isTracking) {
      _isTracking = false;
      notifyListeners();
    }
  }
  
  // Blickposition aktualisieren
  void updateGazePosition(Face face, Size imageSize) {
    if (!isTracking) return;
    
    // Blickrichtung basierend auf Kopfrotation berechnen
    // (Kopf nach links gedreht bedeutet Blick nach rechts und umgekehrt)
    if (face.headEulerAngleY != null) {
      // Wir kehren hier die Richtung um, da die Kamera gespiegelt ist
      // headEulerAngleY negativ = Kopf nach rechts gedreht = Blick nach rechts
      // Wert zwischen -30 und +30 Grad auf 0.0 bis 1.0 abbilden
      _gazePositionX = (face.headEulerAngleY! + 30) / 60;
      _gazePositionX = 1.0 - _gazePositionX; // Umkehren wegen Kameraspiegelung
      _gazePositionX = _gazePositionX.clamp(0.0, 1.0); // Auf 0.0-1.0 begrenzen
    }
    
    // Vertikale Blickposition aus headEulerAngleX (Kopfneigung)
    if (face.headEulerAngleX != null) {
      // Kopf nach unten geneigt = Blick nach unten
      // Wert zwischen -30 und +30 Grad auf 0.0 bis 1.0 abbilden
      _gazePositionY = (face.headEulerAngleX! + 30) / 60;
      _gazePositionY = _gazePositionY.clamp(0.0, 1.0); // Auf 0.0-1.0 begrenzen
    }
    
    // Heatmap aktualisieren
    _updateHeatmap();
    
    // Blinzeln erkennen und zählen
    _detectBlink(face);
    
    // Eye-Tracking-Daten speichern
    _saveEyeTrackingData(face);
    
    notifyListeners();
  }
  
  // Blinzeln erkennen
  void _detectBlink(Face face) {
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0;
    
    // Durchschnittliche Augenöffnung berechnen
    final avgEyeOpen = (leftEyeOpen + rightEyeOpen) / 2;
    
    // Blinzeln definieren als Augenöffnung < 0.3
    final isBlinking = avgEyeOpen < 0.3;
    
    // Blinzelzähler erhöhen, wenn Übergang von offen zu geschlossen
    if (isBlinking && !_wasBlinking) {
      _blinkCount++;
    }
    
    _wasBlinking = isBlinking;
  }
  
  // Eye-Tracking-Daten speichern
  void _saveEyeTrackingData(Face face) {
    // Blickrichtung bestimmen
    String direction = 'center';
    if (_gazePositionX < 0.4) direction = 'left';
    else if (_gazePositionX > 0.6) direction = 'right';
    else if (_gazePositionY < 0.4) direction = 'up';
    else if (_gazePositionY > 0.6) direction = 'down';
    
    // Augenposition als Map
    Map<String, double> eyePosition = {
      'x': _gazePositionX,
      'y': _gazePositionY,
    };
    
    // EyeTrackingData-Objekt erstellen
    final eyeTrackingData = EyeTrackingData(
      timestamp: DateTime.now(),
      isUserLooking: true,
      direction: direction,
      eyePosition: eyePosition,
    );
    
    // In-Memory-Speicher aktualisieren
    _eyeTrackingData.add(eyeTrackingData);
    
    // In SQLite-Datenbank speichern
    _dbHelper.saveEyeTrackingData(eyeTrackingData).then((id) {
      print('Eye-Tracking-Daten in SQLite gespeichert mit ID: $id');
    }).catchError((error) {
      print('Fehler beim Speichern der Eye-Tracking-Daten: $error');
    });
    
    // Beschränke die In-Memory-Liste auf maximal 20 Einträge
    if (_eyeTrackingData.length > 20) {
      _eyeTrackingData.removeAt(0);
    }
  }
  
  // Heatmap aktualisieren
  void _updateHeatmap() {
    // Position auf das Heatmap-Raster abbilden
    final row = (_gazePositionY * (heatmapRows - 1)).round();
    final col = (_gazePositionX * (heatmapCols - 1)).round();
    
    // Sicherstellen, dass wir im gültigen Bereich sind
    if (row >= 0 && row < heatmapRows && col >= 0 && col < heatmapCols) {
      // Zellwert erhöhen
      _heatmapGrid[row][col]++;
    }
  }
  
  // Heatmap-Daten abrufen
  List<List<int>> getHeatmapData() {
    return _heatmapGrid;
  }
  
  // Manuelle Methode zum Hinzufügen von Eye-Tracking-Daten (falls nötig)
  void addEyeTrackingData({
    required bool isLooking,
    String? direction,
    Map<String, double>? position
  }) {
    if (_isTracking) {
      final data = EyeTrackingData(
        timestamp: DateTime.now(),
        isUserLooking: isLooking,
        direction: direction,
        eyePosition: position,
      );
      
      // In-Memory-Speicher
      _eyeTrackingData.add(data);
      
      // In SQLite-Datenbank speichern
      _dbHelper.saveEyeTrackingData(data).then((id) {
        print('Manuell eingegebene Eye-Tracking-Daten in SQLite gespeichert mit ID: $id');
      }).catchError((error) {
        print('Fehler beim Speichern der manuellen Eye-Tracking-Daten: $error');
      });
      
      // Beschränke die Liste auf maximal 20 Einträge
      if (_eyeTrackingData.length > 20) {
        _eyeTrackingData.removeAt(0);
      }
      
      notifyListeners();
    }
  }
  
  // Eye-Tracking-Daten löschen
  void clearEyeTrackingData() {
    _eyeTrackingData = [];
    notifyListeners();
  }
}