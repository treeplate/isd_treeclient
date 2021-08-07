import 'package:flutter/material.dart';
import 'parser.dart';
import 'raw_connection.dart';

void main() async {
  await connect();
  webSocket.add(login);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  _MyHomePageState() {
    webSocket.listen((event) {
      setState(() {
        parseMessage(event);
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
              Text(actors.toString()),
              Container(
                height: 10,
                child: SizedBox.expand(
                  child: Container(color: Colors.black),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                        child: NamedSection(
                            'Research', getGridChildren(setState))),
                    Container(
                      width: 10,
                      child: SizedBox.expand(
                        child: Container(color: Colors.black),
                      ),
                    ),
                    Expanded(
                        child:
                            NamedSection('Building', getGridSlots(setState))),
                    Container(
                      width: 10,
                      child: SizedBox.expand(
                        child: Container(color: Colors.black),
                      ),
                    ),
                    Expanded(child: FilteredActors(typeFilter('news'), 'news')),
                  ],
                ),
              ),
            ],
          ),
          dialog
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

class FilteredActors extends StatelessWidget {
  final bool Function(Actor) filter;
  final String name;

  FilteredActors(this.filter, this.name);

  @override
  Widget build(BuildContext context) {
    return NamedSection(
      name,
      actors.values
          .where(filter)
          .map((e) => Center(child: Text(e.toString())))
          .toList(),
    );
  }
}

bool Function(Actor) typeFilter(String type) =>
    (Actor actor) => actor?.type == type;

List<Widget> getGridChildren(setState) {
  List<Widget> result = [];
  for (Actor actor in actors.values) {
    if (actor?.props['ResearchTopics'] != null) {
      result.add(Container(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          children: [
            Text(
                "${actor?.props['ThrusterMode'] != null ? 'flying ' : ''}research facility"),
            TextButton(
              onPressed: () {
                setState(() {
                  dialog = Container(
                    color: Color(0xEEFFFFFF),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:
                          (actor?.props['ResearchTopics'].value as List<String>)
                              .map(
                                (String topic) => TextButton(
                                  child: Text("$topic"),
                                  onPressed: () {
                                    setState(() {
                                      lastMessageId++;
                                      String message =
                                          "$lastMessageId\x00${actor.id}\x00set-research-topic\x00$topic\x00";
                                      webSocket.add(message);
                                      messagesSent.add(message);
                                      dialog = Container();
                                    });
                                  },
                                ),
                              )
                              .toList(),
                    ),
                  );
                });
              },
              child: Text(
                  "  set topic (currently ${actor?.props['SelectedResearchTopic'].value})  "),
            ),
            if (actor?.props['ThrusterMode'] != null)
              TextButton(
                child: Text(actor?.props['ThrusterMode'].value == "tmFiring"
                    ? "Stop thrusters"
                    : "Fire thrusters"),
                onPressed: () {
                  lastMessageId++;
                  String message =
                      "$lastMessageId\x00${actor.id}\x00thruster-control\x00${actor?.props['ThrusterMode'].value == "tmFiring" ? "tmOff" : "tmFiring"}\x00";
                  webSocket.add(message);
                  messagesSent.add(message);
                },
              ),
          ],
        ),
      ));
    }
  }
  return result;
}

List<Widget> getGridSlots(setState) {
  Map<String, int> slotTypes = {};
  Map<String, Location> lastLocation = {};
  for (Actor actor in actors.values) {
    if (actor?.type == "grid") {
      if (actor.info is! GridExtraInfo) {
        continue;
      }
      GridExtraInfo info = actor.info;
      int cN = 0;
      for (GridCell cell in info.grid) {
        if (cell.actor == null) {
          if (slotTypes[cell.env] == null)
            slotTypes[cell.env] = 1;
          else
            slotTypes[cell.env]++;
          lastLocation[cell.env] =
              Location(actor.id, "${cN % info.w}\x00${(cN / info.w).floor()}");
        }
        cN++;
      }
    }
  }
  return slotTypes.entries
      .map((entry) => Row(
            children: [
              Text("${entry.key}: ${entry.value}"),
              TextButton(
                onPressed: () {
                  setState(() {
                    dialog = Container(
                      color: Color(0xEEFFFFFF),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                                Text("Build on type ${entry.key}:"),
                              ] +
                              techs
                                  .map((e) => TextButton(
                                        child: Text(e),
                                        onPressed: () {
                                          setState(() {
                                            lastMessageId++;
                                            String message =
                                                "$lastMessageId\x000\x00build\x00$e\x00${lastLocation[entry.key].actor}\x00${lastLocation[entry.key].location}\x00";
                                            webSocket.add(message);
                                            messagesSent.add(message);
                                            dialog = Container();
                                          });
                                        },
                                      ))
                                  .toList(),
                        ),
                      ),
                    );
                  });
                },
                child: Text("Build"),
              ),
            ],
          ))
      .toList();
}

Widget dialog = Container();

class Location {
  final int actor;
  final String location;

  String toString() => "$actor ($location)";

  Location(this.actor, this.location);
}
