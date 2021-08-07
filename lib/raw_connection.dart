import 'dart:io';

WebSocket webSocket;

Future<void> connect() async {
  webSocket = await WebSocket.connect("ws://software.hixie.ch:13534/");
}