import 'dart:async';
import 'dart:typed_data';

class WebSocketWrapper {
  StreamSubscription<dynamic /*String|List<int>*/> listen(void onData(dynamic /*String|List<int>*/ event)?,
      {Function? onError, void onReset()?, bool? cancelOnError}) {
    throw UnsupportedError('websockets');
  }

  void send(String data) {
    throw UnsupportedError('websockets');
  }
  
  void close() {}

  String get name => 'a socket';
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
void saveBinaryBlob(String name, List<int> data) {}