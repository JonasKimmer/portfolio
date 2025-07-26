import 'package:flutter/material.dart';
import '../../services/device_info_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  Map<String, String>? _deviceData;
  bool _isLoading = true;
  bool _isOneHandMode = false;
  bool _isRightHanded = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    setState(() {
      _isLoading = true;
    });
    
    final info = await DeviceInfoService.getDeviceInfo(context);
    final formatted = DeviceInfoService.getFormattedDeviceData(info);
    
    setState(() {
      _deviceData = formatted;
      _isOneHandMode = info.isOneHandMode;
      _isRightHanded = info.isRightHanded;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeviceInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deviceData == null
              ? const Center(child: Text('Keine Gerätedaten verfügbar'))
              : RefreshIndicator(
                  onRefresh: _loadDeviceInfo,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCard(
                        title: 'Gerätespezifische Daten', 
                        icon: Icons.smartphone,
                        keys: [
                          'Modell',
                          'Hersteller',
                          'OS-Version',
                        ]
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildCard(
                        title: 'Bildschirm', 
                        icon: Icons.display_settings,
                        keys: [
                          'Bildschirmhelligkeit',
                          'Ausrichtung',
                        ]
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildSettingsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCard({
    required String title, 
    required IconData icon,
    required List<String> keys
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
            ...keys.map((key) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _deviceData![key] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
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
                  Icons.settings,
                  color: Colors.deepPurple.shade800,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Benutzereinstellungen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
              ],
            ),
            const Divider(),
            
            // Einhandmodus mit Toggle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Einhandmodus',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Switch(
                    value: _isOneHandMode,
                    onChanged: (value) async {
                      await DeviceInfoService.setOneHandMode(value);
                      await _loadDeviceInfo();
                    },
                    activeColor: Colors.deepPurple,
                  ),
                ],
              ),
            ),
            
            // Bevorzugte Hand mit Optionen
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bevorzugte Hand',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHandOption(
                          label: 'Linkshänder',
                          isSelected: !_isRightHanded,
                          onTap: () async {
                            await DeviceInfoService.setRightHanded(false);
                            await _loadDeviceInfo();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildHandOption(
                          label: 'Rechtshänder',
                          isSelected: _isRightHanded,
                          onTap: () async {
                            await DeviceInfoService.setRightHanded(true);
                            await _loadDeviceInfo();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHandOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Colors.deepPurple : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.deepPurple : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}