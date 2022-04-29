import 'dart:convert';
import 'dart:typed_data';

import 'package:file/local.dart';
import 'package:file/memory.dart';

const binaryFilePathPosix = 'assets/data.bin';
const multilineTextFilePathPosix = 'assets/utf8_multiline.txt';
const destinationPathPosix = 'lib/app.resources.dart';

const allYaml = '''
resource_importer:
  destination: '$destinationPathPosix'

  resources:
    stringResource:
      path: '$multilineTextFilePathPosix'
      type: String

    stringListResource:
      path: '$multilineTextFilePathPosix'
      type: List<String>

    binaryResource:
      path: '$binaryFilePathPosix'
      type: Uint8List

    shorterBinaryResource:
      path: '$binaryFilePathPosix'

    shortestBinaryResource: '$binaryFilePathPosix'

    base64Resource:
      path: '$binaryFilePathPosix'
      type: Base64Data

    gzippedResource:
      path: '$binaryFilePathPosix'
      type: GzippedData
''';

const multilineString = //
    'The quick brown fox jumps over the lazy dog.\n'
    'Pack my box with five dozen liquor jugs.\n'
    'Jackdaws love my big sphinx of quartz.\n'
    'The five boxing wizards jump quickly.\n';
final binaryData = Uint8List.fromList([
  for (var i = 0; i < 512; i += 1) i,
]);

/// Creates and return a [MemoryFileSystem] with default contents.
MemoryFileSystem setUpMemoryFileSystem({
  required String yaml,
  required String packageRootPath,
  required FileSystemStyle style,
}) {
  var fs = MemoryFileSystem(style: style);

  var binaryFilePath = binaryFilePathPosix;
  var multilineTextFilePath = multilineTextFilePathPosix;
  if (style == FileSystemStyle.windows) {
    binaryFilePath = binaryFilePath.toWindows();
    multilineTextFilePath = multilineTextFilePathPosix.toWindows();
  }

  fs
    ..addFile('$packageRootPath/pubspec.yaml', content: yaml)
    ..addFile('$packageRootPath/$binaryFilePath', content: binaryData)
    ..addFile(
      '$packageRootPath/$multilineTextFilePath',
      content: multilineString,
    )
    ..currentDirectory = packageRootPath;
  return fs;
}

extension AddMemoryFile on MemoryFileSystem {
  /// Adds a [File] with the specified path and contents.
  ///
  /// Automatically creates all ancesetor directories if necessary.
  ///
  /// [content] must be either a [Uint8List] or a [String].
  void addFile(
    String pathPosix, {
    required Object content,
  }) {
    var path =
        (style == FileSystemStyle.windows) ? pathPosix.toWindows() : pathPosix;

    var file = this.file(path)..parent.createSync(recursive: true);
    if (content is String) {
      file.writeAsStringSync(content);
    } else if (content is Uint8List) {
      file.writeAsBytes(content);
    } else {
      throw ArgumentError(
        'addMemoryFile: Unsupported content type: ${content.runtimeType}',
      );
    }
  }
}

/// Returns the absolute path to the `test` directory.
///
/// Note that [io.Platform.script] does not work in tests and also will not
/// work for `import`ed files.
String getTestPath() {
  var filePathRegExp = RegExp(r'(file://.+\.dart)');
  var stackLineIterator = LineSplitter.split(StackTrace.current.toString());
  var match = filePathRegExp.firstMatch(stackLineIterator.first);
  if (match == null) {
    throw StateError('Failed to determine path to the `test` directory.');
  }

  var scriptPath = Uri.parse(match.group(1)!).toFilePath();
  return const LocalFileSystem().path.dirname(scriptPath);
}

extension WindowsPath on String {
  String toWindows() => replaceAll('/', r'\');
}
