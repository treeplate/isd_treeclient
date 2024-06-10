import 'dart:async';

class WebSocketWrapper {
  StreamSubscription<dynamic /*String|List<int>*/> listen(void onData(dynamic /*String|List<int>*/ event)?,
      {Function? onError, void onDone()?, bool? cancelOnError}) {
    throw UnsupportedError('websockets');
  }

  void send(String data) {
    throw UnsupportedError('websockets');
  }
}

Future<WebSocketWrapper> connect(String serverUrl) async {
  throw UnsupportedError('websockets');
}


String? getCookie(String name) {
  return null;
}

void setCookie(String name, String? value) {}
