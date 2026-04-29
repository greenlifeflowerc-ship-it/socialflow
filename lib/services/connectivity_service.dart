import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';

class ConnectivityService {
  static Future<bool> hasInternet() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) return false;
    
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  static Future<void> openWifiSettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(
        action: 'android.settings.WIFI_SETTINGS',
      );
      await intent.launch();
    }
  }
}
