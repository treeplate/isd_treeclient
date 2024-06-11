import 'dart:async';
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.html) 'sockets_cookies_html.dart';

class NetworkConnection {
  NetworkConnection(
      this.socket, void Function(List<String>) unrequestedMessageHandler) {
    subscription = socket.listen((rawMessage) {
      List<String> message = (rawMessage as String).split('\x00');
      if (message[0] == 'reply') {
        items.add(message.sublist(1, message.length-1));
        moreItems.complete();
        moreItems = Completer();
      } else {
        unrequestedMessageHandler(message.sublist(0, message.length-1));
      }
    }, onDone: () {
      if(!_closed) {
        throw Exception('unexpectedly closed server ${socket.name}');
      }
    },);
  }

  final WebSocketWrapper socket;
  late StreamSubscription subscription;
  bool _closed = false;

  void close() {
    _closed = true;
    socket.close();
  }

  Completer<void> moreItems = Completer();
  List<List<String>> items = [];
  List<Object?> sent = [];

  /// Sends [message] to connected server
  void send(List<String> message) {
    assert(!message.contains('\x00'));
    socket.send(message.join('\x00') + '\x00');
  }

  // Waits for an item to be recieved and returns it.
  Future<List<String>> readItem() async {
    if (items.isEmpty) await moreItems.future;
    return items.removeAt(0);
  }
}
