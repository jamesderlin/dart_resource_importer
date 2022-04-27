#!/usr/bin/env dart

import 'package:resource_importer/src/resource_importer.dart';

void main(List<String> args) async {
  await processYamlConfiguration();
  print('Done.');
}
