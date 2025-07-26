import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';
import 'sensor/sensor_screen.dart';
import 'settings_screen.dart';
import 'package:portfolio5cp/views/app_usage/app_usage_screen.dart';
import 'touch/touch_screen.dart';
import 'eye_tracking/eye_tracking_screen.dart'; 

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  // Liste der Screens, zwischen denen gewechselt werden kann.
  final List<Widget> _pages = [
    DashboardView(),
    SensorScreen(),
    AppUsageScreen(),
    TouchScreen(),
    EyeTrackingScreen(), 
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaptive UI Tracker'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: 'Sensoren',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps),
            label: 'App-Nutzung',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.touch_app),
            label: 'Touch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.visibility), 
            label: 'Eye-Tracking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}