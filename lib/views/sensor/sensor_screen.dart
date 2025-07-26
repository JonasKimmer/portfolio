import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sensor_service.dart';

class SensorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SensorService>(
      builder: (context, sensorService, child) {
        final data = sensorService.sensorData;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sensoren'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCard(
                  title: 'Beschleunigung (m/s²)',
                  icon: Icons.speed,
                  rows: [
                    _buildRow('x', data.accelX),
                    _buildRow('y', data.accelY),
                    _buildRow('z', data.accelZ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                _buildCard(
                  title: 'Gyroskop (rad/s)',
                  icon: Icons.rotate_90_degrees_ccw,
                  rows: [
                    _buildRow('x', data.gyroX),
                    _buildRow('y', data.gyroY),
                    _buildRow('z', data.gyroZ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                _buildCard(
                  title: 'Magnetometer (µT)',
                  icon: Icons.compass_calibration,
                  rows: [
                    _buildRow('x', data.magX),
                    _buildRow('y', data.magY),
                    _buildRow('z', data.magZ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                _buildCard(
                  title: 'Lichtsensor (Lux)',
                  icon: Icons.light_mode,
                  rows: [
                    _buildRow('Intensität', data.lightLevel),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                _buildCard(
                  title: 'Nähe-Sensor',
                  icon: Icons.sensors,
                  rows: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Status:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: data.isNear ? Colors.green.shade100 : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: data.isNear ? Colors.green : Colors.red,
                              ),
                            ),
                            child: Text(
                              data.isNear ? 'Objekt erkannt' : 'Kein Objekt',
                              style: TextStyle(
                                color: data.isNear ? Colors.green.shade800 : Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> rows,
  }) {
    return Card(
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
                  icon,
                  color: Colors.deepPurple.shade800,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}