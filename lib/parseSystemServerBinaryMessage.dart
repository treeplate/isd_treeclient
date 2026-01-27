import 'package:flutter/widgets.dart' show Offset;

import 'assets.dart';
import 'binaryreader.dart';
import 'data-structure.dart';
import 'feature_parser.dart';

import 'core.dart';

Set<StarIdentifier> parseSystemServerBinaryMessage(
    BinaryReader message, DataStructure data) {
  Set<StarIdentifier> systems = {};
  while (!message.done) {
    int id = message.readUint32();
    if (id < 0x10000000) {
      StarIdentifier systemID = StarIdentifier.parse(id);
      systems.add(systemID);
      (DateTime, Uint64) time0 = (DateTime.timestamp(), message.readUint64());
      double timeFactor = message.readFloat64();
      id = message.readUint32();
      assert(id != 0);
      AssetID rootAssetID = AssetID(systemID, id);
      data.setRootAsset(systemID, rootAssetID);
      Offset position = Offset(message.readFloat64(), message.readFloat64());
      data.setSystemPosition(systemID, position / data.galaxyDiameter!);
      data.setTime0(systemID, time0);
      data.setTimeFactor(systemID, timeFactor);
      Set<AssetID> notReferenced = {};
      while (true) {
        int id = message.readUint32();
        if (id == 0) break;
        AssetID assetID = AssetID(systemID, id);
        data.getChildren(assetID, notReferenced);
        int owner = message.readUint32();
        double mass = message.readFloat64();
        double massFlowRate = message.readFloat64();
        double size = message.readFloat64();
        String name = message.readString();
        AssetClass assetClass = message.readAssetClass(false)!;
        List<Feature> features = [];
        while (true) {
          int featureCode = message.readUint32();
          if (featureCode == 0) break;
          try {
            Feature feature = parseFeature(
              featureCode,
              message,
              systemID,
              notReferenced,
              data,
            );
            assert(assetClass.id != null || !feature.mustKnowAssetClass, 'server invariant failed: $feature for asset with unknown class ($name/${assetClass.name})');
            features.add(feature);
          } catch (e) {
            throw Exception('$e');
          }
        }
        data.setAsset(
          assetID,
          Asset(
            features,
            mass,
            massFlowRate,
            owner == 0 ? null : owner,
            size,
            name == '' ? null : name,
            assetClass,
            time0.$2,
          ),
        );
      }
      for (AssetID asset in notReferenced) {
        data.removeAsset(asset);
      }
      // TODO: there might be a possible race condition? sometimes this triggers for some reason
      assert(data.assets[rootAssetID] != null);
    } else {
      switch (id) {
        default:
          throw UnimplementedError(
              'Unknown notification ID 0x${id.toRadixString(16)}');
      }
    }
  }
  return systems;
}
