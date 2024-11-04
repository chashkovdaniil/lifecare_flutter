sealed class BluetoothException implements Exception {
  final Object? message;
  final Object? stackTrace;

  const BluetoothException([this.message, this.stackTrace]);

  @override
  String toString() {
    return '$message -> $stackTrace';
  }
}

final class BluetoothUnexpectedException extends BluetoothException {
  const BluetoothUnexpectedException(super.message, super.stackTrace);

  @override
  String toString() {
    return '$message -> $stackTrace';
  }
}

final class BluetoothNotFoundDeviceException extends BluetoothException {
  final String id;
  const BluetoothNotFoundDeviceException(this.id);

  @override
  String toString() {
    return 'Device with id: $id not found.';
  }
}

final class BluetoothNotFoundDeviceIdException extends BluetoothException {
  const BluetoothNotFoundDeviceIdException();

  @override
  String toString() {
    return 'Device Id not found. Call startScan';
  }
}

final class BluetoothNotFoundCharacteristicException
    extends BluetoothException {
  final String id;
  const BluetoothNotFoundCharacteristicException(this.id);

  @override
  String toString() {
    return 'Characteristic - $id not found';
  }
}
