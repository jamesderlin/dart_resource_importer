import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/local.dart';

import 'resource_importer.dart';
import 'utils.dart';

/// String tokens representing each of the supported resource types.
const _tokenUint8List = 'Uint8List';
const _tokenBase64Data = 'Base64Data';
const _tokenGzippedData = 'GzippedData';
const _tokenString = 'String';
const _tokenStringList = 'List<String>';

/// Abstract base class for imported resources.
abstract class ImportEntry {
  /// The variable name to use for the imported resource.
  late final String name;

  /// The string token for the resource type.
  late final String type;

  /// The path to the resource file.
  ///
  /// [path] might be relative to the YAML configuration file.
  String get path => _file.path;

  /// The resource file.
  late final File _file;

  /// Constructor that returns an appropriate subtype for [type].
  factory ImportEntry({
    required String name,
    required String path,
    String? type,
    FileSystem fs = const LocalFileSystem(),
  }) {
    var file = fs.file(fs.path.normalize(path));

    type ??= _tokenUint8List;

    ImportEntry entry;
    switch (type) {
      case _tokenUint8List:
        entry = Uint8ListImportEntry._();
        break;
      case _tokenBase64Data:
        entry = Base64DataImportEntry._();
        break;
      case _tokenGzippedData:
        entry = GzippedDataImportEntry._();
        break;
      case _tokenString:
        entry = StringImportEntry._();
        break;
      case _tokenStringList:
        entry = StringListImportEntry._();
        break;
      default:
        throw FormatException('Unrecognized type: $type');
    }
    return entry
      ..name = name
      ..type = type
      .._file = file;
  }

  ImportEntry._();

  @override
  String toString() => '$type: $name = "$path"';

  /// Any necessary Dart `import` statements that might be needed for the code
  /// generated by [generateCode].
  List<String> get requiredImports => const [];

  /// Generates code to declare a variable named [name] and that stores the
  /// contents of the file from [path].
  String generateCode();
}

/// Represents a resource imported as a [Uint8List].
class Uint8ListImportEntry extends ImportEntry {
  Uint8ListImportEntry._() : super._();

  @override
  List<String> get requiredImports => const ["import 'dart:typed_data';"];

  @override
  String generateCode() {
    var data = _file.readAsBytesSync();
    var stringBuffer = StringBuffer()
      ..write('final $name = Uint8List.fromList(const [')
      ..writeln('// Do not format.');
    var count = 0;
    for (var byte in data) {
      var hex = byte.toRadixString(16).toUpperCase().padLeft(2, '0');
      stringBuffer.write('0x$hex, ');
      count += 1;
      if (count % 10 == 0) {
        stringBuffer.write('\n');
      }
    }
    stringBuffer.writeln(']);');
    return stringBuffer.toString();
  }
}

/// Represents a resource imported as a base64-encoded [String] literal.
class Base64DataImportEntry extends ImportEntry {
  Base64DataImportEntry._() : super._();

  @override
  List<String> get requiredImports =>
      const ["import 'package:$packageName/base64_data.dart';"];

  @override
  String generateCode() {
    var data = _file.readAsBytesSync();
    return 'const $name = Base64Data("${base64.encode(data)}");';
  }
}

/// Represents a resource imported as a gzip-compressed [Uint8List].
class GzippedDataImportEntry extends ImportEntry {
  GzippedDataImportEntry._() : super._();

  @override
  List<String> get requiredImports =>
      const ["import 'package:$packageName/gzipped_data.dart';"];

  @override
  String generateCode() {
    var data = _file.readAsBytesSync();
    var stringBuffer = StringBuffer()
      ..write('const $name = GzippedData([')
      ..writeln('// Do not format.');
    var count = 0;
    for (var byte in io.gzip.encode(data)) {
      var hex = byte.toRadixString(16).toUpperCase().padLeft(2, '0');
      stringBuffer.write('0x$hex, ');
      count += 1;
      if (count % 10 == 0) {
        stringBuffer.write('\n');
      }
    }
    stringBuffer.writeln(']);');
    return stringBuffer.toString();
  }
}

/// Represents a resource imported as a [String] literal.]
class StringImportEntry extends ImportEntry {
  StringImportEntry._() : super._();

  @override
  String generateCode() {
    var randomAccessFile = _file.openSync();
    Uint8List bom;
    try {
      bom = randomAccessFile.readSync(3);
    } finally {
      randomAccessFile.closeSync();
    }

    const utf8Bom = [0xEF, 0xBB, 0xBF];
    const utf16LeBom = [0xFF, 0xFE];
    const utf16BeBom = [0xFE, 0xFF];

    if (bom.startsWith(utf8Bom)) {
      // [File.readAsString] seems to ignore a UTF-8 BOM if present, so we
      // don't need to do anything extra.
    } else if (bom.startsWith(utf16LeBom)) {
      throw const FormatException('Unsupported encoding: UTF-16LE');
    } else if (bom.startsWith(utf16BeBom)) {
      throw const FormatException('Unsupported encoding: UTF-16BE');
    }

    var data = _file.readAsStringSync();
    return 'const $name = "${escapeString(data)}";';
  }
}

/// Represents a resource imported as a [List] of [String] literals where
/// each literal represents a single line of text.
class StringListImportEntry extends ImportEntry {
  StringListImportEntry._() : super._();

  @override
  String generateCode() {
    var randomAccessFile = _file.openSync();
    Uint8List bom;
    try {
      bom = randomAccessFile.readSync(3);
    } finally {
      randomAccessFile.closeSync();
    }

    const utf8Bom = [0xEF, 0xBB, 0xBF];
    const utf16LeBom = [0xFF, 0xFE];
    const utf16BeBom = [0xFE, 0xFF];

    if (bom.startsWith(utf8Bom)) {
      // [File.readAsString] seems to ignore a UTF-8 BOM if present, so we
      // don't need to do anything extra.
    } else if (bom.startsWith(utf16LeBom)) {
      throw const FormatException('Unsupported encoding: UTF-16LE');
    } else if (bom.startsWith(utf16BeBom)) {
      throw const FormatException('Unsupported encoding: UTF-16BE');
    }

    var data = _file.readAsStringSync();
    var lines = LineSplitter.split(data);

    var stringBuffer = StringBuffer()..write('const $name = [');
    for (var line in lines) {
      stringBuffer.write('"${escapeString(line)}", ');
    }
    stringBuffer.write('];');
    return stringBuffer.toString();
  }
}
