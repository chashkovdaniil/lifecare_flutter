import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lifecare/javascript_flutter_message.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
            "error": error,
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
        child: BluetoothManagerInheritedWidget(
          bluetoothManager: bluetoothManager,
          child: WebViewWidget(
            controller: controller,
          ),
        ),
      ),
    );
  }

  /// Намеренно оставляю все в виджете, чтобы потом сами решили куда и что выносить
  Future<void> initController() async {
    controller = WebViewController(onPermissionRequest: (request) {
      print('PERMISSIONS — ${request.types}');
    });
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(const Color(0x00000000));
    await controller.addJavaScriptChannel(
      'Bluetooth',
      onMessageReceived: (javascriptMessage) {
        final message = JavascriptFlutterMessage.fromJson(
          jsonDecode(javascriptMessage.message),
        );

        print('JS MSG - ${javascriptMessage.message}');
        print('MSG ' + message.method.toString());

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
