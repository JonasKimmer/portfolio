import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/touch_service.dart';
import '../../services/touch_sync_service.dart';
import 'heatmap_painter.dart';

class TouchScreen extends StatefulWidget {
  const TouchScreen({Key? key}) : super(key: key);

  @override
  _TouchScreenState createState() => _TouchScreenState();
}

class _TouchScreenState extends State<TouchScreen> {
  String _text = 'Tippe oder wische auf den Bildschirm';
  Offset _lastPosition = Offset.zero;
  Offset? _swipeStartPosition;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _lastPosition = Offset(size.width / 2, size.height / 2);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final touchService = Provider.of<TouchService>(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Touchscreen-Aktivität'),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: Colors.grey[200],
                      child: CustomPaint(
                        painter: HeatmapPainter(
                          touchService.getAllTouchPoints(), 
                          Size(constraints.maxWidth, constraints.maxHeight),
                        ),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    ),
                    
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (TapDownDetails details) {
                        _handleTap(details.localPosition);
                      },
                      onPanStart: (DragStartDetails details) {
                        _handleSwipeStart(details.localPosition);
                      },
                      onPanUpdate: (DragUpdateDetails details) {
                        setState(() {
                          _lastPosition = details.localPosition;
                        });
                      },
                      onPanEnd: (DragEndDetails details) {
                        _handleSwipeEnd(details);
                      },
                      onLongPressStart: (LongPressStartDetails details) {
                        _handleLongPressStart(details.localPosition);
                      },
                      onLongPressEnd: (LongPressEndDetails details) {
                        _handleLongPressEnd();
                      },
                    ),
                    
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _text,
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    
                    if (_lastPosition != Offset.zero)
                      Positioned(
                        left: _lastPosition.dx - 8,
                        top: _lastPosition.dy - 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          Container(
            color: Colors.white,
            height: MediaQuery.of(context).size.height * 0.4, 
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer<TouchService>(
                    builder: (context, service, child) {
                      final swipeDetails = service.getSwipeDetails();
                      final longPressDetails = service.getLongPressDetails();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
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
                                        Icons.touch_app,
                                        color: Colors.deepPurple.shade800,
                                        size: 24,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Gesamt: ${service.getTotalCount()} Events',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Taps:',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${service.getCountByType("tap")}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Swipes:',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${service.getCountByType("swipe")}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Lange Drucks:',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${service.getCountByType("longpress")}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  if (_lastPosition != Offset.zero)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Letzte Position:',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '(${_lastPosition.dx.toStringAsFixed(1)}, ${_lastPosition.dy.toStringAsFixed(1)})',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          
                          if (swipeDetails.isNotEmpty) 
                            ExpansionTile(
                              title: Text('Swipe-Details'),
                              children: [
                                for (var detail in swipeDetails)
                                  ListTile(
                                    dense: true,
                                    title: Text('Richtung: ${detail['direction']}'),
                                    subtitle: Text(
                                      'Start: (${detail['start']['x'].toStringAsFixed(1)}, ${detail['start']['y'].toStringAsFixed(1)})\n'
                                      'Ende: (${detail['end']['x'].toStringAsFixed(1)}, ${detail['end']['y'].toStringAsFixed(1)})'
                                    ),
                                  ),
                              ],
                            ),
                          
                          // Details zu langen Drucks anzeigen, wenn vorhanden
                          if (longPressDetails.isNotEmpty)
                            ExpansionTile(
                              title: Text('Lange Drucks-Details'),
                              children: [
                                for (var detail in longPressDetails)
                                  ListTile(
                                    dense: true,
                                    title: Text('Position: (${detail['position']['x'].toStringAsFixed(1)}, ${detail['position']['y'].toStringAsFixed(1)})'),
                                    subtitle: Text('Dauer: ${detail['duration']} ms'),
                                  ),
                              ],
                            ),
                          
                          SizedBox(height: 12),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                Provider.of<TouchService>(context, listen: false).clearData();
                                setState(() {
                                  _text = 'Tippe oder wische auf den Bildschirm';
                                  _lastPosition = Offset.zero;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[100],
                                foregroundColor: Colors.black87,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text('Daten zurücksetzen'),
                            ),
                          ),
                          
                          SizedBox(height: 16), 
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Handler-Methoden
  void _handleTap(Offset localPosition) {
    setState(() {
      _lastPosition = localPosition;
      _text = 'Getippt';
      
      final touchService = Provider.of<TouchService>(context, listen: false);
      touchService.addTouchPoint(
        localPosition.dx,
        localPosition.dy,
        'tap'
      );
    });
  }
  
  void _handleSwipeStart(Offset localPosition) {
    _swipeStartPosition = localPosition;
    
    final touchService = Provider.of<TouchService>(context, listen: false);
    touchService.startSwipe(localPosition.dx, localPosition.dy);
  }
  
  void _handleSwipeEnd(DragEndDetails details) {
    if (_swipeStartPosition != null && _lastPosition != Offset.zero) {
      final dx = _lastPosition.dx - _swipeStartPosition!.dx;
      final dy = _lastPosition.dy - _swipeStartPosition!.dy;
      String direction;
      
      if (dx.abs() > dy.abs()) {
        direction = dx > 0 ? 'right' : 'left';
      } else {
        direction = dy > 0 ? 'down' : 'up';
      }
      
      setState(() {
        _text = 'Swipe nach ${direction == 'right' ? 'rechts' : direction == 'left' ? 'links' : direction == 'up' ? 'oben' : 'unten'}';
        
        final touchService = Provider.of<TouchService>(context, listen: false);
        touchService.endSwipe(_lastPosition.dx, _lastPosition.dy, direction);
      });
    }
  }
  
  void _handleLongPressStart(Offset localPosition) {
    setState(() {
      _lastPosition = localPosition;
      _text = 'Langer Druck';
      
      final touchService = Provider.of<TouchService>(context, listen: false);
      touchService.startLongPress(localPosition.dx, localPosition.dy);
    });
  }
  
  void _handleLongPressEnd() {
    if (_lastPosition != Offset.zero) {
      final touchService = Provider.of<TouchService>(context, listen: false);
      touchService.endLongPress(_lastPosition.dx, _lastPosition.dy);
      setState(() {});
    }
  }
}