import 'dart:async';
import 'dart:io';

class WebSocketWrapper {
  final WebSocket socket;

  
  StreamSubscription<dynamic> listen(void onData(dynamic event),
      {Function? onError, void onDone()?, bool? cancelOnError}) {
    return socket.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void send(String data) {
    socket.add(data);
  }

  WebSocketWrapper(this.socket);
}

Future<WebSocketWrapper> connect(String serverUrl) async {
  return WebSocketWrapper(await WebSocket.connect(serverUrl));
}

File _cookieStorage = File('cookies.save');
Map<String, String>? _cookieCache;

String? getCookie(String name) {
  getCookiesFromFile();
  return _cookieCache![name];
}

void getCookiesFromFile() {
  if (_cookieCache == null) {
    if (_cookieStorage.existsSync()) {
      try {
        _cookieCache = Map.fromEntries(
          _cookieStorage.readAsLinesSync().map(
            (String line) {
              List<String> parts = line.split(':');
              if(parts.length != 2) {
                throw FormatException('invalid _cookieStorage format');
              }
              return MapEntry(parts.first, parts.last);
            },
          ),
        );
      } catch (e) {
        print('Error "$e" while parsing _cookieStorage');
        _cookieCache = {};
      }
    } else {
      _cookieCache = {};
    }
  }
}

void setCookie(String name, String value) {
  getCookiesFromFile();
  _cookieCache![name] = value;
  _cookieStorage.writeAsStringSync(_cookieCache!.entries.map((MapEntry<String, String> entry) => '${entry.key}:${entry.value}').join('\n')); 
}
