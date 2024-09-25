import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lifecare/bluetooth_devices_list_widget.dart';
import 'package:lifecare/javascript_flutter_message.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    initController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(
          controller: controller,
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
        print('MSG ' + message.method.toString());
        if (message.method == 'startScan') {
          startScan();
        } else if (message.method.contains('connect')) {
          connect(message.method);
        }
      },
    );
    await controller.loadRequest(Uri.parse('https://flutter.careapp.ru/'));
  }

  Future<void> startScan() async {
    if (!mounted) {
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();

    // final scanResults = FlutterBluePlus.lastScanResults;
    // FlutterBluePlus.adapterStateNow;
    // final map = scanResults.map((e) {
    //   return {
    //     'name': e.device.platformName,
    //     'advName': e.device.advName,
    //     'services': e.device.servicesList.map((s) => s.remoteId.str).toList(),
    //     'id': e.device.remoteId.str,
    //   };
    // }).toList();
    // final jsonString = jsonEncode(map);

    await showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder(
            initialData: FlutterBluePlus.lastScanResults,
            stream: FlutterBluePlus.onScanResults,
            builder: (context, snapshot) {
              final devices = snapshot.requireData
                  .where(
                    (result) => result.device.platformName.isNotEmpty,
                    // (result) => result.device.platformName.contains('LTab-'),
                  )
                  .map((result) => result.device)
                  .toList();
              final arguments = {
                "devices": devices
                    .map(
                      (e) => {
                        "uuid": e.remoteId.str,
                        "name": e.platformName,
                      },
                    )
                    .toList(),
              };
              final answer = {
                "method": "onDevicesScanned",
                "arguments": arguments,
              };
              final jsCode =
                  'window.onMessageFromFlutter(\'${jsonEncode(answer)}\')';
              controller.runJavaScript(jsCode);
              print('TEST ${jsCode}');

              if (devices.isEmpty) {
                return AlertDialog(
                  content: Text('No devices'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('OK'),
                    ),
                  ],
                );
              }
              return BluetoothDevicesWidget(devices: devices);
            });
      },
    );
    FlutterBluePlus.stopScan();
  }

  Future<void> connect(String message) async {
    try {
      final deviceId = message.split('+').last;
      final scanResults = FlutterBluePlus.lastScanResults;
      final device = scanResults
          .firstWhere(
            (element) => element.device.remoteId.str == deviceId,
          )
          .device;
      await device.connect();
      controller.runJavaScript('alert(\''
          'onConnected'
          '\');');
    } catch (error) {
      controller.runJavaScript('alert(\''
          'onError($error)'
          '\');');
    }
  }

  Future<void> write(String message) async {
    try {
      final deviceId = message.split('+').last;
      final scanResults = FlutterBluePlus.lastScanResults;
      final device = scanResults
          .firstWhere(
            (element) => element.device.remoteId.str == deviceId,
          )
          .device;
      await device.connect();
      controller.runJavaScript('alert(\''
          'onConnected'
          '\');');
    } catch (error) {
      controller.runJavaScript('alert(\''
          'onError($error)'
          '\');');
    }
  }
}
