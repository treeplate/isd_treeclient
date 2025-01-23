import '../../network_handler.dart';
import 'dart:io';
import 'dart:typed_data';

void main() async {
    NetworkConnection loginServer = await NetworkConnection.fromURL(
      loginServerURL,
      unrequestedMessageHandler: (List<String> message) {
        print(message);
      },
      binaryMessageHandler: (ByteBuffer data) {
        print(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        print(error);
      },
    );
    print('Type "new" for a new game or "login" to log in');
    String command = stdin.readLineSync()!;
    String username;
    String password;
    String dynastyServerURL;
    String token;
    if (command == 'new') {
      List<String> result = await loginServer.send(['new']);
      username = result[1];
      password = result[2];
      dynastyServerURL = result[3];
      token = result[4];
    } else if (command == 'login') {
      print('Username:');
      username = stdin.readLineSync()!;
      print('Password:');
      password = stdin.readLineSync()!;
      List<String> result = await loginServer.send(['login', username, password]);
      if (result[0] == 'F') {
        print(result);
        return;
      }
      dynastyServerURL = result[1];
      token = result[2];
    } else {
      print('Invalid command.');
      return;
    }
    NetworkConnection dynastyServer = await NetworkConnection.fromURL(
      dynastyServerURL,
      unrequestedMessageHandler: (List<String> message) {
        print(message);
      },
      binaryMessageHandler: (ByteBuffer data) {
        print(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        print(error);
      },
    );
    print(await dynastyServer.send(['login', token]));
}
