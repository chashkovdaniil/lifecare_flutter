import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lifecare/exceptions.dart';

import 'bluetooth_device_storage.dart';

/// Менеджер, который управляет подключениями к блютуз устройствам
class BluetoothManager {
  final BluetoothDeviceStorage bluetoothDeviceStorage;

  /// Вызывается когда отсканирован список блютуз устройства
  final Function(List<BluetoothDevice> devices) onScannedDevices;

  /// Вызывается после подключения к девайсу
  final Function(BluetoothDevice device) onConnected;

  /// Вызывается при чтении характеристики и при получении событии во время подписки
  final Function(
    BluetoothCharacteristic characteristic,
    List<int> value,
  ) onCharacteristicRead;

  /// Вызывается при ошибках
  final Function(BluetoothException exception) onError;

  /// Подключенный девайс
  BluetoothDevice? _connectedDevice;

  /// Идентификатор подклбюченного девайса
  String? _connectedDeviceId;

  /// Подписка на сканирование девайсов
  StreamSubscription? _scanSubscription;

  /// Подписки на слушанье характеристик
  final _characteristicsSubscription =
      <String, StreamSubscription<List<int>>>{};

  BluetoothManager({
    required this.bluetoothDeviceStorage,
    required this.onScannedDevices,
    required this.onConnected,
    required this.onCharacteristicRead,
    required this.onError,
  });

  Future<void> init() async {
    /// Тут мы смотрим, есть ли сохраненный ид девайса и устанавливаем его
    /// Заодно пробуем подключиться
    final deviceId =
        _connectedDeviceId = await bluetoothDeviceStorage.deviceId();
    if (deviceId != null) {
      connect(deviceId);
    }
  }

  /// Очищает все подписки и останавливает сканирование
  Future<void> dispose() async {
    for (final sub in _characteristicsSubscription.values) {
      await sub.cancel();
    }
    await stopScan();
    _clearDevice();
  }

  /// Начинает сканирование
  Future<void> startScan() async {
    try {
      print('BluetoothManager — startScan');

      await _scanSubscription?.cancel();
      await FlutterBluePlus.startScan().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      /// Слушаем результаты сканирования
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
          onError(BluetoothUnexpectedException(error, null));
        },
        onDone: () {
          print('BluetoothManager — scanned');
        },
        cancelOnError: true,
      );
    } catch (error, stackTrace) {
      onError(BluetoothUnexpectedException(error, stackTrace));
    }
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
  }

  Future<void> connect(String id) async {
    try {
      print('BluetoothManager — connect to $id');

      /// Сначала пробуем подключиться к уже имеющимся девайсам
      var device = await _findDevice(id);
      if (device == null) {
        /// если их нет, то заново ищем в течение 10 секунд
        await startScan();
        await Future.delayed(const Duration(seconds: 10));
        await stopScan();
        device = await _findDevice(id);

        if (device == null) {
          onError(BluetoothNotFoundDeviceException(id));
          return;
        }
      }
      await device.connect();
      _connectedDevice = device;
      _connectedDeviceId = device.remoteId.str;
      await bluetoothDeviceStorage.saveDeviceId(device.remoteId.str);
      onConnected(device);
    } catch (error, stackTrace) {
      onError(BluetoothUnexpectedException(error, stackTrace));
    }
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
    _clearDevice();
  }

  /// Записывает значение [message] в характеристику [characteristicId] в [serviceId]
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
          services?.where((s) => s.uuid.str == serviceId).firstOrNull;

      if (service == null) {
        print('BluetoothManager — not found service with ID = $serviceId');
        return;
      }
      print('BluetoothManager — found service with ID = $serviceId');

      final characteristic = service.characteristics
          .where((c) => c.characteristicUuid.str == characteristicId)
          .firstOrNull;

      if (characteristic == null) {
        print(
          'BluetoothManager — available characteristics = ${service.characteristics}',
        );
        onError(
          BluetoothNotFoundCharacteristicException(characteristicId),
        );
        return;
      }

      final ints = message.codeUnits;
      await characteristic.write(ints);
    } catch (error, stackTrace) {
      onError(BluetoothUnexpectedException(error, stackTrace));
    }
  }

  /// Читает значение у характеристики [characteristicId] в [serviceId]
  /// И передает в колбэк [onCharacteristicRead]
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
          services?.where((s) => s.uuid.str == serviceId).firstOrNull;

      if (service == null) {
        print('BluetoothManager — available services = $services');
        print('BluetoothManager — not found service with ID = $serviceId');
        return;
      }
      print('BluetoothManager — found service with ID = $serviceId');

      final characteristic = service.characteristics
          .where((c) => c.characteristicUuid.str == characteristicId)
          .firstOrNull;

      if (characteristic == null) {
        print(
          'BluetoothManager — available characteristics = ${service.characteristics}',
        );
        onError(
          BluetoothNotFoundCharacteristicException(characteristicId),
        );
        return;
      }
      final value = await characteristic.read();
      onCharacteristicRead(characteristic, value);
    } catch (error, stackTrace) {
      onError(BluetoothUnexpectedException(error, stackTrace));
    }
  }

  /// Подписывается на характеристику [characteristicId] в [serviceId]
  /// И передает значение в колбэк [onCharacteristicRead]
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
          services?.where((s) => s.uuid.str == serviceId).firstOrNull;

      if (service == null) {
        print('BluetoothManager — not found service with ID = $serviceId');
        return;
      }
      print('BluetoothManager — found service with ID = $serviceId');

      final characteristic = service.characteristics
          .where((c) => c.characteristicUuid.str == characteristicId)
          .firstOrNull;

      if (characteristic == null) {
        print(
          'BluetoothManager — available characteristics = ${service.characteristics}',
        );
        onError(
          BluetoothNotFoundCharacteristicException(characteristicId),
        );
        return;
      }
      characteristic.lastValueStream.listen((onData) {
        print(onData);
      });
      _characteristicsSubscription[characteristic.characteristicUuid.str] =
          characteristic.onValueReceived.listen(
        (value) {
          onCharacteristicRead(characteristic, value);
        },
      );
    } catch (error, stackTrace) {
      onError(BluetoothUnexpectedException(error, stackTrace));
    }
  }

  Future<BluetoothDevice?> _findDevice(
    String id,
  ) async {
    return [
      ...await FlutterBluePlus.systemDevices,
      ...FlutterBluePlus.connectedDevices,
      ...FlutterBluePlus.lastScanResults
          .where((result) => result.device.remoteId.str == id)
          .map((result) => result.device)
    ].toList().firstOrNull;
  }

  /// локально очищает девайс из ОЗУ
  void _clearDevice() {
    _connectedDevice = null;
  }
}
