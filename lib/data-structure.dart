import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.html) 'sockets_cookies_html.dart';

class DataStructure with ChangeNotifier {
  String? tempCurrentMessage;
  String? username;
  String? password;

  void tempMessage(String message) {
    tempCurrentMessage = message;
    notifyListeners();
  }

  void setCredentials(String username, String password) {
    setCookie('username', username);
    setCookie('password', password);
    this.username = username;
    this.password = password;
    notifyListeners();
  }

  void removeCredentials() {
    setCookie('username', null);
    setCookie('password', null);
    username = null;
    password = null;
    notifyListeners();
  }

   void updateUsername(String username) {
    setCookie('username', username);
    this.username = username;
    notifyListeners();
  }

  void updatePassword(String password) {
    setCookie('password', password);
    this.password = password;
    notifyListeners();
  }

  DataStructure() {
    username = getCookie('username');
    password = getCookie('password');
  }
}