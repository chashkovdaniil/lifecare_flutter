import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lifecare/bluetooth_devices_list_widget.dart';
import 'package:lifecare/javascript_flutter_message.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'bluetooth_device_storage.dart';
import 'bluetooth_manager.dart';

/// https://clck.ru/3EP6pm - link to code on GitHub
void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final WebViewController controller;
  late final BluetoothManager bluetoothManager;

  @override
  void initState() {
    super.initState();
    initController();
    bluetoothManager = BluetoothManager(
      bluetoothDeviceStorage: BluetoothDeviceStorage(),
      onScannedDevices: (devices) {
        final msg = FlutterJavascriptMessage(
          'onDevicesScanned',
          {
            "devices": devices
                .map(
                  (e) => {
                    "id": e.remoteId.str,
                    "name": e.platformName,
                  },
                )
                .toList(),
          },
        );

        controller.runJavaScript(msg.toString());
      },
      onConnected: (device) {
        final msg = FlutterJavascriptMessage(
          'onConnected',
          {
            "id": device.remoteId.str,
          },
        );

        controller.runJavaScript(msg.toString());
      },
      onCharacteristicRead: (characteristic, value) {
        final msg = FlutterJavascriptMessage(
          'characteristicValueChanged',
          {
            "id": characteristic.remoteId.str,
            "value": value,
          },
        );

        controller.runJavaScript(msg.toString());
      },
      onError: (error) {
        final msg = FlutterJavascriptMessage(
          'onConnectionError',
          {
            "message": error.toString(),
          },
        );

        controller.runJavaScript(msg.toString());
        if (!mounted) {
          return;
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ошибка'),
            content: Text('$error'),
          ),
        );
      },
    );
    bluetoothManager.init();
  }

  @override
  void dispose() {
    bluetoothManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(
          controller: controller,
        ),
      ),
      floatingActionButton: (!kDebugMode)
          ? null

          /// Это мы используем чисто для дебага
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  child: Text('S'),
                  onPressed: () async {
                    bluetoothManager.startScan();
                    await showDialog(
                      context: context,
                      builder: (context) {
                        return StreamBuilder(
                          initialData: FlutterBluePlus.lastScanResults,
                          stream: FlutterBluePlus.onScanResults,
                          builder: (context, snapshot) {
                            return BluetoothDevicesWidget(
                              bluetoothManager: bluetoothManager,
                              devices: snapshot.requireData
                                  .where(
                                    (s) =>
                                        s.device.platformName.contains('LTab'),
                                  )
                                  .map((s) => s.device)
                                  .toList(),
                            );
                          },
                        );
                      },
                    );
                    bluetoothManager.stopScan();
                  },
                ),
                TextButton(
                  child: Text('C'),
                  onPressed: () {
                    bluetoothManager.connect('94:B9:7E:E3:93:0A');
                  },
                ),
                TextButton(
                  child: Text('D'),
                  onPressed: () {
                    bluetoothManager.disconnect('94:B9:7E:E3:93:0A');
                  },
                ),
                TextButton(
                  child: Text('W'),
                  onPressed: () async {
                    bluetoothManager.writeCharacteristic(
                      characteristicId: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
                      serviceId: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
                      message: 'select:0',
                    );
                    await Future.delayed(const Duration(seconds: 1));
                    bluetoothManager.writeCharacteristic(
                      characteristicId: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
                      serviceId: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
                      message: 'select:2',
                    );
                    await Future.delayed(const Duration(seconds: 1));
                    bluetoothManager.writeCharacteristic(
                      characteristicId: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
                      serviceId: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
                      message: 'select:1',
                    );
                    await Future.delayed(const Duration(seconds: 1));
                    bluetoothManager.writeCharacteristic(
                      characteristicId: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
                      serviceId: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
                      message: 'select:3',
                    );
                    bluetoothManager.subscribeToCharacteristic(
                      serviceId: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
                      characteristicId: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
                    );
                  },
                ),
                TextButton(
                  child: Text('R'),
                  onPressed: () {
                    bluetoothManager.readCharacteristic(
                      characteristicId: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
                      serviceId: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
                    );
                    bluetoothManager.readCharacteristic(
                      characteristicId: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
                      serviceId: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
                    );
                  },
                ),
              ],
            ),
    );
  }

  /// Намеренно оставляю все в виджете, чтобы потом сами решили куда и что выносить
  Future<void> initController() async {
    controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(const Color(0x00000000));
    await controller.addJavaScriptChannel(
      'Bluetooth',
      onMessageReceived: (javascriptMessage) {
        final message = JavascriptFlutterMessage.fromJson(
          jsonDecode(javascriptMessage.message),
        );

        switch (message.method) {
          case 'startScan':
            bluetoothManager.startScan();
            break;
          case 'connectToDevice':
            bluetoothManager.connect(
              (message.arguments as Map<String, Object?>)['id'] as String,
            );
            break;
          case 'writeCharacteristic':
            final args = (message.arguments as Map<String, Object?>);
            bluetoothManager.writeCharacteristic(
              serviceId: args['service'] as String,
              characteristicId: args['characteristicId'] as String,
              message: args['message'] as String,
            );
            break;
          case 'readCharacteristic':
            final args = (message.arguments as Map<String, Object?>);
            bluetoothManager.readCharacteristic(
              serviceId: args['service'] as String,
              characteristicId: args['characteristicId'] as String,
            );
            break;
          case 'subscribeToCharacteristic':
            final args = (message.arguments as Map<String, Object?>);
            bluetoothManager.subscribeToCharacteristic(
              serviceId: args['service'] as String,
              characteristicId: args['characteristicId'] as String,
            );
            break;
          case 'disconnect':
            bluetoothManager.disconnect();
            break;
        }
      },
    );

    await controller.loadRequest(Uri.parse('https://flutter.careapp.ru/'));
  }
}
