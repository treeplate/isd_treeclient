import 'package:isd_treeclient/data-structure.dart';

import 'binaryreader.dart';
import 'assets.dart';
import 'core.dart';

Feature parseFeature(int featureCode, BinaryReader reader,
    StarIdentifier systemID, Set<AssetID> notReferenced, DataStructure data) {
  switch (featureCode) {
    case 1:
      return StarFeature(StarIdentifier.parse(reader.readUint32()));
    case 2:
      int id = reader.readUint32();
      assert(id != 0);
      AssetID primaryChild = AssetID(systemID, id);
      notReferenced.remove(primaryChild);
      List<SolarSystemChild> children = [SolarSystemChild(primaryChild, 0, 0)];
      while (true) {
        int id = reader.readUint32();
        if (id == 0) break;
        AssetID child = AssetID(systemID, id);
        notReferenced.remove(child);
        double distanceFromCenter = reader.readFloat64();
        double theta = reader.readFloat64();
        children.add(SolarSystemChild(child, distanceFromCenter, theta));
      }
      return SolarSystemFeature(children);
    case 3:
      int id = reader.readUint32();
      assert(id != 0);
      AssetID primaryChild = AssetID(systemID, id);
      notReferenced.remove(primaryChild);
      List<OrbitChild> children = [];
      while (true) {
        int id = reader.readUint32();
        if (id == 0) break;
        AssetID child = AssetID(systemID, id);
        notReferenced.remove(child);
        double semiMajorAxis = reader.readFloat64();
        double eccentricity = reader.readFloat64();
        double omega = reader.readFloat64();
        Uint64 timeOrigin = reader.readUint64();
        int direction = reader.readUint8();
        if (direction > 0x1) {
          throw UnimplementedError(
            'Unsupported OrbitChild.direction: 0x${direction.toRadixString(16)}',
          );
        }
        children.add(
          OrbitChild(
            child,
            semiMajorAxis,
            eccentricity,
            timeOrigin,
            direction & 0x1 > 0,
            omega,
          ),
        );
      }
      return OrbitFeature(children, primaryChild);
    case 4:
      List<MaterialLineItem> materials = [];
      while (reader.readUint32() != 0) {
        int quantity = reader.readUint32();
        int max = reader.readUint32();
        String componentName = reader.readString();
        String materialDescription = reader.readString();
        int id = reader.readUint32();
        int? materialID = id == 0 ? null : id;
        materials.add(MaterialLineItem(
          componentName == '' ? null : componentName,
          materialID,
          quantity,
          max == 0 ? null : max,
          materialDescription,
        ));
      }
      int hp = reader.readUint32();
      int minHP = reader.readUint32();
      return StructureFeature(
        materials,
        hp,
        minHP == 0 ? null : minHP,
      );
    case 5:
      return SpaceSensorFeature(
        reader.readUint32(),
        reader.readUint32(),
        reader.readUint32(),
        reader.readFloat64(),
      );
    case 6:
      return SpaceSensorStatusFeature(
        AssetID(systemID, reader.readUint32()),
        AssetID(systemID, reader.readUint32()),
        reader.readUint32(),
      );
    case 7:
      return PlanetFeature(
      );
    case 8:
      int isColonyShip = reader.readUint32();
      assert(isColonyShip < 2);
      return PlotControlFeature(
        isColonyShip == 1,
      );
    case 9:
      Map<(double, double), AssetID> regions = {};
      while (true) {
        int id = reader.readUint32();
        if (id == 0) break;
        double x = reader.readFloat64();
        double y = reader.readFloat64();
        AssetID region = AssetID(systemID, id);
        regions[(x,y)] = region;
        notReferenced.remove(region);
      }
      return SurfaceFeature(regions);
    case 10:
      double cellSize = reader.readFloat64();
      int width = reader.readUint32();
      int height = reader.readUint32();
      List<AssetID?> cells = List.filled(width * height, null);
      while (true) {
        int id = reader.readUint32();
        if (id == 0) break;
        int x = reader.readUint32();
        int y = reader.readUint32();
        cells[x + y * width] = AssetID(systemID, id);
        notReferenced.remove(cells[x + y * width]);
      }
      return GridFeature(cells, width, height, cellSize);
    case 11:
      Uint64 population = reader.readUint64();
      double averageHappiness = reader.readFloat64();
      return PopulationFeature(population, averageHappiness);
    case 12:
      List<AssetID> messages = [];
      while (true) {
        int id = reader.readUint32();
        if (id == 0) break;
        AssetID message = AssetID(systemID, id);
        notReferenced.remove(message);
        messages.add(message);
      }
      return MessageBoardFeature(messages);
    case 13:
      StarIdentifier source = StarIdentifier.parse(reader.readUint32());
      Uint64 timestamp = reader.readUint64();
      int flags = reader.readUint8();
      if (flags > 0x1) {
        throw UnimplementedError(
          'Unsupported MessageFeature.isRead: 0x${flags.toRadixString(16)}',
        );
      }
      String body = reader.readString();
      if (!body.contains('\n')) {
        throw UnimplementedError('no newline in message body: $body');
      }
      String subject = body.substring(0, body.indexOf('\n'));
      String from = body.split('\n')[1];
      String text = body.substring(subject.length + from.length + 2);
      return MessageFeature(
        source,
        timestamp,
        flags == 0x1,
        subject,
        from.substring('From: '.length),
        text,
      );
    case 14:
      return RubblePileFeature();
    case 15:
      int id = reader.readUint32();
      assert(id != 0);
      AssetID child = AssetID(systemID, id);
      notReferenced.remove(child);
      return ProxyFeature(child);
    case 16:
      int type = reader.readUint8();
      Map<AssetClassID, AssetClass> classes = {};
      Map<MaterialID, Material> materials = {};
      while (type != 0) {
        switch (type) {
          case 1:
            AssetClassID id = reader.readInt32();
            String icon = reader.readString();
            String name = reader.readString();
            String description = reader.readString();
            classes[id] = AssetClass(id, icon, name, description);
          case 2:
            MaterialID id = reader.readInt32();
            String icon = reader.readString();
            String name = reader.readString();
            String description = reader.readString();
            Uint64 flags = reader.readUint64();
            bool isFluid = flags.lsh & 1 == 1;
            bool isComponent = flags.lsh & 2 == 2;
            bool isPressurized = flags.lsh & 8 == 8;
            if (flags.msh != 0 || flags.lsh & 4 == 4 || flags.lsh > 0xf) {
              throw UnimplementedError('material flags ${flags.displayName}');
            }
            double massPerUnit = reader.readFloat64();
            double massPerCubicMeter = reader.readFloat64();
            materials[id] = Material(icon, name, description, isFluid,
                isComponent, isPressurized, massPerUnit, massPerCubicMeter);
          default:
            throw UnimplementedError('knowledge type $type');
        }
        type = reader.readUint8();
      }
      return KnowledgeFeature(classes, materials);
    case 17:
      String topic = reader.readString();
      return ResearchFeature(topic);
    case 18:
      double rate = reader.readFloat64();
      MiningFeatureMode mode = MiningFeatureMode.values[(reader.readUint8()+1)%256];
      return MiningFeature(rate, mode);
    case 19:
      double pileMass = reader.readFloat64();
      double pileMassFlowRate = reader.readFloat64();
      double capacity = reader.readFloat64();
      List<MaterialID> materials = [];
      while(true) {
        MaterialID material = reader.readInt32();
        if (material == 0) break;
        materials.add(material);
      }
      return OrePileFeature(pileMass, pileMassFlowRate, capacity, materials, data.getTime(systemID, DateTime.timestamp()));
    case 20:
      int flags = reader.readUint8();
      if (flags>1) throw UnimplementedError('unsupported fcRegion flags: $flags');
      return RegionFeature(flags==1);
    default:
      throw UnimplementedError('Unknown featureID $featureCode');
  }
}

const kClientVersion = 20;
