import 'package:shared_preferences/shared_preferences.dart';

/// Класс, который записывает и сохраняет device id подключенного устройства
class BluetoothDeviceStorage {
  Future<String?> deviceId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id');
  }

  Future<void> saveDeviceId(String id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('device_id', id);
  }
}
