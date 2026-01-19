import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

File? _cookieStorage;
Directory? _binaryDataDirectory;
Map<String, String> cookieCache = {};
bool cookiesCached = false;

Future<String?> getCookie(String name) async {
  await getCookiesFromFile();
  return cookieCache[name];
}

Future<void> getCookiesFromFile() async {
  if (!cookiesCached) {
    if (_cookieStorage == null) {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      _cookieStorage = File(documentsDirectory.path + '/cookies.save');
    }
    if (_cookieStorage!.existsSync()) {
      try {
        String fileContents = _cookieStorage!.readAsStringSync();
        if (fileContents == '') {
          cookieCache = {};
        } else {
          cookieCache = Map.fromEntries(
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
        cookieCache.addAll(cookieCache);
      } catch (e) {
        cookieCache = {
          'previousError': '$e',
        };
      }
    } else {
      cookieCache = {};
    }
    cookiesCached = true;
  }
}

void setCookie(String name, String? value) async {
  await getCookiesFromFile();
  if (value == null) {
    cookieCache.remove(name);
  } else {
    cookieCache[name] = value;
  }
  _cookieStorage!.writeAsStringSync(
    cookieCache.entries
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

Future<void> saveBinaryBlob(String name, ByteBuffer data) async {
  if (_binaryDataDirectory == null) {
    _binaryDataDirectory = await getApplicationCacheDirectory();
  }
  await File('${_binaryDataDirectory!.path}/$name.bin')
      .writeAsBytes(data.asUint8List());
}
