import 'dart:async';
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.js_interop) 'sockets_cookies_web.dart';

class NetworkConnection {
  NetworkConnection(
      this.socket,
      void Function(List<String>) unrequestedMessageHandler,
      void binaryMessageHandler(List<int> data),
      void Function() onReset) {
    subscription =
        doListen(unrequestedMessageHandler, binaryMessageHandler, onReset);
  }

  bool get reloading => socket.reloading;

  StreamSubscription<dynamic> doListen(
      void unrequestedMessageHandler(List<String> data),
      void binaryMessageHandler(List<int> data),
      void onReset()) {
    return socket.listen(
      (rawMessage) {
        if (rawMessage is String) {
          List<String> message = rawMessage.split('\x00');
          // message[0] is the message type. Anything other than 'reply' is passed to unrequestedMessageHandler.
          // message[1] (for replies) is the conversation ID, which in our case is the index into the replies list.
          assert(message.last ==
              ''); // all messages are null-terminated and we're splitting on nulls
          if (message[0] == 'reply') {
            int conversationID = int.parse(message[1]);
            if (replies.length <= conversationID ||
                replies[conversationID].isCompleted) {
              throw Exception('unrequested reply $message');
            }
            replies[conversationID]
                .complete(message.sublist(2, message.length - 1));
          } else {
            unrequestedMessageHandler(message.sublist(0, message.length - 1));
          }
        } else {
          binaryMessageHandler(rawMessage);
        }
      },
      onReset: () {
        doListen(unrequestedMessageHandler, binaryMessageHandler, onReset);
        onReset();
      },
    );
  }

  final WebSocketWrapper socket;
  late StreamSubscription subscription;

  void close() {
    socket.close();
  }

  List<Completer<List<String>>> replies = [];

  /// Sends [message] to connected server.
  Future<List<String>> send(List<String> message) {
    assert(!message.contains('\x00'));
    int index = replies.indexWhere((e) => e.isCompleted);
    Completer<List<String>> reply = Completer();
    if (index == -1) {
      index = replies.length;
      replies.add(reply);
    } else {
      replies[index] = reply;
    }
    message.insert(0, index.toString());
    socket.send(message.join('\x00') + '\x00');
    return reply.future;
  }
}
