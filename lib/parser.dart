import 'data-structure.dart';

// if the return value of this function is non-null, it is an error message.
String? parseMessage(DataStructure data, List<String> message) {
  switch (message.first) {
    default:
      return 'Error: Unexpected unrequested message $message';
  }
}