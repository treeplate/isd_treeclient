import 'data-structure.dart';
import 'binaryreader.dart';
import 'assets.dart';
import 'core.dart';

Feature parseFeature(
  int featureCode,
  BinaryReader reader,
  StarIdentifier systemID,
  Set<AssetID> notReferenced,
  DataStructure data,
) {
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
      int max = reader.readUint32();
      while (max != 0) {
        String componentName = reader.readString();
        String materialDescription = reader.readString();
        int id = reader.readUint32();
        int? materialID = id == 0 ? null : id;
        materials.add(MaterialLineItem(
          componentName == '' ? null : componentName,
          materialID,
          max,
          materialDescription,
        ));
        max = reader.readUint32();
      }
      int quantity = reader.readUint32();
      double quantityFlowRate = reader.readFloat64();
      int hp = reader.readUint32();
      double hpFlowRate = reader.readFloat64();
      int minHP = reader.readUint32();
      return StructureFeature(
        materials,
        quantity,
        quantityFlowRate,
        hp,
        hpFlowRate,
        minHP == 0 ? null : minHP,
        data.getTime(systemID, DateTime.timestamp()),
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
      return PlanetFeature(reader.readUint32());
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
        regions[(x, y)] = region;
        notReferenced.remove(region);
      }
      return SurfaceFeature(regions);
    case 0xa:
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
    case 0xb:
      Uint64 population = reader.readUint64();
      double averageHappiness = reader.readFloat64();
      return PopulationFeature(population, averageHappiness);
    case 0xc:
      List<AssetID> messages = [];
      while (true) {
        int id = reader.readUint32();
        if (id == 0) break;
        AssetID message = AssetID(systemID, id);
        notReferenced.remove(message);
        messages.add(message);
      }
      return MessageBoardFeature(messages);
    case 0xd:
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
    case 0xe:
      int id = reader.readUint32();
      Map<MaterialID, Uint64> materials = {};
      while(id != 0) {
        materials[id] = reader.readUint64();
        id = reader.readInt32();
      }
      return RubblePileFeature(materials, reader.readUint64());
    case 0xf:
      int id = reader.readUint32();
      assert(id != 0);
      AssetID child = AssetID(systemID, id);
      notReferenced.remove(child);
      return ProxyFeature(child);
    case 0x10:
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
    case 0x11:
      String topic = reader.readString();
      return ResearchFeature(topic);
    case 0x12:
      double maxRate = reader.readFloat64();
      DisabledReasoning disabledReasoning = DisabledReasoning(reader.readUint32());
      int flags = reader.readUint8();
      double currentRate = reader.readFloat64();
      // TODO: check constraints for these flags
      return MiningFeature(
        maxRate,
        disabledReasoning,
        flags & 0x1 == 1,
        flags & 0x2 == 2,
        currentRate,
      );
    case 0x13:
      double pileMass = reader.readFloat64();
      double pileMassFlowRate = reader.readFloat64();
      double capacity = reader.readFloat64();
      Set<MaterialID> materials = {};
      while (true) {
        MaterialID material = reader.readInt32();
        if (material == 0) break;
        materials.add(material);
      }
      return OrePileFeature(
        pileMass,
        pileMassFlowRate,
        capacity,
        materials,
        data.getTime(systemID, DateTime.timestamp()),
      );
    case 0x14:
      int flags = reader.readUint8();
      if (flags > 1)
        throw UnimplementedError('unsupported fcRegion flags: $flags');
      return RegionFeature(flags == 1);
    case 0x15:
      MaterialID? ore = reader.readInt32();
      if (ore == 0) ore = null;
      double maxRate = reader.readFloat64();
      DisabledReasoning disabledReasoning = DisabledReasoning(reader.readUint32());
      int flags = reader.readUint8();
      double currentRate = reader.readFloat64();
      // TODO: check constraints for these flags
      return RefiningFeature(
        ore,
        maxRate,
        disabledReasoning,
        flags & 0x1 == 1,
        flags & 0x2 == 2,
        currentRate,
      );
    case 0x16:
      double pileMass = reader.readFloat64();
      double pileMassFlowRate = reader.readFloat64();
      double capacity = reader.readFloat64();
      String materialName = reader.readString();
      MaterialID? material = reader.readInt32();
      if (material == 0) material = null;
      return MaterialPileFeature(
        pileMass,
        pileMassFlowRate,
        capacity,
        materialName,
        material,
        data.getTime(systemID, DateTime.timestamp()),
      );
    case 0x17:
      Uint64 pileQuantity = reader.readUint64();
      double pileQuantityFlowRate = reader.readFloat64();
      Uint64 capacity = reader.readUint64();
      String materialName = reader.readString();
      MaterialID? material = reader.readInt32();
      if (material == 0) material = null;
      return MaterialStackFeature(
        pileQuantity,
        pileQuantityFlowRate,
        capacity,
        materialName,
        material,
        data.getTime(systemID, DateTime.timestamp()),
      );
    case 0x18:
      return GridSensorFeature();
    case 0x19:
      int? grid = reader.readUint32();
      return GridSensorStatusFeature(
        grid == 0 ? null : AssetID(systemID, grid),
        reader.readUint32(),
      );
    case 0x1A:
      int capacity = reader.readUint32();
      double rate = reader.readFloat64();
      DisabledReasoning disabledReasoning = DisabledReasoning(reader.readUint32());
      Set<AssetID> structures = {};
      int rawStructureID = reader.readUint32();
      while(rawStructureID != 0) {
        structures.add(AssetID(systemID, rawStructureID));
        rawStructureID = reader.readUint32();
      }
      return BuilderFeature(capacity, rate, disabledReasoning, structures);
    case 0x1B:
      return InternalSensorFeature();
    case 0x1C:
      int count = reader.readUint32();
      return InternalSensorStatusFeature(count);
    case 0x1D:
      bool enabled = reader.readUint8() == 1;
      return OnOffFeature(enabled);
    default:
      throw UnimplementedError('Unknown featureID $featureCode');
  }
}

const kClientVersion = 0x1D;
