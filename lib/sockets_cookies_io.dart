import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class WebSocketWrapper {
  WebSocket socket;

  StreamSubscription<dynamic> listen(
    void onData(dynamic event), {
    Function? onError,
    void onReset()?,
    bool? cancelOnError,
  }) {
    return socket.listen(
      onData,
      onError: onError,
      onDone: () async {
        if (!_closed) {
          socket = await WebSocket.connect(name);
          if (onReset != null) {
            onReset();
          }
        }
      },
      cancelOnError: cancelOnError,
    );
  }

  void send(String data) {
    socket.add(data);
  }

  bool _closed = false;
  void close() {
    _closed = true;
    socket.close();
  }

  final String name;

  WebSocketWrapper(this.socket, this.name);
}

Future<WebSocketWrapper> connect(String serverUrl) async {
  return WebSocketWrapper(await WebSocket.connect(serverUrl), serverUrl);
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
          _cookieStorage.readAsStringSync().split('\n\x00').map(
            (String line) {
              List<String> parts = line.split(':\x00');
              if (parts.length != 2) {
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

void setCookie(String name, String? value) {
  getCookiesFromFile();
  if (value == null) {
    _cookieCache!.remove(name);
  } else {
    _cookieCache![name] = value;
  }
  _cookieStorage.writeAsStringSync(_cookieCache!.entries
      .map(
          (MapEntry<String, String> entry) => '${entry.key}:\x00${entry.value}')
      .join('\n\x00'));
}

Uint8List? getBinaryBlob(String name) {
  File file = File('$name.bin');
  return file.existsSync() ? file.readAsBytesSync() : null;
}

void saveBinaryBlob(String name, List<int> data) {
  File('$name.bin').writeAsBytesSync(data);
}
