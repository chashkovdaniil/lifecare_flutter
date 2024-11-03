import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothService {
  final Function(List<BluetoothDevice> devices) onScannedDevices;

  StreamSubscription? _scanSubscription;

  BluetoothService({
    required this.onScannedDevices,
  });

  Future<void> startScan() async {
    _scanSubscription = FlutterBluePlus.scanResults.listen((scanResults) {
      final devices = FlutterBluePlus.lastScanResults
          .where((result) => result.device.platformName.contains('LTab-'))
          .map((result) => result.device)
          .toList();
      onScannedDevices(devices);
    });
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
  }
}
