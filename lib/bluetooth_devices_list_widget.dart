import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lifecare/bluetooth_manager.dart';

/// Виджет, который выводит список блютуз устройств.
/// Требуется для дебага, открывается по тапу на кнпоку "S" в режиме дебага
class BluetoothDevicesWidget extends StatelessWidget {
  final BluetoothManager bluetoothManager;
  final List<BluetoothDevice> devices;

  const BluetoothDevicesWidget({
    super.key,
    required this.devices,
    required this.bluetoothManager,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ListDevice(
              devices: devices,
              bluetoothManager: bluetoothManager,
            ),
          ),
          TextButton(
            child: Text('Закрыть'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _ListDevice extends StatefulWidget {
  final BluetoothManager bluetoothManager;
  final List<BluetoothDevice> devices;

  const _ListDevice(
      {super.key, required this.devices, required this.bluetoothManager});

  @override
  State<_ListDevice> createState() => _ListDeviceState();
}

class _ListDeviceState extends State<_ListDevice> {
  var _isFreezed = false;
  String? _selectedDevice;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.devices.length,
      itemBuilder: (context, index) {
        final device = widget.devices[index];

        return ListTile(
          title: Text(device.platformName),
          subtitle: Text(
            '${device.remoteId.str}${device.isConnected ? '\nConnected' : ''}',
          ),
          isThreeLine: device.isConnected,
          trailing: _selectedDevice == device.remoteId.str
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                  ],
                )
              : null,
          enabled: !_isFreezed,
          onTap: () async {
            try {
              _isFreezed = true;
              _selectedDevice = device.remoteId.str;
              setState(() {});

              await widget.bluetoothManager.connect(device.remoteId.str);
              _isFreezed = false;
              _selectedDevice = null;
              setState(() {});

              if (!mounted) {
                return;
              }
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Успешно подключено'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Ок'),
                    ),
                  ],
                ),
              );
            } catch (error) {
              _selectedDevice = null;
              _isFreezed = false;
              setState(() {});
              if (!mounted) {
                return;
              }
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Error'),
                    content: Text(error.toString()),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('OK'),
                      ),
                    ],
                  );
                },
              );
            }
          },
        );
      },
    );
  }
}
