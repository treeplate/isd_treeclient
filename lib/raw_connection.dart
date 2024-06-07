import 'dart:io';

Future<WebSocket> connect() async {
  return await WebSocket.connect("ws://software.hixie.ch:1024/");
}