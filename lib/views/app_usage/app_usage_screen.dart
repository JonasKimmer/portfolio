import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_usage_service.dart';
import 'dart:io' show Platform;

class AppUsageScreen extends StatefulWidget {
  @override
  _AppUsageScreenState createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends State<AppUsageScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<AppUsageService>(context, listen: false).checkUsagePermission();
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final usageService = Provider.of<AppUsageService>(context);
    final int directAppOpenCount = usageService.appOpenCount;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('App-Nutzung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => usageService.fetchUsageData(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!usageService.hasUsageAccess && Platform.isAndroid)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => usageService.requestUsagePermission(),
                child: const Text('Nutzungszugriff anfordern'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          if (Platform.isIOS)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Hinweis: Auf iOS können nur Daten der eigenen App angezeigt werden.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.orange[700], 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: usageService.usageData.isEmpty
              ? const Center(child: Text('Keine Nutzungsdaten verfügbar'))
              : RefreshIndicator(
                  onRefresh: () async {
                    await usageService.fetchUsageData();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: usageService.usageData.length,
                    itemBuilder: (context, index) {
                      final info = usageService.usageData[index];
                      
                      final bool isCurrentApp = info['packageName'] == usageService.usageData.first['packageName'];
                      final int displayOpenCount = isCurrentApp ? directAppOpenCount : (info['openCount'] ?? 1);
                      
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.apps,
                                    color: Colors.deepPurple.shade800,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    info['appName'],
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
                                    const Text(
                                      'Paketname:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${info['packageName']}',
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
                                    const Text(
                                      'Nutzungsdauer:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(info['usage']),
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
                                    const Text(
                                      'Öffnungen heute:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '$displayOpenCount', 
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
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
}