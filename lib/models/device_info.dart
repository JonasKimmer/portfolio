class DeviceInfo {
  final String model;
  final String manufacturer;
  final String osVersion;
  final double screenBrightness;
  final bool isPortrait;
  final bool isOneHandMode;
  final bool isRightHanded;

  DeviceInfo({
    required this.model,
    required this.manufacturer,
    required this.osVersion,
    required this.screenBrightness,
    required this.isPortrait,
    required this.isOneHandMode,
    required this.isRightHanded,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': 'this_device', 
    'model': model,
    'manufacturer': manufacturer,
    'osVersion': osVersion,
    'screenBrightness': screenBrightness,
    'screenOrientation': isPortrait ? 'portrait' : 'landscape',
    'oneHandMode': isOneHandMode,
    'dominantHand': isRightHanded ? 'right' : 'left',
    'timestamp': DateTime.now().toIso8601String()
  };
}