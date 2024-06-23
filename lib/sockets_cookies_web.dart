import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart';

class WebSocketWrapper {
  WebSocket socket;

  StreamSubscription<dynamic> listen(void onData(dynamic event),
      {Function? onError,
      void onReset()?,
      bool? cancelOnError}) {
    return socket.onMessage.map((MessageEvent message) => message.data).listen(
      onData,
      onError: onError,
      onDone: () {
        socket = WebSocket(name);
        if (onReset != null) {
          onReset();
        }
      },
      cancelOnError: cancelOnError,
    );
  }

  void send(String data) {
    socket.send(data.toJS);
  }

  void close() {
    socket.close();
  }

  String get name => socket.url;

  WebSocketWrapper(this.socket);
}

Future<WebSocketWrapper> connect(String serverUrl) async {
  return WebSocketWrapper(WebSocket(serverUrl));
}

String? getCookie(String name) {
  return window.localStorage[name];
}

void setCookie(String name, String? value) {
  if (value == null) {
    window.localStorage.removeItem(name);
  } else {
    window.localStorage[name] = value;
  }
}

Uint8List? getBinaryBlob(String name) {
  var cookie = getCookie(name);
  return cookie == null ? null : base64Decode(cookie);
}

void saveBinaryBlob(String name, List<int> data) {
  setCookie(name, base64Encode(data));
}
