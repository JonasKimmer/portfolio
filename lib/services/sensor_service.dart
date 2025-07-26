import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import '../models/sensor_data.dart';
import '../data/db_helper.dart';

class SensorService extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper(); 
  
  SensorData _sensorData = SensorData(
    accelX: 0,
    accelY: 0,
    accelZ: 0,
    gyroX: 0,
    gyroY: 0,
    gyroZ: 0,
    magX: 0,
    magY: 0,
    magZ: 0,
    lightLevel: 0,
    isNear: false,
  );
  
  SensorData get sensorData => _sensorData;
  
  double _lastAccelMagnitude = 0;
  int _proximityCounter = 0;
  DateTime _lastProximityChange = DateTime.now();
  
  // Zeitintervall für Datenbankeinträge
  DateTime? _lastDatabaseSave;
  static const Duration _databaseSaveInterval = Duration(seconds: 10);
  
  SensorService() {
    _initSensors();
  }
  
  void _initSensors() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      _sensorData = _sensorData.copyWith(
        accelX: event.x,
        accelY: event.y,
        accelZ: event.z,
      );
      
      _simulateLightSensor(event);
      _trySaveToDatabaseWithThrottle();
      
      notifyListeners();
    });
    
    gyroscopeEvents.listen((GyroscopeEvent event) {
      _sensorData = _sensorData.copyWith(
        gyroX: event.x,
        gyroY: event.y,
        gyroZ: event.z,
      );
      
      _simulateProximitySensor(event);
      _trySaveToDatabaseWithThrottle();
      
      notifyListeners();
    });
    
    magnetometerEvents.listen((MagnetometerEvent event) {
      _sensorData = _sensorData.copyWith(
        magX: event.x,
        magY: event.y,
        magZ: event.z,
      );
      
      _trySaveToDatabaseWithThrottle();
      
      notifyListeners();
    });
  }
  
  // Neue Methode zum gedrosselten Speichern
  void _trySaveToDatabaseWithThrottle() {
    final now = DateTime.now();
    
    // Speichern alle 10 Sekunden
    if (_lastDatabaseSave == null || 
        now.difference(_lastDatabaseSave!) >= _databaseSaveInterval) {
      _saveCurrentSensorDataToDatabase();
      _lastDatabaseSave = now;
    }
  }
  
  // Methode zum Speichern der aktuellen Sensordaten
  Future<void> _saveCurrentSensorDataToDatabase() async {
    try {
      print('Speichere Sensordaten in Datenbank');
      print('Aktuelle Daten: $sensorData');
      
      final result = await _dbHelper.saveSensorData(sensorData);
      
      print('Sensordaten in Datenbank gespeichert. ID: $result');
    } catch (e) {
      print('Fehler beim Speichern der Sensordaten: $e');
    }
  }

  // Lichtsensor-Simulation basierend auf Beschleunigungsdaten
  void _simulateLightSensor(AccelerometerEvent event) {
    // Gesamtbeschleunigung berechnen (ohne Schwerkraft)
    double accelMagnitude = _calculateMagnitude(event.x, event.y, event.z - 9.8);
    
    // Nur aktualisieren, wenn sich die Beschleunigung signifikant geändert hat
    if ((accelMagnitude - _lastAccelMagnitude).abs() > 0.3) {
      _lastAccelMagnitude = accelMagnitude;
      
      // Simulierter Lichtwert basierend auf Bewegung und Zeit
      double time = DateTime.now().millisecondsSinceEpoch / 1000;
      double baseLight = 300 + 200 * (0.5 + 0.5 * (time % 10) / 10); // Basiswert mit zeitlicher Variation
      double movementFactor = accelMagnitude * 50; // Bewegung erhöht den Lichtwert
      
      double simulatedLight = baseLight + movementFactor;
      simulatedLight = simulatedLight.clamp(50, 1000); // Vernünftiger Wertebereich
      
      _sensorData = _sensorData.copyWith(lightLevel: simulatedLight);
    }
  }
  
  // Nähe-Sensor-Simulation basierend auf Gyroskop-Daten
  void _simulateProximitySensor(GyroscopeEvent event) {
    // Gesamtrotationsgeschwindigkeit berechnen
    double rotationMagnitude = _calculateMagnitude(event.x, event.y, event.z);
    
    // Wenn das Gerät stark gedreht wird, erhöhen wir den Nähe-Zähler
    if (rotationMagnitude > 1.0) {
      _proximityCounter++;
      
      // Status nur ändern, wenn genug Zeit seit der letzten Änderung vergangen ist
      // und die Drehung stark genug war
      if (_proximityCounter > 3 &&
          DateTime.now().difference(_lastProximityChange).inMilliseconds > 2000) {
        _sensorData = _sensorData.copyWith(isNear: !_sensorData.isNear);
        _lastProximityChange = DateTime.now();
        _proximityCounter = 0;
      }
    } else {
      // Zähler langsam zurücksetzen, wenn keine starke Rotation
      _proximityCounter = _proximityCounter > 0 ? _proximityCounter - 1 : 0;
    }
  }
  
  // Hilfsfunktion zur Berechnung der Magnitude eines 3D-Vektors
  double _calculateMagnitude(double x, double y, double z) {
    return math.sqrt(x * x + y * y + z * z);
  }

  void resetData() {
    // Setze alle Sensorwerte auf ihre Standardwerte zurück
    _sensorData = SensorData(
      accelX: 0,
      accelY: 0,
      accelZ: 0,
      gyroX: 0,
      gyroY: 0,
      gyroZ: 0,
      magX: 0,
      magY: 0,
      magZ: 0,
      lightLevel: 0,
      isNear: false,
    );
    
    // Setze Simulationsvariablen zurück
    _lastAccelMagnitude = 0;
    _proximityCounter = 0;
    _lastProximityChange = DateTime.now();
    
    // Benachrichtige Listener, um UI zu aktualisieren
    notifyListeners();
    
    print("Sensor-Daten zurückgesetzt");
  }
}