import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart';

class WebSocketWrapper {
  WebSocket socket;

  StreamSubscription<dynamic> listen(void onData(dynamic event),
      {Function? onError, void onReset()?, bool? cancelOnError}) {
    return socket.onMessage.map((MessageEvent message) => message.data).listen(
      onData,
      onError: onError,
      onDone: () {
        if (!_closed) {
          socket = WebSocket(name);
          if (onReset != null) {
            onReset();
          }
        }
      },
      cancelOnError: cancelOnError,
    );
  }

  void send(String data) {
    socket.send(data.toJS);
  }

  bool _closed = false;
  void close() {
    _closed = true;
    socket.close();
  }

  String get name => socket.url;

  WebSocketWrapper(this.socket);
}

Future<WebSocketWrapper> connect(String serverUrl) async {
  WebSocket webSocket = WebSocket(serverUrl);
  await webSocket.onOpen.first;
  return WebSocketWrapper(webSocket);
}

Future<String?> getCookie(String name) async {
  return window.localStorage[name];
}

void setCookie(String name, String? value) {
  if (value == null) {
    window.localStorage.removeItem(name);
  } else {
    window.localStorage[name] = value;
  }
}

Future<Uint8List?> getBinaryBlob(String name) async {
  String? cookie = await getCookie(name);
  return cookie == null ? null : base64Decode(cookie);
}

void saveBinaryBlob(String name, List<int> data) async {
  setCookie(name, base64Encode(data));
}
