import 'dart:async';
import 'dart:html';

class WebSocketWrapper {
  final WebSocket socket;

  StreamSubscription<dynamic> listen(void onData(dynamic event),
      {Function? onError, void onDone()?, bool? cancelOnError}) {
    return socket.onMessage.map((MessageEvent message) => message.data).listen(
          onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
  }

  void send(String data) {
    socket.send(data);
  }
  
  void close() {
    socket.close();
  }

  String get name => socket.url!;

  WebSocketWrapper(this.socket);
}

Future<WebSocketWrapper> connect(String serverUrl) async {
  return WebSocketWrapper(await WebSocket(serverUrl));
}

String? getCookie(String name) {
  return window.localStorage[name];
}

void setCookie(String name, String? value) {
  if (value == null) {
    window.localStorage.remove(name);
  } else {
    window.localStorage[name] = value;
  }
}
