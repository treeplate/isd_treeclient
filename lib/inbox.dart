import 'package:flutter/material.dart';
import 'assets.dart';
import 'data-structure.dart';

class Inbox extends StatefulWidget {
  const Inbox({super.key, required this.data});
  final DataStructure data;

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
              Text(
                'Inbox',
                style: TextTheme.of(context).headlineLarge,
              ),
              SizedBox(
                child: TabBar(
                  controller: tabController,
                  tabs: widget.data.rootAssets.keys.map((e) {
                    int messageCount =
                        findMessages(widget.data.rootAssets[e]!, widget.data)
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
  const SystemInbox({super.key, required this.rootAsset, required this.data});
  final AssetID rootAsset;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: findMessages(
        rootAsset,
        data,
      ).map((e) => InboxMessage(message: e, data: data)).toList(),
    );
  }
}

class InboxMessage extends StatelessWidget {
  const InboxMessage({super.key, required this.message, required this.data});
  final Asset message;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    MessageFeature messageFeature = message.features.single as MessageFeature;
    return Row(
      children: [
        Text(
          '${messageFeature.message}',
          style: DefaultTextStyle.of(context).style.copyWith(
                fontWeight:
                    messageFeature.isRead ? FontWeight.normal : FontWeight.bold,
              ),
        )
      ],
    );
  }
}

List<Asset> findMessages(AssetID root, DataStructure data) {
  List<Asset> result = [];
  _findMessages(root, data, result);
  return result;
}

void _findMessages(AssetID root, DataStructure data, List<Asset> result) {
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
        result.add(rootAsset);
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
