import 'dart:async';
import 'dart:typed_data';

void _dummy(String? e) {}
class WebSocketWrapper {
  StreamSubscription<dynamic /*String|List<int>*/> listen(void onData(dynamic /*String|List<int>*/ event)?,
      {Function? onError, void onDone(String? reason) = _dummy, bool? cancelOnError}) {
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


String? getCookie(String name) {
  return null;
}

Uint8List? getBinaryBlob(String name) {
  return null;
}


void setCookie(String name, String? value) {}
void saveBinaryBlob(String name, List<int> data) {}