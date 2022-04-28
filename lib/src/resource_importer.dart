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
