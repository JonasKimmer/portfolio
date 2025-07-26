import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
class AppInfoService {
  Future<List<AppInfo>> getInstalledApps() async {
    List<AppInfo> apps = await InstalledApps.getInstalledApps();
    return apps;
  }
 
  Future<void> printAllAppNames() async {
    List<AppInfo> apps = await getInstalledApps();
    for (AppInfo app in apps) {
      print('App-Name: ${app.name}, Paketname: ${app.packageName}');
    }
  }
} 