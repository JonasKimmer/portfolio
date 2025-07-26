class TouchPoint {
  final int timestamp;
  final double x;
  final double y;
  final String type; // 'tap', 'swipe', 'longpress'
  final String? direction; // für swipes
  
  final double? endX;
  final double? endY;
  
  final int? durationMs;
  
  TouchPoint({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.type,
    this.direction,
    this.endX,
    this.endY,
    this.durationMs,
  });
}