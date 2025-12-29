import 'dart:math';

import 'package:flutter/material.dart';
import 'core.dart';
import 'knowledge.dart';
import 'ui-core.dart';
import 'assets.dart';
import 'calendar.dart';
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
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: Icon(Icons.close),
                  )
                ],
              ),
              SizedBox(
                child: TabBar(
                  controller: tabController,
                  tabs: widget.data.rootAssets.keys.map((e) {
                    int messageCount = widget.data
                        .findFeature<MessageFeature>(widget.data.rootAssets[e]!)
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
    return ListView(
      children: data
          .findFeature<MessageFeature>(rootAsset)
          .map((e) => InboxMessage(
                message: e,
                data: data,
                server: server,
              ))
          .toList()..sort((a,b) => -getTimestamp(a).compareTo(getTimestamp(b))),
    );
  }

  Uint64 getTimestamp(InboxMessage a) => data.assets[a.message]!.features.whereType<MessageFeature>().single.timestamp;
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
        data.assets[message]!.features.whereType<MessageFeature>().single;
    KnowledgeFeature? knowledgeFeature = data.assets[message]!.features
        .whereType<KnowledgeFeature>()
        .singleOrNull;
    return TextButton(
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(context).style.copyWith(
              fontWeight:
                  messageFeature.isRead ? FontWeight.normal : FontWeight.bold,
            ),
        child: LayoutBuilder(builder: (context, constraints) {
          return Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      messageFeature.from,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: max(0, constraints.maxWidth - 250),
                    child: Text.rich(
                      TextSpan(
                        text: messageFeature.subject,
                        children: [
                          TextSpan(
                            text:
                                ' - ${messageFeature.text.replaceAll('\n', ' ')}',
                            style: DefaultTextStyle.of(context).style.copyWith(
                                  fontWeight: messageFeature.isRead
                                      ? FontWeight.w300
                                      : FontWeight.normal,
                                ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Container(),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      calendar.dateName(messageFeature.timestamp) +
                          ' ' +
                          calendar.timeName(messageFeature.timestamp),
                    ),
                  ),
                ],
              ),
              if (knowledgeFeature != null &&
                  knowledgeFeature.classes.length +
                          knowledgeFeature.materials.length >
                      0)
                Row(
                  children: [
                    SizedBox(
                      width: 150,
                    ),
                    ...knowledgeFeature.classes
                        .map((e) => Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: AttachmentButton(
                                  icon: e.icon,
                                  name: e.name,
                                  openDialog: (context) =>
                                      AssetClassDialog(assetClass: e)),
                            ))
                        .followedBy(knowledgeFeature.materials.values
                            .map((e) => Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: AttachmentButton(
                                    icon: e.icon,
                                    name: e.name,
                                    openDialog: (context) =>
                                        MaterialDialog(material: e),
                                  ),
                                )))
                        .take(3),
                    if (knowledgeFeature.classes.length +
                            knowledgeFeature.materials.length >
                        3)
                      Text(
                          '+${knowledgeFeature.classes.length + knowledgeFeature.materials.length - 3}')
                  ],
                )
            ],
          );
        }),
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
              knowledge: knowledgeFeature,
              server: server,
              asset: message,
            ),
          ),
        );
      },
    );
  }
}

class InboxMessageDialog extends StatelessWidget {
  const InboxMessageDialog(
      {super.key,
      required this.message,
      required this.knowledge,
      required this.server,
      required this.asset});
  final MessageFeature message;
  final KnowledgeFeature? knowledge;
  final NetworkConnection server;
  final AssetID asset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  textAlign: TextAlign.center,
                  message.subject,
                  style: TextTheme.of(context).headlineLarge,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                if (context.mounted) {
                  Navigator.pop(context);
                }
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '${calendar.dateName(message.timestamp)} ${calendar.timeName(message.timestamp)} (${message.timestamp.displayName})',
              ),
            ),
            OutlinedButton(
              onPressed: () {
                server.send([
                  'play',
                  asset.system.value.toString(),
                  asset.id.toString(),
                  message.isRead ? 'mark-unread' : 'mark-read'
                ]);
              },
              child: Text(message.isRead ? 'Mark as unread' : 'Mark as read'),
            )
          ],
        ),
        SelectableText(message.text),
        if (knowledge != null &&
            knowledge!.classes.length + knowledge!.materials.length > 0)
          Divider(),
        if (knowledge != null)
          Wrap(children: [
            ...knowledge!.classes
                .map((e) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: AttachmentButton(
                          icon: e.icon,
                          name: e.name,
                          openDialog: (context) =>
                              AssetClassDialog(assetClass: e)),
                    ))
                .followedBy(knowledge!.materials.values.map((e) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: AttachmentButton(
                        icon: e.icon,
                        name: e.name,
                        openDialog: (context) => MaterialDialog(material: e),
                      ),
                    )))
          ]),
      ],
    );
  }
}

class AttachmentButton extends StatelessWidget {
  const AttachmentButton(
      {super.key,
      required this.icon,
      required this.name,
      required this.openDialog});

  final String icon;
  final String name;
  final Widget Function(BuildContext context) openDialog;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
        onPressed: () {
          showDialog(context: context, builder: openDialog);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
                color: Colors.grey,
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: ISDIcon(icon: icon, width: 16, height: 16),
                )),
            Text(name)
          ],
        ));
  }
}
