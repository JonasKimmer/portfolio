import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'coordinates_translator.dart';

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(
    this.faces,
    this.imageSize,
    this.rotation,
    this.cameraLensDirection,
  );
  
  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.red.withOpacity(0.0); // 100% transparent
    final Paint paint2 = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.0
      ..color = Colors.green.withOpacity(0.0); // 100% transparent
    
    for (final Face face in faces) {
      final left = translateX(
        face.boundingBox.left,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final top = translateY(
        face.boundingBox.top,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final right = translateX(
        face.boundingBox.right,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final bottom = translateY(
        face.boundingBox.bottom,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      
      // Gesichtsrechteck zeichnen
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        paint1,
      );
      
      // Augenpartie lokalisieren und Raster um die Augen zeichnen
      final landmarks = face.landmarks;
      final leftEye = landmarks[FaceLandmarkType.leftEye]?.position;
      final rightEye = landmarks[FaceLandmarkType.rightEye]?.position;
      
      if (leftEye != null && rightEye != null) {
        final leftEyeX = translateX(
          leftEye.x.toDouble(),
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );
        final leftEyeY = translateY(
          leftEye.y.toDouble(),
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );
        final rightEyeX = translateX(
          rightEye.x.toDouble(),
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );
        final rightEyeY = translateY(
          rightEye.y.toDouble(),
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );
        
        // Bereich für das Raster berechnen (Augenbereich mit Puffer)
        final centerX = (leftEyeX + rightEyeX) / 2;
        final centerY = (leftEyeY + rightEyeY) / 2;
        final eyeDistance = (rightEyeX - leftEyeX).abs();
        
        // Raster um die Augen herum definieren
        final gridLeft = centerX - eyeDistance * 1.5;
        final gridRight = centerX + eyeDistance * 1.5;
        final gridTop = centerY - eyeDistance;
        final gridBottom = centerY + eyeDistance * 1.5;
        
        // Raster zeichnen
        final Paint gridPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.red.withOpacity(0.0); // 100% transparent
        
        // Vertikale Linien (3 Spalten im Raster)
        final gridWidth = gridRight - gridLeft;
        canvas.drawLine(
          Offset(gridLeft + gridWidth / 3, gridTop),
          Offset(gridLeft + gridWidth / 3, gridBottom),
          gridPaint,
        );
        canvas.drawLine(
          Offset(gridLeft + gridWidth * 2 / 3, gridTop),
          Offset(gridLeft + gridWidth * 2 / 3, gridBottom),
          gridPaint,
        );
        
        // Horizontale Linien (3 Zeilen im Raster)
        final gridHeight = gridBottom - gridTop;
        canvas.drawLine(
          Offset(gridLeft, gridTop + gridHeight / 3),
          Offset(gridRight, gridTop + gridHeight / 3),
          gridPaint,
        );
        canvas.drawLine(
          Offset(gridLeft, gridTop + gridHeight * 2 / 3),
          Offset(gridRight, gridTop + gridHeight * 2 / 3),
          gridPaint,
        );
        
        // Umrahmen des gesamten Rasters
        canvas.drawRect(
          Rect.fromLTRB(gridLeft, gridTop, gridRight, gridBottom),
          gridPaint,
        );
      }
      
      // Rest des Codes für Gesichtskonturen und Landmarks...
      void paintContour(FaceContourType type) {
        final contour = face.contours[type];
        if (contour?.points != null) {
          for (final Point point in contour!.points) {
            canvas.drawCircle(
              Offset(
                translateX(
                  point.x.toDouble(),
                  size,
                  imageSize,
                  rotation,
                  cameraLensDirection,
                ),
                translateY(
                  point.y.toDouble(),
                  size,
                  imageSize,
                  rotation,
                  cameraLensDirection,
                ),
              ),
              1,
              paint1);
          }
        }
      }
      
      void paintLandmark(FaceLandmarkType type) {
        final landmark = face.landmarks[type];
        if (landmark?.position != null) {
          canvas.drawCircle(
            Offset(
              translateX(
                landmark!.position.x.toDouble(),
                size,
                imageSize,
                rotation,
                cameraLensDirection,
              ),
              translateY(
                landmark.position.y.toDouble(),
                size,
                imageSize,
                rotation,
                cameraLensDirection,
              ),
            ),
            2,
            paint2);
        }
      }
      
      for (final type in FaceContourType.values) {
        paintContour(type);
      }
      
      for (final type in FaceLandmarkType.values) {
        paintLandmark(type);
      }
    }
  }
  
  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.faces != faces;
  }
}