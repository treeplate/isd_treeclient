import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Duration pingInterval = Duration(seconds: 10);

class WebSocketWrapper {
  WebSocket socket;
  bool reloading = false;
  Completer<void> _doneReloading = Completer();

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
      onDone: ()  {
        if (!_closed) {
          reconnect(onData, onError, onReset);
        }
      },
    );
  }

  Future<void> reconnect(void onData(dynamic event), void Function(Object error, StackTrace)? onError,
    void Function()? onReset, [Duration waitingTime = const Duration(milliseconds: 100)]) async {
    _doneReloading = Completer();
    reloading = true;
    do {
    try {
      socket = await WebSocket.connect(name);
      socket.pingInterval = pingInterval;
      reloading = false;
      _doneReloading.complete();
      listen(onData, onError: onError, onReset: onReset);
    } catch (e, st) {
      try {
      if (onError == null) rethrow;
      onError(e, st);
      } finally {
        waitingTime *= 2;
        print('waiting $waitingTime...');
        await Future.delayed(waitingTime);
        continue;
      }
    }
    } while(false);
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

File? _cookieStorage;
Directory? _binaryDataDirectory;
Map<String, String>? _cookieCache;

Future<String?> getCookie(String name) async {
  await getCookiesFromFile();
  return _cookieCache![name];
}

Future<void> getCookiesFromFile() async {
  if (_cookieCache == null) {
    if (_cookieStorage == null) {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      _cookieStorage = File(documentsDirectory.path + '/cookies.save');
    }
    if (_cookieStorage!.existsSync()) {
      try {
        String fileContents = _cookieStorage!.readAsStringSync();
        if (fileContents == '') {
          _cookieCache = {};
        } else {
          _cookieCache = Map.fromEntries(
            fileContents.split('\n\x00').map(
              (String line) {
                List<String> parts = line.split(':\x00');
                if (parts.length != 2) {
                  throw FormatException('invalid _cookieStorage format');
                }
                return MapEntry(parts.first, parts.last);
              },
            ),
          );
        }
      } catch (e) {
        print('Error "$e" while parsing _cookieStorage');
        _cookieCache = {};
      }
    } else {
      _cookieCache = {};
    }
  }
}

void setCookie(String name, String? value) async {
  await getCookiesFromFile();
  if (value == null) {
    _cookieCache!.remove(name);
  } else {
    _cookieCache![name] = value;
  }
  _cookieStorage!.writeAsStringSync(
    _cookieCache!.entries
        .map((MapEntry<String, String> entry) =>
            '${entry.key}:\x00${entry.value}')
        .join('\n\x00'),
  );
}

Future<Uint8List?> getBinaryBlob(String name) async {
  if (_binaryDataDirectory == null) {
    _binaryDataDirectory = await getApplicationCacheDirectory();
  }
  File file = File('${_binaryDataDirectory!.path}/$name.bin');
  return file.existsSync() ? file.readAsBytesSync() : null;
}

void saveBinaryBlob(String name, List<int> data) async {
  if (_binaryDataDirectory == null) {
    _binaryDataDirectory = await getApplicationCacheDirectory();
  }
  File('${_binaryDataDirectory!.path}/$name.bin').writeAsBytesSync(data);
}
