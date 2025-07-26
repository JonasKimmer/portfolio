import 'package:flutter/material.dart';

class HeatmapPainter extends CustomPainter {
  final List<List<int>> heatmap;
  final int maxValue;
  
  HeatmapPainter({
    required this.heatmap,
    required this.maxValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (heatmap.isEmpty) return;
    
    final int rows = heatmap.length;
    final int cols = heatmap[0].length;
    
    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;
    
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final int value = heatmap[y][x];
        if (value <= 0) continue;
        
        // Intensität basierend auf dem Wert berechnen
        final double intensity = (value / maxValue).clamp(0.0, 1.0);
        
        // Farbe basierend auf der Intensität (blau bis rot)
        final Color color = _getHeatColor(intensity);
        
        // Zelle zeichnen
        canvas.drawRect(
          Rect.fromLTWH(
            x * cellWidth,
            y * cellHeight,
            cellWidth,
            cellHeight,
          ),
          Paint()..color = color.withOpacity(0.7),
        );
        
        // Hohe Werte mit Text darstellen
        if (value > maxValue * 0.5) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: value.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              (x * cellWidth) + (cellWidth / 2) - (textPainter.width / 2),
              (y * cellHeight) + (cellHeight / 2) - (textPainter.height / 2),
            ),
          );
        }
      }
    }
  }
  
  // Farbe basierend auf der Intensität generieren (blau->grün->gelb->rot)
  Color _getHeatColor(double intensity) {
    if (intensity < 0.25) {
      // Blau bis Grün
      return Color.lerp(Colors.blue, Colors.green, intensity * 4) ?? Colors.blue;
    } else if (intensity < 0.5) {
      // Grün bis Gelb
      return Color.lerp(Colors.green, Colors.yellow, (intensity - 0.25) * 4) ?? Colors.green;
    } else if (intensity < 0.75) {
      // Gelb bis Orange
      return Color.lerp(Colors.yellow, Colors.orange, (intensity - 0.5) * 4) ?? Colors.yellow;
    } else {
      // Orange bis Rot
      return Color.lerp(Colors.orange, Colors.red, (intensity - 0.75) * 4) ?? Colors.orange;
    }
  }
  
  @override
  bool shouldRepaint(HeatmapPainter oldDelegate) {
    return oldDelegate.heatmap != heatmap || oldDelegate.maxValue != maxValue;
  }
}