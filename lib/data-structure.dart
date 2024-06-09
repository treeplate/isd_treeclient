import 'package:flutter/foundation.dart' show ChangeNotifier;

class DataStructure with ChangeNotifier {
  String? tempCurrentMessage;
  void tempMessage(String message) {
    tempCurrentMessage = message;
    notifyListeners();
  }
}