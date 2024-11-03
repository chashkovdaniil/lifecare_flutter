import 'dart:convert';

class JavascriptFlutterMessage {
  final String method;
  final Object? arguments;

  const JavascriptFlutterMessage(this.method, this.arguments);

  factory JavascriptFlutterMessage.fromJson(Map<String, Object?> map) {
    return JavascriptFlutterMessage(map['method'] as String, map['arguments']);
  }
}

class FlutterJavascriptMessage {
  final String method;
  final Map<String, Object?>? arguments;

  const FlutterJavascriptMessage(this.method, this.arguments);

  @override
  String toString() {
    final result = {
      "method": method,
      "arguments": arguments,
    };
    return 'window.onMessageFromFlutter(\'${jsonEncode(result)}\')';
  }
}
