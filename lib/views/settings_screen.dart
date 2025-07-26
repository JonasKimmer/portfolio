import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_usage_service.dart';
import '../services/touch_service.dart';
import '../services/eye_tracking_service.dart';
import '../services/sensor_service.dart';
import '../services/touch_sync_service.dart';
import '../services/eye_tracking_sync_service.dart';
import '../services/device_sync_service.dart';
import '../services/sensor_sync_service.dart';
import '../data/db_helper.dart';
import 'package:http/http.dart' as http;

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, bool> _isSyncing = {
    'appUsage': false,
    'touch': false,
    'eyeTracking': false,
    'sensor': false,
    'device': false,
  };

  final Map<String, String> _syncStatus = {
    'appUsage': 'Bereit',
    'touch': 'Bereit',
    'eyeTracking': 'Bereit',
    'sensor': 'Bereit',
    'device': 'Bereit',
  };

  // Zähler für unsynchronisierte Daten
  Map<String, int> _unsyncedCounts = {
    'appUsage': 0,
    'touch': 0,
    'eyeTracking': 0,
    'sensor': 0,
    'device': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadUnsyncedCounts();
  }

  Future<void> _loadUnsyncedCounts() async {
    final dbHelper = DBHelper();
    try {
      _unsyncedCounts['device'] = await dbHelper.getUnsyncedDataCount('device_info');
      _unsyncedCounts['touch'] = await dbHelper.getUnsyncedDataCount('touch_data');
      _unsyncedCounts['eyeTracking'] = await dbHelper.getUnsyncedDataCount('eye_tracking_data');
      _unsyncedCounts['sensor'] = await dbHelper.getUnsyncedDataCount('sensor_data');
      _unsyncedCounts['appUsage'] = await dbHelper.getUnsyncedDataCount('app_usage');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Fehler beim Laden der unsynced Counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUnsyncedCounts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildManualSyncCard(context),
            const SizedBox(height: 16),
            _buildServerConnectionCard(),
            const SizedBox(height: 16),
            _buildAboutCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildManualSyncCard(BuildContext context) {
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
                  Icons.sync,
                  color: Colors.deepPurple.shade800,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Manuelle Synchronisation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
              ],
            ),
            const Divider(),
            // Geräteinformationen
            _buildSyncListTile(
              title: 'Geräteinformationen synchronisieren',
              subtitle: 'Status: ${_syncStatus['device']} (${_unsyncedCounts['device']} unsynced)',
              isLoading: _isSyncing['device'] ?? false,
              onTap: () => _syncDeviceInfo(context),
              icon: Icons.smartphone,
            ),
            const Divider(),
            // App-Nutzungsdaten
            _buildSyncListTile(
              title: 'App-Nutzungsdaten synchronisieren',
              subtitle: 'Status: ${_syncStatus['appUsage']} (${_unsyncedCounts['appUsage']} unsynced)',
              isLoading: _isSyncing['appUsage'] ?? false,
              onTap: () => _syncAppUsageData(context),
              icon: Icons.apps,
            ),
            const Divider(),
            // Touch-Daten
            _buildSyncListTile(
              title: 'Touch-Daten synchronisieren',
              subtitle: 'Status: ${_syncStatus['touch']} (${_unsyncedCounts['touch']} unsynced)',
              isLoading: _isSyncing['touch'] ?? false,
              onTap: () => _syncTouchData(context),
              icon: Icons.touch_app,
            ),
            const Divider(),
            // Eye-Tracking-Daten
            _buildSyncListTile(
              title: 'Eye-Tracking-Daten synchronisieren',
              subtitle: 'Status: ${_syncStatus['eyeTracking']} (${_unsyncedCounts['eyeTracking']} unsynced)',
              isLoading: _isSyncing['eyeTracking'] ?? false,
              onTap: () => _syncEyeTrackingData(context),
              icon: Icons.visibility,
            ),
            const Divider(),
            // Sensordaten
            _buildSyncListTile(
              title: 'Sensordaten synchronisieren',
              subtitle: 'Status: ${_syncStatus['sensor']} (${_unsyncedCounts['sensor']} unsynced)',
              isLoading: _isSyncing['sensor'] ?? false,
              onTap: () => _syncSensorData(context),
              icon: Icons.sensors,
            ),
            const Divider(),
            // Alle Daten
            _buildSyncListTile(
              title: 'Alle Daten synchronisieren',
              subtitle: 'Löst nacheinander alle obigen Synchronisationen aus',
              isLoading: _isSyncing.values.any((syncing) => syncing),
              onTap: () => _syncAllData(context),
              icon: Icons.sync,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerConnectionCard() {
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
                  Icons.network_check,
                  color: Colors.deepPurple.shade800,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Server-Verbindung',
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
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final connected = await _pingServer();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(connected ? 'Server ist erreichbar' : 'Server ist nicht erreichbar'),
                      backgroundColor: connected ? Colors.green : Colors.red,
                    ),
                  );
                },
                icon: Icon(Icons.network_check),
                label: Text('Server-Verbindung prüfen'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  foregroundColor: Colors.deepPurple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
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
                  Icons.info_outline,
                  color: Colors.deepPurple.shade800,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Über die App',
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
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Version',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '1.0.0',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Diese App sammelt Daten zur Smartphone-Nutzung, Sensorwerten und Eye-Tracking, '
              'um adaptive Benutzeroberflächen zu entwickeln.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncListTile({
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      leading: Icon(
        icon,
        color: Colors.deepPurple.shade300,
      ),
      trailing: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
            )
          : Icon(
              Icons.sync,
              color: Colors.deepPurple,
            ),
      onTap: isLoading ? null : onTap,
    );
  }

  Future<bool> _pingServer() async {
    try {
      print('Versuche Server-Ping an: https://portfolio-bjatv9ae2-jonas-kimmerinfos-projects.vercel.app/api/ping');
      try {
        final pingResponse = await http.get(
          Uri.parse('https://portfolio-bjatv9ae2-jonas-kimmerinfos-projects.vercel.app/api/ping')
        ).timeout(Duration(seconds: 5));
        print('Server Ping-Antwort: ${pingResponse.statusCode} ${pingResponse.body}');
        if (pingResponse.statusCode == 200) {
          return true;
        }
      } catch (pingError) {
        print('Ping-Endpunkt nicht verfügbar: $pingError');
        // Kein Abbruch, wir versuchen es mit alternativen Endpunkten
      }
      
      // Als Fallback versuchen wir den Device-Endpunkt
      try {
        final deviceResponse = await http.get(
          Uri.parse('https://portfolio-bjatv9ae2-jonas-kimmerinfos-projects.vercel.app/api/device')
        ).timeout(Duration(seconds: 5));
        print('Server Device-Endpunkt-Antwort: ${deviceResponse.statusCode}');
        return deviceResponse.statusCode == 200 || deviceResponse.statusCode == 404; // 404 ist auch OK, bedeutet der Endpunkt existiert
      } catch (deviceError) {
        print('Device-Endpunkt nicht verfügbar: $deviceError');
      }
      
      try {
        final rootResponse = await http.get(
          Uri.parse('https://portfolio-bjatv9ae2-jonas-kimmerinfos-projects.vercel.app/')
        ).timeout(Duration(seconds: 5));
        print('Root-Endpunkt-Antwort: ${rootResponse.statusCode}');
        return true; // Wenn wir hier ankommen, ist zumindest der Server erreichbar
      } catch (rootError) {
        print('Root-Endpunkt nicht verfügbar: $rootError');
      }
      
      return false;
    } catch (e) {
      print('Genereller Fehler bei Server-Verbindungsprüfung: $e');
      return false;
    }
  }

  // Vereinfachte Version für die Fehlersuche
  Future<void> _syncDeviceInfo(BuildContext context) async {
    if (_isSyncing['device'] == true) return;
    setState(() {
      _isSyncing['device'] = true;
      _syncStatus['device'] = 'Synchronisiere...';
    });
    
    try {
      // Wichtig: DeviceSyncService vom Provider holen
      final deviceSyncService = Provider.of<DeviceSyncService>(context, listen: false);
      print("SettingsScreen: DeviceSyncService erfolgreich vom Provider geholt");
      
      // DBHelper für Debug-Informationen
      final dbHelper = DBHelper();
      
      // Anzahl unsynchronisierter Einträge vor der Synchronisation
      final beforeCount = await dbHelper.getUnsyncedDataCount('device_info');
      print("SettingsScreen: Vor der Synchronisation: $beforeCount unsynchronisierte DeviceInfos");
      
      // Direkte Synchronisation ohne Netzwerkprüfung für Fehlersuche
      print("SettingsScreen: Starte direkte Synchronisation...");
      final success = await deviceSyncService.syncDeviceInfo();
      print("SettingsScreen: Synchronisation abgeschlossen, Ergebnis: $success");
      
      // Anzahl unsynchronisierter Einträge nach der Synchronisation
      final afterCount = await dbHelper.getUnsyncedDataCount('device_info');
      print("SettingsScreen: Nach der Synchronisation: $afterCount unsynchronisierte DeviceInfos");
      
      // Aktualisiere Zähler und UI
      await _loadUnsyncedCounts();
      setState(() {
        _syncStatus['device'] = success ? 'Erfolgreich' : 'Fehlgeschlagen';
        _isSyncing['device'] = false;
      });
      
      // Benachrichtigung an den Benutzer
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Geräteinformationen synchronisiert ($beforeCount → $afterCount)'
            : 'Synchronisation fehlgeschlagen'),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: Duration(seconds: 3),
      ));
    } catch (e) {
      print("SettingsScreen: Kritischer Fehler bei Device-Synchronisation: $e");
      setState(() {
        _syncStatus['device'] = 'Fehler: $e';
        _isSyncing['device'] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Fehler: $e'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ));
    }
  }

  Future<void> _syncAppUsageData(BuildContext context) async {
    if (_isSyncing['appUsage'] == true) return;
    setState(() {
      _isSyncing['appUsage'] = true;
      _syncStatus['appUsage'] = 'Synchronisiere...';
    });
    
    try {
      // Server-Ping testen
      final pingSuccess = await _pingServer();
      if (!pingSuccess) {
        setState(() {
          _syncStatus['appUsage'] = 'Server nicht erreichbar';
          _isSyncing['appUsage'] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server nicht erreichbar')),
        );
        return;
      }
      
      final appUsageService = Provider.of<AppUsageService>(context, listen: false);
      final dbHelper = DBHelper();
      
      // Debug: Zeige Datenbank-Inhalte vor der Synchronisation
      await dbHelper.debugPrintAppUsageData();
      final success = await appUsageService.syncAppUsageData();
      
      // Debug: Zeige Datenbank-Inhalte nach der Synchronisation
      await dbHelper.debugPrintAppUsageData();
      
      // Aktualisiere die Anzahl der unsynced Elemente
      await _loadUnsyncedCounts();
      setState(() {
        _syncStatus['appUsage'] = success ? 'Erfolgreich' : 'Fehlgeschlagen';
        _isSyncing['appUsage'] = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'App-Nutzungsdaten erfolgreich synchronisiert'
              : 'Synchronisation fehlgeschlagen'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _syncStatus['appUsage'] = 'Fehler: $e';
        _isSyncing['appUsage'] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Synchronisation: $e')),
      );
    }
  }

  Future<void> _syncTouchData(BuildContext context) async {
    if (_isSyncing['touch'] == true) return;
    setState(() {
      _isSyncing['touch'] = true;
      _syncStatus['touch'] = 'Synchronisiere...';
    });
    
    try {
      final touchSyncService = Provider.of<TouchSyncService>(context, listen: false);
      final success = await touchSyncService.syncTouchData();
      
      // Aktualisiere die Anzahl der unsynced Elemente
      await _loadUnsyncedCounts();
      setState(() {
        _syncStatus['touch'] = success ? 'Erfolgreich' : 'Fehlgeschlagen';
        _isSyncing['touch'] = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Touch-Daten erfolgreich synchronisiert'
              : 'Synchronisation fehlgeschlagen'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _syncStatus['touch'] = 'Fehler: $e';
        _isSyncing['touch'] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Synchronisation: $e')),
      );
    }
  }

  Future<void> _syncEyeTrackingData(BuildContext context) async {
    if (_isSyncing['eyeTracking'] == true) return;
    setState(() {
      _isSyncing['eyeTracking'] = true;
      _syncStatus['eyeTracking'] = 'Synchronisiere...';
    });
    
    try {
      final eyeTrackingSyncService = Provider.of<EyeTrackingSyncService>(context, listen: false);
      final success = await eyeTrackingSyncService.syncEyeTrackingData();
      
      // Aktualisiere die Anzahl der unsynced Elemente
      await _loadUnsyncedCounts();
      setState(() {
        _syncStatus['eyeTracking'] = success ? 'Erfolgreich' : 'Fehlgeschlagen';
        _isSyncing['eyeTracking'] = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Eye-Tracking-Daten erfolgreich synchronisiert'
              : 'Synchronisation fehlgeschlagen'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _syncStatus['eyeTracking'] = 'Fehler: $e';
        _isSyncing['eyeTracking'] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Synchronisation: $e')),
      );
    }
  }

  Future<void> _syncSensorData(BuildContext context) async {
    if (_isSyncing['sensor'] == true) return;
    setState(() {
      _isSyncing['sensor'] = true;
      _syncStatus['sensor'] = 'Synchronisiere...';
    });
    
    try {
      final sensorSyncService = Provider.of<SensorSyncService>(context, listen: false);
      final success = await sensorSyncService.syncSensorData();
      
      // Aktualisiere die Anzahl der unsynced Elemente
      await _loadUnsyncedCounts();
      setState(() {
        _syncStatus['sensor'] = success ? 'Erfolgreich' : 'Fehlgeschlagen';
        _isSyncing['sensor'] = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Sensor-Daten erfolgreich synchronisiert'
              : 'Synchronisation fehlgeschlagen'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _syncStatus['sensor'] = 'Fehler: $e';
        _isSyncing['sensor'] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Synchronisation: $e')),
      );
    }
  }

  Future<void> _syncAllData(BuildContext context) async {
    // Server-Ping testen
    final pingSuccess = await _pingServer();
    if (!pingSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server nicht erreichbar')),
      );
      return;
    }
    
    // Synchronisationen nacheinander ausführen
    await _syncDeviceInfo(context);
    await _syncAppUsageData(context);
    await _syncTouchData(context);
    await _syncEyeTrackingData(context);
    await _syncSensorData(context);
    
    // Aktualisiere die Anzahl der unsynced Elemente
    await _loadUnsyncedCounts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alle Synchronisationen abgeschlossen'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}