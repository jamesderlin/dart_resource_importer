#!/usr/bin/env dart

import 'dart:io' as io;

import 'package:resource_importer/src/resource_importer.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  try {
    await processYamlConfiguration();
    print('Done.');
  } on YamlException catch (e) {
    io.stderr.writeln(e);
    io.exitCode = 1;
  } on io.FileSystemException catch (e) {
    io.stderr.writeln(e);
    io.exitCode = 1;
  }
}
