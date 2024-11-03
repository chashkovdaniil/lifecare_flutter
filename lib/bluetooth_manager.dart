import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lifecare/exceptions.dart';

class BluetoothManager {
  final Function(List<BluetoothDevice> devices) onScannedDevices;
  final Function(BluetoothDevice device) onConnected;
  final Function(
    BluetoothCharacteristic characteristic,
    List<int> value,
  ) onCharacteristicRead;
  final Function(BluetoothException exception) onError;
  BluetoothDevice? _connectedDevice;
  String? _connectedDeviceId;

  StreamSubscription? _scanSubscription;
  final _characteristicsSubscription =
      <String, StreamSubscription<List<int>>>{};

  BluetoothManager({
    required this.onScannedDevices,
    required this.onConnected,
    required this.onCharacteristicRead,
    required this.onError,
  });

  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<void> dispose() async {
    for (final sub in _characteristicsSubscription.values) {
      await sub.cancel();
    }
    await stopScan();
  }

  Future<void> startScan() async {
    print('BluetoothManager — startScan');
    await _scanSubscription?.cancel();
    await FlutterBluePlus.startScan().timeout(const Duration(seconds: 5));
    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (scanResults) {
        final devices = FlutterBluePlus.lastScanResults
            .where((result) => result.device.platformName.contains('LTab-'))
            .map((result) => result.device)
            .toList();
        print('BluetoothManager — onScannedDevices: $scanResults, $devices');
        onScannedDevices(devices);
      },
      onError: (error) {
        print('BluetoothManager — error: $error');
      },
      onDone: () {
        print('BluetoothManager — scanned');
      },
      cancelOnError: true,
    );
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
  }

  Future<void> connect(String id) async {
    print('BluetoothManager — connect to $id');

    final device = FlutterBluePlus.lastScanResults
        .where((result) => result.device.remoteId.str == id)
        .map((result) => result.device)
        .toList()
        .firstOrNull;
    if (device == null) {
      return;
    }
    await device.connect();
    _connectedDevice = device;
    _connectedDeviceId = device.remoteId.str;
    onConnected(device);
  }

  Future<void> disconnect([String? id]) async {
    print(
      'BluetoothManager — disconnect to ${id ?? _connectedDevice?.remoteId.str}',
    );
    await _connectedDevice?.disconnect();

    final device = FlutterBluePlus.lastScanResults
        .where((result) => result.device.remoteId.str == id)
        .map((result) => result.device)
        .toList()
        .firstOrNull;
    await device?.disconnect();
  }

  Future<void> writeCharacteristic({
    required String serviceId,
    required String characteristicId,
    required String message,
  }) async {
    try {
      if (_connectedDevice == null) {
        final connectedDeviceId = _connectedDeviceId;

        if (connectedDeviceId == null) {
          onError(const BluetoothNotFoundDeviceIdException());
          return;
        }

        await connect(connectedDeviceId);
      }
      final services = await _connectedDevice?.discoverServices();
      final service =
          services?.where((s) => s.remoteId.str == serviceId).firstOrNull;

      if (service == null) {
        print('BluetoothManager — not found service with ID = $serviceId');
        return;
      }
      print('BluetoothManager — found service with ID = $serviceId');

      final characteristic = service.characteristics
          .where((c) => c.remoteId.str == characteristicId)
          .firstOrNull;

      if (characteristic == null) {
        onError(const BluetoothNotFoundCharacteristicException());
        return;
      }

      await characteristic.write(message as List<int>);
    } catch (error, stackTrace) {
      onError(BluetoothUnexpectedException(error, stackTrace));
    }
  }

  Future<void> readCharacteristic({
    required String serviceId,
    required String characteristicId,
  }) async {
    try {
      if (_connectedDevice == null) {
        final connectedDeviceId = _connectedDeviceId;

        if (connectedDeviceId == null) {
          onError(const BluetoothNotFoundDeviceIdException());
          return;
        }

        await connect(connectedDeviceId);
      }
      final services = await _connectedDevice?.discoverServices();
      final service =
          services?.where((s) => s.remoteId.str == serviceId).firstOrNull;

      if (service == null) {
        print('BluetoothManager — not found service with ID = $serviceId');
        return;
      }
      print('BluetoothManager — found service with ID = $serviceId');

      final characteristic = service.characteristics
          .where((c) => c.remoteId.str == characteristicId)
          .firstOrNull;

      if (characteristic == null) {
        onError(const BluetoothNotFoundCharacteristicException());
        return;
      }
      final value = await characteristic.read();
      onCharacteristicRead(characteristic, value);
    } catch (error, stackTrace) {
      onError(BluetoothUnexpectedException(error, stackTrace));
    }
  }

  Future<void> subscribeToCharacteristic({
    required String serviceId,
    required String characteristicId,
  }) async {
    try {
      if (_connectedDevice == null) {
        final connectedDeviceId = _connectedDeviceId;

        if (connectedDeviceId == null) {
          onError(const BluetoothNotFoundDeviceIdException());
          return;
        }

        await connect(connectedDeviceId);
      }
      final services = await _connectedDevice?.discoverServices();
      final service =
          services?.where((s) => s.remoteId.str == serviceId).firstOrNull;

      if (service == null) {
        print('BluetoothManager — not found service with ID = $serviceId');
        return;
      }
      print('BluetoothManager — found service with ID = $serviceId');

      final characteristic = service.characteristics
          .where((c) => c.remoteId.str == characteristicId)
          .firstOrNull;

      if (characteristic == null) {
        onError(const BluetoothNotFoundCharacteristicException());
        return;
      }
      _characteristicsSubscription[characteristic.remoteId.str] =
          characteristic.onValueReceived.listen(
        (value) {
          onCharacteristicRead(characteristic, value);
        },
      );
    } catch (error, stackTrace) {
      onError(BluetoothUnexpectedException(error, stackTrace));
    }
  }
}

class BluetoothManagerInheritedWidget extends InheritedWidget {
  final BluetoothManager bluetoothManager;

  const BluetoothManagerInheritedWidget({
    required Widget child,
    required this.bluetoothManager,
    super.key,
  }) : super(child: child);

  static BluetoothManagerInheritedWidget of(
    BuildContext context, {
    bool listen = true,
  }) {
    if (listen) {
      final BluetoothManagerInheritedWidget? result =
          context.dependOnInheritedWidgetOfExactType<
              BluetoothManagerInheritedWidget>();
      assert(
        result != null,
        'No BluetoothManagerInheritedWidget found in context',
      );
      return result!;
    }

    final BluetoothManagerInheritedWidget? result = context
        .getInheritedWidgetOfExactType<BluetoothManagerInheritedWidget>();
    assert(
      result != null,
      'No BluetoothManagerInheritedWidget found in context',
    );
    return result!;
  }

  @override
  bool updateShouldNotify(BluetoothManagerInheritedWidget old) =>
      bluetoothManager != old.bluetoothManager;
}
