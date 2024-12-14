import 'package:flutter/material.dart';
import 'assets.dart';
import 'data-structure.dart';
import 'network_handler.dart';

class Inbox extends StatefulWidget {
  const Inbox({super.key, required this.data, required this.servers});
  final DataStructure data;
  final Map<StarIdentifier, NetworkConnection> servers;

  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> with TickerProviderStateMixin {
  TabController? tabController;

  @override
  void initState() {
    super.initState();
    didUpdateWidget(widget);
  }

  @override
  void didUpdateWidget(covariant Inbox oldWidget) {
    tabController?.dispose();
    tabController = TabController(
      length: widget.data.rootAssets.length,
      vsync: this,
      initialIndex: tabController?.index ?? 0,
    );
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: widget.data,
        builder: (context, child) {
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(),
                  Text(
                    'Inbox',
                    style: TextTheme.of(context).headlineLarge,
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close),
                  )
                ],
              ),
              SizedBox(
                child: TabBar(
                  controller: tabController,
                  tabs: widget.data.rootAssets.keys.map((e) {
                    int messageCount =
                        findMessages(widget.data.rootAssets[e]!, widget.data)
                            .where((e) => widget.data.assets[e]!.features
                                .any((e) => e is MessageFeature && !e.isRead))
                            .length;
                    return Badge.count(
                      count: messageCount,
                      isLabelVisible: messageCount > 0,
                      child: Text(e.displayName),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: widget.data.rootAssets.values
                      .map((e) => SystemInbox(
                            rootAsset: e,
                            data: widget.data,
                            server: widget.servers[e.system]!,
                          ))
                      .toList(),
                ),
              ),
            ],
          );
        });
  }
}

class SystemInbox extends StatelessWidget {
  const SystemInbox(
      {super.key,
      required this.rootAsset,
      required this.data,
      required this.server});
  final AssetID rootAsset;
  final DataStructure data;
  final NetworkConnection server;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: findMessages(
        rootAsset,
        data,
      )
          .map((e) => InboxMessage(
                message: e,
                data: data,
                server: server,
              ))
          .toList(),
    );
  }
}

class InboxMessage extends StatelessWidget {
  const InboxMessage(
      {super.key,
      required this.message,
      required this.data,
      required this.server});
  final AssetID message;
  final DataStructure data;
  final NetworkConnection server;

  @override
  Widget build(BuildContext context) {
    MessageFeature messageFeature =
        data.assets[message]!.features.single as MessageFeature;
    return TextButton(
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(context).style.copyWith(
              fontWeight:
                  messageFeature.isRead ? FontWeight.normal : FontWeight.bold,
            ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(messageFeature.from),
            ),
            Text(messageFeature.subject),
            Text(
              '- ${messageFeature.body}',
              overflow: TextOverflow.ellipsis,
              style: DefaultTextStyle.of(context).style.copyWith(
                    fontWeight: messageFeature.isRead
                        ? FontWeight.w300
                        : FontWeight.normal,
                  ),
            ),
            Expanded(
              child: Container(),
            ),
            SizedBox(
              width: 100,
              child: Text(messageFeature.timestamp.displayName),
            ),
          ],
        ),
      ),
      onPressed: () {
        server.send([
          'play',
          message.system.value.toString(),
          message.id.toString(),
          'mark-read'
        ]);
        showDialog(
            context: context,
            builder: (context) => Dialog(
                child: InboxMessageDialog(
                    message: messageFeature,
                    server: server,
                    messageAsset: message)));
      },
    );
  }
}

class InboxMessageDialog extends StatelessWidget {
  const InboxMessageDialog(
      {super.key,
      required this.message,
      required this.server,
      required this.messageAsset});
  final MessageFeature message;
  final NetworkConnection server;
  final AssetID messageAsset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(),
            Text(
              message.subject,
              style: TextTheme.of(context).headlineLarge,
            ),
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.close),
            )
          ],
        ),
        Row(
          children: [
            Text(message.from),
            Text(
              ' (${message.source.displayName})',
              style: DefaultTextStyle.of(context)
                  .style
                  .copyWith(fontWeight: FontWeight.w300),
            ),
            Expanded(child: Container()),
            Text('${message.timestamp.displayName}')
          ],
        ),
        Text(message.body),
        OutlinedButton(
          onPressed: () {
            server.send([
              'play',
              messageAsset.system.value.toString(),
              messageAsset.id.toString(),
              message.isRead ? 'mark-unread' : 'mark-read'
            ]);
          },
          child: Text(message.isRead ? 'Mark as unread' : 'Mark as read'),
        )
      ],
    );
  }
}

List<AssetID> findMessages(AssetID root, DataStructure data) {
  List<AssetID> result = [];
  _findMessages(root, data, result);
  return result;
}

void _findMessages(AssetID root, DataStructure data, List<AssetID> result) {
  Asset rootAsset = data.assets[root]!;
  for (Feature feature in rootAsset.features) {
    switch (feature) {
      case SolarSystemFeature(children: List<SolarSystemChild> children):
        for (SolarSystemChild child in children) {
          _findMessages(child.child, data, result);
        }
      case OrbitFeature(
          primaryChild: AssetID primaryChild,
          orbitingChildren: List<OrbitChild> orbitingChildren,
        ):
        _findMessages(primaryChild, data, result);
        for (OrbitChild child in orbitingChildren) {
          _findMessages(child.child, data, result);
        }
      case SurfaceFeature(regions: List<AssetID> regions):
        for (AssetID region in regions) {
          _findMessages(region, data, result);
        }
      case GridFeature(cells: List<AssetID?> cells):
        for (AssetID? cell in cells) {
          if (cell != null) {
            _findMessages(cell, data, result);
          }
        }
      case MessageBoardFeature(messages: List<AssetID> messages):
        for (AssetID message in messages) {
          _findMessages(message, data, result);
        }
      case MessageFeature():
        result.add(root);
      case StructureFeature():
      case StarFeature():
      case SpaceSensorFeature():
      case SpaceSensorStatusFeature():
      case PlanetFeature():
      case PlotControlFeature():
      case PopulationFeature():
        break;
    }
  }
}
