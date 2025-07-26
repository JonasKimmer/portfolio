class EyeTrackingData {
  final DateTime timestamp;
  final bool isUserLooking;
  final String? direction; // Blickrichtung: links, rechts, oben, unten, Mitte
  final Map<String, double>? eyePosition;
  
  final double? gazePositionX;
  final double? gazePositionY;
  
  EyeTrackingData({
    required this.timestamp,
    required this.isUserLooking,
    this.direction,
    this.eyePosition,
    this.gazePositionX,
    this.gazePositionY,
  });
  
  // Konvertierung von Map zu Objekt (für Datenbank)
  factory EyeTrackingData.fromMap(Map<String, dynamic> map) {
    return EyeTrackingData(
      timestamp: map['timestamp'] is DateTime 
          ? map['timestamp'] 
          : DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isUserLooking: map['isUserLooking'] ?? false,
      direction: map['direction'],
      eyePosition: map['eyePosition'] != null
          ? Map<String, double>.from(map['eyePosition'])
          : null,
      gazePositionX: map['gazePositionX'],
      gazePositionY: map['gazePositionY'],
    );
  }
  
  // Konvertierung von Objekt zu Map (für Datenbank und API)
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isUserLooking': isUserLooking,
      'direction': direction,
      'eyePosition': eyePosition,
      'gazePositionX': gazePositionX,
      'gazePositionY': gazePositionY,
    };
  }
  
  // Implementierung des Operators [] für Map-ähnlichen Zugriff
  dynamic operator [](String key) {
    switch(key) {
      case 'timestamp':
        return timestamp.millisecondsSinceEpoch;
      case 'isUserLooking':
        return isUserLooking;
      case 'direction':
        return direction;
      case 'eyePosition':
        return eyePosition;
      case 'gazePositionX':
        return gazePositionX;
      case 'gazePositionY':
        return gazePositionY;
      default:
        return null;
    }
  }
  
  // Hilfsmethode für die Prüfung, ob ein Schlüssel existiert
  bool containsKey(String key) {
    return [
      'timestamp',
      'isUserLooking',
      'direction',
      'eyePosition',
      'gazePositionX',
      'gazePositionY'
    ].contains(key);
  }
  
  // Erstellt eine Kopie des Objekts mit möglicherweise aktualisierten Feldern
  EyeTrackingData copyWith({
    DateTime? timestamp,
    bool? isUserLooking,
    String? direction,
    Map<String, double>? eyePosition,
    double? gazePositionX,
    double? gazePositionY,
  }) {
    return EyeTrackingData(
      timestamp: timestamp ?? this.timestamp,
      isUserLooking: isUserLooking ?? this.isUserLooking,
      direction: direction ?? this.direction,
      eyePosition: eyePosition ?? this.eyePosition,
      gazePositionX: gazePositionX ?? this.gazePositionX,
      gazePositionY: gazePositionY ?? this.gazePositionY,
    );
  }
  
  @override
  String toString() {
    return 'EyeTrackingData(timestamp: $timestamp, direction: $direction, gazePosition: ($gazePositionX, $gazePositionY))';
  }
}