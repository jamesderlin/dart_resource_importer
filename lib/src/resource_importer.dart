import 'dart:convert';
import 'dart:io' as io;

import 'package:basics/date_time_basics.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_style/dart_style.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:logging/logging.dart' as log;
import 'package:yaml/yaml.dart';

import 'import_entries.dart';

/// The name of this package.
const packageName = 'resource_importer';

final _logger = log.Logger.root;

/// The resource importer configuration loaded from a YAML document.
class ResourceImporterConfiguration {
  /// The list of imported resources.
  List<ImportEntry> importEntries;

  /// Path to the `.dart` file to generate with the imported resources.
  String destinationPath;

  /// Checksum for the `resource_importer` YAML configuration.
  Digest checksum;

  /// Constructor.
  ResourceImporterConfiguration({
    required this.importEntries,
    required this.destinationPath,
    required this.checksum,
  });
}

/// Processes the `resource_importer` configuration from the `pubspec.yaml`
/// file.
///
/// This is the main entry point.
///
/// Searches for the `pubspec.yaml` file in the current directory.  If not
/// found, searches successive parent directories until one is found.
Future<void> processYamlConfiguration({
  FileSystem fs = const LocalFileSystem(),
}) async {
  // Search ancestor paths for `pubspec.yaml`.
  var packageRoot = fs.path.current;
  String pubspecPath;
  while (true) {
    pubspecPath = fs.path.join(packageRoot, 'pubspec.yaml');
    if (fs.isFileSync(pubspecPath)) {
      break;
    }

    var parent = fs.path.dirname(packageRoot);
    if (parent == packageRoot) {
      // We reached the root.
      throw Exception(
        'No `pubspec.yaml` file found in the current directory nor in any '
        'ancestor directories.',
      );
    }
    packageRoot = parent;
  }

  fs.currentDirectory = packageRoot;

  var yamlDocuments = loadYamlDocumentsFromFile(fs.file(pubspecPath));

  await Future.wait<void>([
    for (var document in yamlDocuments)
      processYamlDocument(document.contents, fs: fs),
  ]);
}

/// Loads [YamlDocument]s from a [File].
List<YamlDocument> loadYamlDocumentsFromFile(File file) => loadYamlDocuments(
      file.readAsStringSync(),
      sourceUrl: file.uri,
    );

/// Generates a `.dart` file with the imported resources specified by
/// a single YAML document.
Future<void> processYamlDocument(
  YamlNode documentRoot, {
  required FileSystem fs,
}) async {
  var config = loadResourceImporterConfiguration(documentRoot, fs: fs);
  if (config == null) {
    return;
  }

  var destinationFile = fs.file(config.destinationPath);
  if (!destinationFile.existsSync()) {
    destinationFile.parent.createSync(recursive: true);
  } else {
    // See <https://github.com/google/file.dart/issues/193>.
    var heading = await utf8.decoder
        .bind(destinationFile.openRead())
        .transform(const LineSplitter())
        .take(2)
        .toList();

    var allowOverwrite = false;
    if (heading.length >= 2) {
      heading[0] = heading[0].toLowerCase();
      allowOverwrite =
          heading[0].contains('generated') && heading[0].contains(packageName);
    }

    if (!allowOverwrite) {
      throw io.FileSystemException(
        'File "${config.destinationPath}" already exists.  Cowardly refusing '
        'to overwrite it.',
      );
    }

    var needsUpdate = false;
    var existingChecksum =
        RegExp(r'Checksum: (.+)$').firstMatch(heading[1])?.group(1);
    if (existingChecksum != config.checksum.toString()) {
      needsUpdate = true;
    } else {
      // Check if any of the imported files have a modification time later than
      // when we last generated the destination file.
      var lastModifiedTimes = await Future.wait<DateTime>([
        for (var entry in config.importEntries)
          fs.file(entry.path).lastModified(),
        destinationFile.lastModified(),
      ]);

      var lastUpdated = lastModifiedTimes.removeLast();

      lastModifiedTimes.sort();
      needsUpdate = lastModifiedTimes.last >= lastUpdated;
    }

    if (!needsUpdate) {
      _logger.info('${destinationFile.path} is already up-to-date.');
      return;
    }
  }

  var output = generateOutput(config);
  if (output.isEmpty) {
    return;
  }

  try {
    output = DartFormatter().format(output);
  } on FormatterException catch (e) {
    io.stderr.writeln(e);
  }

  destinationFile.writeAsStringSync(output);
  _logger.info('Wrote ${destinationFile.path}.');
}

/// Loads the [ResourceImporterConfiguration] from a single YAML document.
ResourceImporterConfiguration? loadResourceImporterConfiguration(
  YamlNode documentRoot, {
  required FileSystem fs,
}) {
  if (documentRoot is! YamlMap) {
    return null;
  }

  var resourceImporterRoot = documentRoot.nodes[packageName];
  if (resourceImporterRoot == null) {
    return null;
  }

  if (resourceImporterRoot.value == null) {
    throw YamlException(
      '"$packageName" block must not be empty.',
      resourceImporterRoot.span,
    );
  }

  if (resourceImporterRoot is! YamlMap) {
    throw YamlException(
      'Invalid value for "$packageName": ${resourceImporterRoot.value}',
      resourceImporterRoot.span,
    );
  }

  const destinationKey = 'destination';
  var destinationNode = resourceImporterRoot.nodes[destinationKey];
  String destinationPath;
  if (destinationNode == null) {
    destinationPath = 'lib/resources.$packageName.dart';
  } else {
    var value = destinationNode.value;
    if (value is String) {
      destinationPath = value;
    } else {
      throw YamlException(
        'Invalid value for "$destinationKey": $value',
        destinationNode.span,
      );
    }
  }

  destinationPath = fs.path.normalize(destinationPath);

  const resourcesKey = 'resources';
  var resourcesRoot = resourceImporterRoot.nodes[resourcesKey];
  if (resourcesRoot == null) {
    throw YamlException(
      '"$resourcesKey" entry is required.',
      resourceImporterRoot.span,
    );
  }

  if (resourcesRoot.value == null) {
    throw YamlException(
      '"$resourcesKey" block must not be empty.',
      resourcesRoot.span,
    );
  }

  if (resourcesRoot is! YamlMap) {
    throw YamlException(
      'Invalid value for "$resourcesKey": ${resourcesRoot.value}',
      resourcesRoot.span,
    );
  }

  var importEntries = <ImportEntry>[];
  for (var entry in resourcesRoot.nodes.entries) {
    var keyNode = entry.key as YamlNode;
    var key = keyNode.value;
    if (key is! String) {
      throw YamlException('Invalid resource key: $key', keyNode.span);
    }

    var valueNode = entry.value;
    var value = valueNode.value;
    if (value == null) {
      throw YamlException('No value for "$key" entry.', valueNode.span);
    } else if (value is String) {
      importEntries.add(ImportEntry(name: key, fs: fs, path: value));
    } else if (value is! YamlMap) {
      throw YamlException('Invalid value for "$key": $value', valueNode.span);
    } else {
      const pathKey = 'path';
      var pathNode = value.nodes[pathKey];
      if (pathNode == null) {
        throw YamlException('No path specified for "$key".', valueNode.span);
      }

      var path = pathNode.value;
      if (path is! String) {
        throw YamlException(
          'Invalid value for "$pathKey": $path.',
          pathNode.span,
        );
      }

      const typeKey = 'type';
      var typeNode = value.nodes[typeKey];
      String? type;
      if (typeNode != null) {
        var value = typeNode.value;
        if (value is! String) {
          throw YamlException(
            'Invalid value for "$typeKey": $value',
            typeNode.span,
          );
        }
        type = value;
      }

      ImportEntry importEntry;
      try {
        importEntry = ImportEntry(name: key, fs: fs, path: path, type: type);
      } on Exception catch (e) {
        throw YamlException(e.toString(), valueNode.span);
      }

      importEntries.add(importEntry);
    }
  }

  return ResourceImporterConfiguration(
    importEntries: importEntries,
    destinationPath: destinationPath,
    checksum:
        sha1.convert(utf8.encode(resourceImporterRoot.span.text.trimRight())),
  );
}

/// Generates the content for the imported resources specified by
/// [config].
String generateOutput(ResourceImporterConfiguration config) {
  if (config.importEntries.isEmpty) {
    return '';
  }

  var stringBuffer = StringBuffer()
    ..write(
      '// DO NOT EDIT.  This file was generated by $packageName.\n'
      '// Checksum: ${config.checksum}\n'
      '\n',
    );

  const ignoredLints = [
    'always_specify_types',
    'always_use_package_imports',
    'lines_longer_than_80_chars',
    'prefer_single_quotes',
    'public_member_api_docs',
    'require_trailing_commas',
  ];

  for (var lint in ignoredLints) {
    stringBuffer.writeln('// ignore_for_file: $lint');
  }
  stringBuffer.writeln();

  List.of({for (var entry in config.importEntries) ...entry.requiredImports})
    ..sort()
    ..forEach(stringBuffer.writeln);
  stringBuffer.writeln();

  for (var entry in config.importEntries) {
    stringBuffer
      ..writeln(entry.generateCode())
      ..writeln();
  }

  return stringBuffer.toString();
}
