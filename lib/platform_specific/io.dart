import 'dart:async';
import 'dart:io';
import 'dart:math';
export 'stub.dart'
    if (dart.library.ui) 'pathprov.dart';

Duration pingInterval = Duration(seconds: 10);

class WebSocketWrapper {
  WebSocket socket;
  bool reloading = false;
  Completer<void> _doneReloading = Completer();
  Random _random = Random();

  StreamSubscription<dynamic> listen(
    void onData(dynamic event), {
    void Function(Object error, StackTrace)? onError,
    void onReset()?,
  }) {
    if (onReset != null) {
      onReset();
    }
    return socket.listen(
      onData,
      onError: onError,
      onDone: () {
        if (!_closed) {
          if (onError != null) {
            onError(
                Exception(
                    'Connection terminated without error, reconnecting...'),
                StackTrace.current);
          }
          reconnect(onData, onError, onReset);
        }
      },
    );
  }

  Future<void> reconnect(
      void onData(dynamic event),
      void Function(Object error, StackTrace)? onError,
      void Function()? onReset,
      [Duration waitingTime = const Duration(milliseconds: 100)]) async {
    _doneReloading = Completer();
    reloading = true;
    do {
      // TODO: make sure this works
      try {
        socket = await WebSocket.connect(name);
        socket.pingInterval = pingInterval;
        reloading = false;
        _doneReloading.complete();
        listen(onData, onError: onError, onReset: onReset);
      } catch (e, st) {
        try {
          if (onError == null) {
            rethrow;
          }
          onError(e, st);
        } finally {
          if (waitingTime < Duration(minutes: 1)) {
            waitingTime *= 2;
          }
          Duration duration =
              waitingTime + waitingTime * (_random.nextDouble() - .5);
          await Future.delayed(
            duration,
          );
          continue;
        }
      }
      break;
    } while (true);
  }

  void send(String data) async {
    await _doneReloading.future;
    socket.add(data);
  }

  bool _closed = false;
  void close() {
    _closed = true;
    socket.close();
  }

  final String name;

  WebSocketWrapper(this.socket, this.name) {
    socket.pingInterval = pingInterval;
    _doneReloading.complete();
  }
}

Future<WebSocketWrapper> connect(String serverUrl) async {
  return WebSocketWrapper(await WebSocket.connect(serverUrl), serverUrl);
}