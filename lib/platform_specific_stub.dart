import 'dart:async';
import 'dart:typed_data';

abstract class WebSocketWrapper {
  StreamSubscription<dynamic /*String|List<int>*/> listen(void onData(dynamic /*String|List<int>*/ event)?,
      {void Function(Object error, StackTrace)? onError, void onReset()?});

  void send(String data);
  
  void close();

  bool get reloading;

  String get name;
}

Future<WebSocketWrapper> connect(String serverUrl) async {
  throw UnsupportedError('websockets');
}


Future<String?> getCookie(String name) async {
  return null;
}

Future<Uint8List?> getBinaryBlob(String name) async {
  return null;
}


void setCookie(String name, String? value) {}
Future<void> saveBinaryBlob(String name, ByteBuffer data) async {}