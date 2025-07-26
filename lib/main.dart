import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_usage_service.dart';
import 'services/sensor_service.dart';
import 'services/touch_service.dart';
import 'services/eye_tracking_service.dart';
import 'services/touch_sync_service.dart';
import 'services/eye_tracking_sync_service.dart';
import 'services/sensor_sync_service.dart';
import 'services/device_sync_service.dart'; 
import 'core/app_config.dart';
import 'views/home_screen.dart';
import 'views/dashboard/dashboard_screen.dart';
import 'views/sensor/sensor_screen.dart';
import 'views/app_usage/app_usage_screen.dart';
import 'views/touch/touch_screen.dart';
import 'views/eye_tracking/eye_tracking_screen.dart';
import 'data/db_helper.dart';

void main() async {
  // Sicherstellen, dass Flutter-Bindings initialisiert sind (wichtig für Datenbankzugriff)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Datenbankhelper initialisieren
  final dbHelper = DBHelper();
  await dbHelper.database; // Datenbankverbindung herstellen
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfig()),
        ChangeNotifierProvider(create: (_) => SensorService()),
        ChangeNotifierProvider(create: (_) => AppUsageService()),
        ChangeNotifierProvider(create: (_) => TouchService()),
        ChangeNotifierProvider(create: (_) => EyeTrackingService()),
        // Sync-Services
        ChangeNotifierProvider(create: (_) => TouchSyncService()),
        ChangeNotifierProvider(create: (_) => EyeTrackingSyncService()),
        ChangeNotifierProvider(create: (_) => SensorSyncService()),
        ChangeNotifierProvider(create: (_) => DeviceSyncService()), // Neu hinzugefügt
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive UI Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      builder: (context, child) {
        return AppLifecycleManager(child: child!);
      },
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/dashboard': (context) => DashboardView(),
        '/sensors': (context) => SensorScreen(),
        '/appUsage': (context) => AppUsageScreen(),
        '/touch': (context) => TouchScreen(),
        '/eyeTracking': (context) => EyeTrackingScreen(),
      },
    );
  }
}

// AppLifecycleManager für App-Nutzungsverfolgung
class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  
  AppLifecycleManager({required this.child});
  
  @override
  _AppLifecycleManagerState createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      final appUsageService = Provider.of<AppUsageService>(context, listen: false);
      
      // Sync-Services abrufen - achten Sie auf Fehler bei einzelnen Services
      TouchSyncService? touchSyncService;
      EyeTrackingSyncService? eyeTrackingSyncService;
      SensorSyncService? sensorSyncService;
      DeviceSyncService? deviceSyncService;
      
      try {
        touchSyncService = Provider.of<TouchSyncService>(context, listen: false);
      } catch (e) {
        print("Fehler beim Abrufen des TouchSyncService: $e");
      }
      
      try {
        eyeTrackingSyncService = Provider.of<EyeTrackingSyncService>(context, listen: false);
      } catch (e) {
        print("Fehler beim Abrufen des EyeTrackingSyncService: $e");
      }
      
      try {
        sensorSyncService = Provider.of<SensorSyncService>(context, listen: false);
      } catch (e) {
        print("Fehler beim Abrufen des SensorSyncService: $e");
      }
      
      try {
        deviceSyncService = Provider.of<DeviceSyncService>(context, listen: false);
      } catch (e) {
        print("Fehler beim Abrufen des DeviceSyncService: $e");
      }
      
      switch (state) {
        case AppLifecycleState.paused:
          appUsageService.onAppPaused();
          
          // Daten synchronisieren mit Fehlerbehandlung
          if (touchSyncService != null) {
            try {
              touchSyncService.syncTouchData();
            } catch (e) {
              print("Fehler bei TouchSyncService: $e");
            }
          }
          
          if (eyeTrackingSyncService != null) {
            try {
              eyeTrackingSyncService.syncEyeTrackingData();
            } catch (e) {
              print("Fehler bei EyeTrackingSyncService: $e");
            }
          }
          
          if (sensorSyncService != null) {
            try {
              sensorSyncService.syncSensorData();
            } catch (e) {
              print("Fehler bei SensorSyncService: $e");
            }
          }
          
          if (deviceSyncService != null) {
            try {
              deviceSyncService.syncDeviceInfo();
            } catch (e) {
              print("Fehler bei DeviceSyncService: $e");
            }
          }
          break;
        case AppLifecycleState.resumed:
          appUsageService.onAppResumed();
          break;
        default:
          break;
      }
    } catch (e) {
      print("Genereller Fehler im AppLifecycleManager: $e");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}