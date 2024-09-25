import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothDevicesWidget extends StatefulWidget {
  final List<BluetoothDevice> devices;

  const BluetoothDevicesWidget({super.key, required this.devices});

  @override
  State<BluetoothDevicesWidget> createState() => _BluetoothDevicesWidgetState();
}

class _BluetoothDevicesWidgetState extends State<BluetoothDevicesWidget> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ListDevice(
              devices: widget.devices,
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
  final List<BluetoothDevice> devices;

  const _ListDevice({super.key, required this.devices});

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
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
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

              await device.connect();
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
