class SensorData {
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double magX;
  final double magY;
  final double magZ;
  final double lightLevel; 
  final bool isNear;     

  SensorData({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.magX,
    required this.magY,
    required this.magZ,
    this.lightLevel = 0.0, 
    this.isNear = false,   
  });

  SensorData copyWith({
    double? accelX,
    double? accelY,
    double? accelZ,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? magX,
    double? magY,
    double? magZ,
    double? lightLevel,
    bool? isNear,
  }) {
    return SensorData(
      accelX: accelX ?? this.accelX,
      accelY: accelY ?? this.accelY,
      accelZ: accelZ ?? this.accelZ,
      gyroX: gyroX ?? this.gyroX,
      gyroY: gyroY ?? this.gyroY,
      gyroZ: gyroZ ?? this.gyroZ,
      magX: magX ?? this.magX,
      magY: magY ?? this.magY,
      magZ: magZ ?? this.magZ,
      lightLevel: lightLevel ?? this.lightLevel,
      isNear: isNear ?? this.isNear,
    );
  }
}