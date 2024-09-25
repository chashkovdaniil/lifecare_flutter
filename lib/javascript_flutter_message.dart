class JavascriptFlutterMessage {
  final String method;
  final Object? arguments;

  const JavascriptFlutterMessage(this.method, this.arguments);

  factory JavascriptFlutterMessage.fromJson(Map<String, Object?> map) {
    return JavascriptFlutterMessage(map['method'] as String, map['arguments']);
  }
}
