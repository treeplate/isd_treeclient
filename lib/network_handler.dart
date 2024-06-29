import 'dart:async';
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.js_interop) 'sockets_cookies_web.dart';

class NetworkConnection {
  NetworkConnection(
      this.socket,
      void Function(List<String>) unrequestedMessageHandler,
      void Function() onReset) {
    subscription = doListen(unrequestedMessageHandler, onReset);
  }

  StreamSubscription<dynamic> doListen(
      void unrequestedMessageHandler(List<String> data), void onReset()) {
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
            if (binaryReplies[conversationID] != null) {
              if (message[2] == 'F') {
                throw Exception('binary message failed $message');
              }
              assert(message[2] == 'T');
              assert(message.length ==
                  5, message); // reply, conversationID, T, fileID, empty string
              fileIDs[int.parse(message[3])] = binaryReplies[conversationID]!;
            }
            replies[conversationID]
                .complete(message.sublist(2, message.length - 1));
          } else {
            unrequestedMessageHandler(message.sublist(0, message.length - 1));
          }
        } else {
          int fileID = rawMessage[0];
          fileIDs[fileID]!.complete(rawMessage.skip(4).toList());
        }
      },
      onReset: () {
        doListen(unrequestedMessageHandler, onReset);
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
  Map<int, Completer<List<int>>> binaryReplies =
      {}; // [replies] index -> actual binary completer
  Map<int, Completer<List<int>>> fileIDs = {}; // file ID -> completer

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

  /// Sends [message] to connected server.
  Future<List<int>> sendExpectingBinaryReply(List<String> message) {
    assert(!message.contains('\x00'));
    Completer<List<int>> reply = Completer();
    int index = replies.indexWhere((e) => e.isCompleted);
    Completer<List<String>> reply2 = Completer();
    if (index == -1) {
      index = replies.length;
      replies.add(reply2);
    } else {
      replies[index] = reply2;
    }
    message.insert(0, index.toString());
    binaryReplies[index] = reply;
    socket.send(message.join('\x00') + '\x00');
    return reply.future;
  }
}
