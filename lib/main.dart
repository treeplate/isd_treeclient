import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isd_treeclient/data-structure.dart';
import 'parser.dart';
import 'raw_connection.dart';

void main() async {
  WebSocket webSocket = await connect();
  webSocket.add('Hello');
  runApp(MyApp(
    webSocket: webSocket,
  ));
}

class MyApp extends StatelessWidget {
  final WebSocket webSocket;

  const MyApp({super.key, required this.webSocket});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(
        webSocket: webSocket,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.webSocket});

  final WebSocket webSocket;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  DataStructure data = DataStructure();

  void initState() {
    super.initState();
    widget.webSocket.listen((event) {
      setState(() {
        parseMessage(data, event);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('No data'),
            ],
          ),
        ],
      ),
    );
  }
}

class NamedSection extends StatelessWidget {
  final String name;
  final List<Widget> contents;

  NamedSection(this.name, this.contents);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Text(name),
        ),
        Container(
          height: 10,
          child: SizedBox.expand(
            child: Container(color: Colors.black),
          ),
        ),
        Expanded(
          child: ListView(
            children: contents,
          ),
        ),
      ],
    );
  }
}
