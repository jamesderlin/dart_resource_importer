import 'dart:convert';
import 'dart:io' as io;

import 'package:dart_style/dart_style.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:yaml/yaml.dart';

import 'import_entries.dart';

/// The name of this package.
const packageName = 'resource_importer';

/// The resource importer configuration loaded from a YAML document.
class ResourceImporterConfiguration {
  /// The list of imported resources.
  List<ImportEntry> importEntries;

  /// Path to the `.dart` file to generate with the imported resources.
  String destinationPath;

  /// Constructor.
  ResourceImporterConfiguration({
    required this.importEntries,
    required this.destinationPath,
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

  if (config.importEntries.isEmpty) {
    return;
  }

  var output = generateOutput(config.importEntries);

  try {
    output = DartFormatter().format(output);
  } on FormatterException catch (e) {
    io.stderr.writeln(e);
  }

  var destinationFile = fs.file(config.destinationPath);
  if (!destinationFile.existsSync()) {
    destinationFile.parent.createSync(recursive: true);
  } else {
    var firstLine = await destinationFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    firstLine = firstLine.toLowerCase();
    if (firstLine.contains('generated') && firstLine.contains(packageName)) {
      // Safe to overwrite.
    } else {
      throw ArgumentError(
        'File "${config.destinationPath}" already exists.  Cowardly refusing '
        'to overwrite it.',
      );
    }
  }

  destinationFile.writeAsStringSync(output);
}

/// Loads the [ResourceImporterConfiguration] from a single YAML document.
ResourceImporterConfiguration? loadResourceImporterConfiguration(
  YamlNode documentRoot, {
  required FileSystem fs,
}) {
  if (documentRoot is! YamlMap) {
    return null;
  }

  var resourceImporterRoot = documentRoot[packageName];
  if (resourceImporterRoot == null) {
    return null;
  }

  if (resourceImporterRoot is! YamlMap) {
    throw FormatException(
      'Invalid value for "$packageName": $resourceImporterRoot',
    );
  }

  const destinationKey = 'destination';
  var destinationPath =
      resourceImporterRoot[destinationKey] ?? 'lib/resources.$packageName.dart';
  if (destinationPath is! String) {
    throw FormatException(
      'Invalid value for "$destinationKey": $destinationPath}',
    );
  }

  destinationPath = fs.path.normalize(destinationPath);

  const resourcesKey = 'resources';
  var resourcesRoot = resourceImporterRoot[resourcesKey];
  if (resourcesRoot == null) {
    throw const FormatException('No "$resourcesKey" entry found.');
  }
  if (resourcesRoot is! YamlMap) {
    throw FormatException(
      'Invalid value for "$resourcesKey": $resourcesRoot',
    );
  }

  var importEntries = <ImportEntry>[];
  for (var entry in resourcesRoot.entries) {
    var key = entry.key;
    if (key is! String) {
      throw FormatException('Invalid resource key: $key');
    }

    var value = entry.value;
    if (value is String) {
      importEntries.add(ImportEntry(name: key, fs: fs, path: value));
    } else if (value is YamlMap) {
      const pathKey = 'path';
      var path = value[pathKey];
      if (path == null) {
        throw FormatException('No path specified for "$key".');
      } else if (path is! String) {
        throw FormatException('Invalid value for "$pathKey": $path');
      }

      const typeKey = 'type';
      var type = value[typeKey];
      if (type is! String?) {
        throw FormatException('Invalid value for "$typeKey": $type');
      }

      importEntries.add(ImportEntry(name: key, fs: fs, path: path, type: type));
    } else {
      throw FormatException('Invalid value for "$key": $value');
    }
  }

  return ResourceImporterConfiguration(
    importEntries: importEntries,
    destinationPath: destinationPath,
  );
}

/// Generates the content for the imported resources specified by
/// [importEntries].
///
/// [importEntries] must not be empty.
String generateOutput(List<ImportEntry> importEntries) {
  assert(importEntries.isNotEmpty);

  var stringBuffer = StringBuffer()
    ..writeln('// DO NOT EDIT.  This file was generated by $packageName.');
  const ignoredLints = [
    'always_specify_types',
    'always_use_package_imports',
    'lines_longer_than_80_chars',
    'prefer_single_quotes',
    'public_member_api_docs',
    'require_trailing_commas',
  ];
  stringBuffer.writeln();
  for (var lint in ignoredLints) {
    stringBuffer.writeln('// ignore_for_file: $lint');
  }
  stringBuffer.writeln();

  List.of({for (var entry in importEntries) ...entry.requiredImports})
    ..sort()
    ..forEach(stringBuffer.writeln);
  stringBuffer.writeln();

  for (var entry in importEntries) {
    stringBuffer
      ..writeln(entry.generateCode())
      ..writeln();
  }

  return stringBuffer.toString();
}
