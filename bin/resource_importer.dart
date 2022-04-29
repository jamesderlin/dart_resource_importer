#!/usr/bin/env dart

import 'dart:io' as io;

import 'package:logging/logging.dart' as log;
import 'package:resource_importer/src/resource_importer.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  log.Logger.root.level = log.Level.INFO;
  log.Logger.root.onRecord.listen((record) {
    if (record.level > log.Level.INFO) {
      io.stderr.writeln('$packageName: $record');
    } else {
      print(record.message);
    }
  });

  try {
    await processYamlConfiguration();
    log.Logger.root.info('Done.');
  } on YamlException catch (e) {
    log.Logger.root.severe(e);
    io.exitCode = 1;
  } on io.FileSystemException catch (e) {
    log.Logger.root.severe(e);
    io.exitCode = 1;
  }
}
