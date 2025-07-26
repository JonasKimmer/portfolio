import 'package:flutter/material.dart';
import '../../models/touch_point.dart';

class HeatmapPainter extends CustomPainter {
  final List<TouchPoint> touchPoints;
  final int gridSize;
  final Size screenSize;
  
  HeatmapPainter(this.touchPoints, this.screenSize, {this.gridSize = 10});

  @override
  void paint(Canvas canvas, Size size) {
    // Grid zeichnen
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;
    
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= gridSize; i++) {
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        gridPaint
      );
      
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        gridPaint
      );
    }
    
    if (touchPoints.isEmpty) return;

    // Direkte Berechnung der Heatmap
    Map<String, int> heatmap = {};
    
    for (var point in touchPoints) {
      // Sicherstellen, dass der Punkt innerhalb des sichtbaren Bereichs liegt
      if (point.x < 0 || point.y < 0 || 
          point.x > size.width || point.y > size.height) {
        continue;
      }
      
      // Berechnen der Zelle im Raster
      final int cellX = (point.x / cellWidth).floor();
      final int cellY = (point.y / cellHeight).floor();
      
      // Sicherstellen, dass die Zelle im gültigen Bereich liegt
      if (cellX >= 0 && cellX < gridSize && cellY >= 0 && cellY < gridSize) {
        final String key = '$cellX-$cellY';
        heatmap[key] = (heatmap[key] ?? 0) + 1;
      }
    }
    
    // Maximalen Wert finden für die Farbskalierung
    int maxValue = 1;
    heatmap.values.forEach((count) {
      if (count > maxValue) maxValue = count;
    });
    
    // Heatmap zeichnen
    heatmap.forEach((key, value) {
      final parts = key.split('-');
      if (parts.length == 2) {
        final x = int.tryParse(parts[0]);
        final y = int.tryParse(parts[1]);
        
        if (x != null && y != null) {
          // Farbintensität basierend auf dem Wert
          final opacity = (value / maxValue).clamp(0.1, 0.8);
          final paint = Paint()
            ..color = Colors.red.withOpacity(opacity)
            ..style = PaintingStyle.fill;
            
          canvas.drawRect(
            Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight),
            paint
          );
        }
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}