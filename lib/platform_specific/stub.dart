import 'dart:async';
import 'dart:typed_data';

abstract class WebSocketWrapper {
  /// Listens to the websocket, and calls [onData] when a message is sent to it, and [onError] when an error is sent to it.
  /// [onReset] is called immediately, as well as after reconnecting.
  StreamSubscription<dynamic /*String|List<int>*/ > listen(
      void onData(dynamic /*String|List<int>*/ event)?,
      {void Function(Object error, StackTrace)? onError,
      void onReset()?});

  /// Sends a message to the websocket
  void send(String data);

  /// Closes the websocket, and does not reconnect.
  void close();

  /// This is [false] if it is currently connected to the websocket, and [true] otherwise.
  bool get reloading;

  /// The URL of the websocket.
  String get name;
}

/// Connects to the websocket and returns when it is connected.
Future<WebSocketWrapper> connect(String serverUrl) async {
  throw UnsupportedError('websockets');
}

/// A cache of cookies that have been saved for use synchronously. This is updated by [getCookie] and [setCookie], and possibly other things too.
Map<String, String> cookieCache = {};

/// Gets the cookie associated with [name] from the cookie store and add it to [cookieCache]. This does not mean an actual cookie, but something somehow stored on the local machine.
Future<String?> getCookie(String name) async {
  return cookieCache[name];
}

/// Gets the binary cookie associated with [name] as a Uint8List. This does not mean an actual cookie, but something somehow stored on the local machine. This is a seperate namespace from [getCookie].
Future<Uint8List?> getBinaryBlob(String name) async {
  return null;
}

/// Sets the cookie associated with [name] to [value] and add it to [cookieCache]. This does not mean an actual cookie, but something somehow stored on the local machine.
void setCookie(String name, String? value) {
  if (value == null) {
    cookieCache.remove(name);
  } else {
    cookieCache[name] = value;
  }
}

/// Sets the binary cookie associated with [name] to [data]. This does not mean an actual cookie, but something somehow stored on the local machine. This is a seperate namespace from [setCookie].
Future<void> saveBinaryBlob(String name, ByteBuffer data) async {}
