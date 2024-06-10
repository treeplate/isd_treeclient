import 'data-structure.dart';
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.html) 'sockets_cookies_html.dart';

void parseMessage(DataStructure data, String message, WebSocketWrapper connection) {
  List<String> parts = message.split('\x00');
  switch (parts.first) {
    case 'account':
      data.setCredentials(parts[1], parts[2]);
    default:
      data.tempMessage(message);
  }
}
