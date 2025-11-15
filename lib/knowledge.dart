import 'package:flutter/material.dart' hide Material;

import 'assets.dart';
import 'ui-core.dart';

class MaterialDialog extends StatelessWidget {
  const MaterialDialog({
    super.key,
    required this.material,
  });

  final Material material;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ISDIcon(icon: material.icon, width: 32, height: 32),
              Text(material.name, style: TextStyle(fontSize: 20))
            ],
          ),
          Text(material.description),
          Text(material.isFluid ? 'A fluid.' : 'A solid.'),
          if (material.isPressurized) Text('Pressurized.'),
          Text(
              'Density: ${material.massPerCubicMeter} kilograms per cubic meter.')
        ],
      ),
    );
  }
}

class AssetClassDialog extends StatelessWidget {
  const AssetClassDialog({super.key, required this.assetClass});
  final AssetClass assetClass;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ISDIcon(icon: assetClass.icon, width: 32, height: 32),
              Text(assetClass.name, style: TextStyle(fontSize: 20))
            ],
          ),
          Text(assetClass.description),
        ],
      ),
    );
  }
}
