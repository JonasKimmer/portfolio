import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../../services/eye_tracking_service.dart';
import 'camera_view.dart';
import 'face_detector_painter.dart';
import 'heatmap_painter.dart';

class EyeTrackingScreen extends StatefulWidget {
  @override
  _EyeTrackingScreenState createState() => _EyeTrackingScreenState();
}

class _EyeTrackingScreenState extends State<EyeTrackingScreen> with WidgetsBindingObserver {
  FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: true,
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _direction;
  bool _showHeatmap = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _canProcess = false;
    _faceDetector.close();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final eyeTrackingService = Provider.of<EyeTrackingService>(context, listen: false);
    if (state == AppLifecycleState.inactive) {
      eyeTrackingService.stopTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EyeTrackingService>(
      builder: (context, eyeTrackingService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Eye Tracker'),
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [                
                // Status-Zeile
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Status: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            eyeTrackingService.isTracking ? "Aktiv" : "Inaktiv",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: eyeTrackingService.isTracking ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      
                      Row(
                        children: [
                          Text(
                            'Blinzeln: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${eyeTrackingService.blinkCount}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: eyeTrackingService.isTracking
                                ? null
                                : () => eyeTrackingService.startTracking(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text('Start'),
                          ),
                          
                          SizedBox(width: 10),
                          
                          ElevatedButton(
                            onPressed: eyeTrackingService.isTracking
                                ? () => eyeTrackingService.stopTracking()
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text('Stop'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Heatmap Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text('Heatmap anzeigen:'),
                      Switch(
                        value: _showHeatmap,
                        onChanged: (value) {
                          setState(() {
                            _showHeatmap = value;
                          });
                        },
                        activeColor: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
                
                // Kamera oder Heatmap
                Container(
                  height: 240, 
                  margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _showHeatmap
                        ? _buildHeatmapView(eyeTrackingService)
                        : _buildCameraView(eyeTrackingService),
                  ),
                ),
                _buildResultCard(eyeTrackingService),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildResultCard(EyeTrackingService eyeTrackingService) {
    final latestData = eyeTrackingService.eyeTrackingData.isNotEmpty
        ? eyeTrackingService.eyeTrackingData.last
        : null;
        
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart,
                    color: Colors.deepPurple.shade800,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Eye-Tracking Ergebnisse:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade800,
                    ),
                  ),
                ],
              ),
              const Divider(),
              
              if (latestData == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Keine Daten verfügbar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    if (latestData['timestamp'] != null)
                      _buildResultRow(
                        'Zeitstempel:',
                        _formatTimestamp(latestData['timestamp']),
                      ),
                    _buildResultRow(
                      'Blickrichtung:',
                      '${latestData['direction'] ?? "unbekannt"}',
                    ),
                    if (latestData['eyePosition'] != null) ...[
                      if (latestData['eyePosition']['leftEyeOpen'] != null)
                        _buildResultRow(
                          'Linkes Auge offen:',
                          '${(latestData['eyePosition']['leftEyeOpen'] * 100).toStringAsFixed(1)}%',
                        ),
                      if (latestData['eyePosition']['rightEyeOpen'] != null)
                        _buildResultRow(
                          'Rechtes Auge offen:',
                          '${(latestData['eyePosition']['rightEyeOpen'] * 100).toStringAsFixed(1)}%',
                        ),
                      if (latestData['eyePosition']['x'] != null && latestData['eyePosition']['y'] != null)
                        _buildResultRow(
                          'Augenposition:',
                          'X=${latestData['eyePosition']['x'].toStringAsFixed(2)}, Y=${latestData['eyePosition']['y'].toStringAsFixed(2)}',
                        ),
                    ],
                    if (latestData.containsKey('gazePositionX') && 
                        latestData.containsKey('gazePositionY') &&
                        latestData['gazePositionX'] != null &&
                        latestData['gazePositionY'] != null)
                      _buildResultRow(
                        'Blickposition:',
                        'X=${(latestData['gazePositionX'] * 100).toStringAsFixed(1)}%, Y=${(latestData['gazePositionY'] * 100).toStringAsFixed(1)}%',
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}.${date.millisecond.toString().padLeft(3, '0')}';
  }
  
  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCameraView(EyeTrackingService eyeTrackingService) {
    return eyeTrackingService.isTracking
        ? CameraView(
            customPaint: _customPaint,
            onImage: (inputImage) {
              _processImage(inputImage, eyeTrackingService);
            },
            initialCameraLensDirection: CameraLensDirection.front,
          )
        : Center(
            child: Text(
              'Kamerabereich für Eye-Tracking',
              style: TextStyle(color: Colors.grey[700]),
            ),
          );
  }
  
  Widget _buildHeatmapView(EyeTrackingService eyeTrackingService) {
    // Maximalen Wert im Heatmap-Grid finden
    final heatmapData = eyeTrackingService.getHeatmapData();
    int maxValue = 1; // Mindestens 1, um Division durch 0 zu vermeiden
    
    for (var row in heatmapData) {
      for (var cell in row) {
        if (cell > maxValue) maxValue = cell;
      }
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blick-Heatmap',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                painter: HeatmapPainter(
                  heatmap: heatmapData,
                  maxValue: maxValue,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 5),
                  Text('Wenig'),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    color: Colors.green,
                  ),
                  SizedBox(width: 5),
                  Text('Mittel'),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    color: Colors.yellow,
                  ),
                  SizedBox(width: 5),
                  Text('Hoch'),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    color: Colors.red,
                  ),
                  SizedBox(width: 5),
                  Text('Sehr hoch'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _processImage(InputImage inputImage, EyeTrackingService eyeTrackingService) async {
    if (!_canProcess || !eyeTrackingService.isTracking || _isBusy) return;
    
    _isBusy = true;
    
    try {
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isNotEmpty) {
        final face = faces.first;
        
        // Blickrichtung bestimmen
        _direction = _getEyeDirection(face);
        
        // Blickposition auf dem Bildschirm aktualisieren
        eyeTrackingService.updateGazePosition(face, Size(640, 480)); // Standard-Größe

        // Daten hinzufügen mit benannten Parametern
        eyeTrackingService.addEyeTrackingData(
          isLooking: true,
          direction: _direction,
          position: {
            'leftEyeOpen': face.leftEyeOpenProbability ?? 0,
            'rightEyeOpen': face.rightEyeOpenProbability ?? 0,
            'x': eyeTrackingService.gazePositionX,
            'y': eyeTrackingService.gazePositionY,
          },
        );
        
        // CustomPaint für die Gesichtserkennung-Visualisierung aktualisieren
        final Size imageSize = Size(640, 480); 
        final InputImageRotation imageRotation = InputImageRotation.rotation0deg; 

        _customPaint = CustomPaint(
          painter: FaceDetectorPainter(
            faces,
            imageSize,
            imageRotation,
            CameraLensDirection.front,
          ),
        );
      } else {
        _customPaint = null;
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Fehler bei der Gesichtserkennung: $e');
    } finally {
      _isBusy = false;
    }
  }
  
  String? _getEyeDirection(Face face) {
    // Kopfwinkel für horizontale Blickrichtung (links/rechts)
    if (face.headEulerAngleY != null) {
      if (face.headEulerAngleY! < -10) {
        return 'links';  
      } else if (face.headEulerAngleY! > 10) {
        return 'rechts';  
      }
    }
    
    // Kopfwinkel für vertikale Blickrichtung (oben/unten)
    if (face.headEulerAngleX != null) {
      if (face.headEulerAngleX! < -10) {
        return 'unten';  
      } else if (face.headEulerAngleX! > 10) {
        return 'oben';   
      }
    }
        return 'mitte';
  }
}