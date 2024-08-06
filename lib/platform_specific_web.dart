import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart';

class WebSocketWrapper {
  WebSocket socket;
  bool reloading = false;
  Completer<void> _doneReloading = Completer();

  StreamSubscription<dynamic> listen(void onData(dynamic event),
      {void Function(Object error, StackTrace)? onError, void onReset()?}) {
    if (onReset != null) {
      onReset();
    }
    return socket.onMessage.map((MessageEvent message) => message.data).listen(
          (message) {
            if (message is String)
              onData(message);
            else if (message is Blob) {
              JSPromise<JSArrayBuffer> promise = message.arrayBuffer();
              promise.toDart.then((JSArrayBuffer arrayBuffer) {
                onData(arrayBuffer.toDart);
              });
            }
          },
          onError: onError,
          onDone: () async {
            if (!_closed) {
              _doneReloading = Completer();
              reloading = true;
              socket = WebSocket(name);
              socket.onError.listen((Event event) {
                if (onError == null) {
                  throw event;
                }
                onError(event, StackTrace.current);
              });
              await socket.onOpen.first;
              reloading = false;
              _doneReloading.complete();
              listen(onData, onError: onError, onReset: onReset);
            }
          },
        );
  }

  void send(String data) async {
    await _doneReloading.future;
    socket.send(data.toJS);
  }

  bool _closed = false;
  void close() {
    _closed = true;
    socket.close();
  }

  String get name => socket.url;

  WebSocketWrapper(this.socket) {
    _doneReloading.complete();
  }
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
  Cache cache = await window.caches.open('$name').toDart;
  Response? data = await cache.match('data'.toJS).toDart;
  if (data == null) return null;
  JSArrayBuffer arrayBuffer = await data.arrayBuffer().toDart;
  return arrayBuffer.toDart.asUint8List();
}

Future<void> saveBinaryBlob(String name, ByteBuffer data) async {
  Cache cache = await window.caches.open('$name').toDart;
  await cache.put('data'.toJS, Response(data.toJS)).toDart;
}
