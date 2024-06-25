import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.js_interop) 'sockets_cookies_web.dart';

const String kUsernameCookieName = 'username';
const String kPasswordCookieName = 'password';
const String kStarsCookieName = 'stars';
const int integerLimit32 = 0x100000000;

typedef StarIdentifier = (int category, int subindex);

StarIdentifier parseStarIdentifier(int value) {
  return (value >> 20, value & 0xFFFFF);
}

extension StarIdentifierConversion on StarIdentifier {
  int get value => $1 << 20 + $2;
}

class DataStructure with ChangeNotifier {
  String? username;
  String? password;
  String? token;
  List<List<Offset>>? stars;

  void setCredentials(String username, String password) {
    setCookie(kUsernameCookieName, username);
    setCookie(kPasswordCookieName, password);
    this.username = username;
    this.password = password;
    notifyListeners();
  }

  void removeCredentials() {
    setCookie(kUsernameCookieName, null);
    setCookie(kPasswordCookieName, null);
    username = null;
    password = null;
    notifyListeners();
  }

  void setToken(String token) {
    this.token = token;
    notifyListeners();
  }

  void updateUsername(String username) {
    setCookie(kUsernameCookieName, username);
    this.username = username;
    notifyListeners();
  }

  void updatePassword(String password) {
    setCookie(kPasswordCookieName, password);
    this.password = password;
    notifyListeners();
  }

  void parseStars(List<int> rawStars) {
    List<List<Offset>> stars = [];
    Uint32List rawStars32 = Uint8List.fromList(rawStars).buffer.asUint32List();
    int categoryCount = rawStars32[0];
    int category = 0;
    int index = categoryCount + 1;
    assert(rawStars32.length ==
        categoryCount +
            1 +
            rawStars32
                .sublist(1, categoryCount + 1)
                .map((e) => e * 2)
                .reduce((e, f) => e + f));
    while (category < categoryCount) {
      int categoryLength = rawStars32[category + 1];
      int originalIndex = index;
      stars.add([]);
      while (index < originalIndex + categoryLength * 2) {
        stars[category].add(Offset(rawStars32[index] / integerLimit32,
            rawStars32[index + 1] / integerLimit32));
        index += 2;
      }
      category++;
    }
    this.stars = stars;
    saveBinaryBlob(kStarsCookieName, rawStars);
    notifyListeners();
  }

  DataStructure() {
    username = getCookie(kUsernameCookieName);
    password = getCookie(kPasswordCookieName);
    Uint8List? binaryBlob = getBinaryBlob(kStarsCookieName);
    if (binaryBlob != null) {
      parseStars(binaryBlob);
    }
  }
}
