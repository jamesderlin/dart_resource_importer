import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dartbag/debug.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';

final defaultModificationTime = DateTime.utc(2022, 1, 1);

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
    'The five boxing wizards jump quickly.\n'
    '\n'
    '"Hello!" he said.\n'
    '"Where\'s the \$amount you owe me?" she asked.\n';

final binaryData = Uint8List.fromList([
  for (var i = 0; i < 512; i += 1) i,
]);

/// Creates and return a [MemoryFileSystem] with default contents.
MemoryFileSystem setUpMemoryFileSystem({
  required String yaml,
  required String packageRootPath,
  required FileSystemStyle style,
}) {
  var memoryFs = MemoryFileSystem(style: style)
    ..addFile(
      '$packageRootPath/pubspec.yaml',
      content: yaml,
      lastModified: defaultModificationTime,
    )
    ..copyFile(
      source: getTestFile(binaryFilePathPosix),
      destinationPosix: '$packageRootPath/$binaryFilePathPosix',
      lastModified: defaultModificationTime,
    )
    ..copyFile(
      source: getTestFile(multilineTextFilePathPosix),
      destinationPosix: '$packageRootPath/$multilineTextFilePathPosix',
      lastModified: defaultModificationTime,
    )
    ..currentDirectory = packageRootPath;
  return memoryFs;
}

extension AddMemoryFile on MemoryFileSystem {
  /// Adds a [File] with the specified path and contents.
  ///
  /// Automatically creates all ancestor directories if necessary.
  ///
  /// [content] must be either a [Uint8List] or a [String].
  void addFile(
    String pathPosix, {
    required Object content,
    DateTime? lastModified,
  }) {
    var path =
        (style == FileSystemStyle.windows) ? pathPosix.toWindows() : pathPosix;

    var file = this.file(path)..parent.createSync(recursive: true);
    if (content is String) {
      file.writeAsStringSync(content);
    } else if (content is Uint8List) {
      file.writeAsBytesSync(content);
    } else {
      throw ArgumentError(
        'addMemoryFile: Unsupported content type: ${content.runtimeType}',
      );
    }

    if (lastModified != null) {
      file.setLastModifiedSync(lastModified);
    }
  }

  /// Copies a file from the local file system to the [MemoryFileSystem].
  ///
  /// Automatically creates all ancestor directories if necessary.
  void copyFile({
    required File source,
    required String destinationPosix,
    DateTime? lastModified,
  }) {
    var destination = (style == FileSystemStyle.windows)
        ? destinationPosix.toWindows()
        : destinationPosix;

    var content = source.readAsBytesSync();
    var file = this.file(destination)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(content, flush: true);
    if (lastModified != null) {
      file.setLastModifiedSync(lastModified);
    }
  }
}

/// Returns the absolute path to the `test` directory.
///
/// Note that [io.Platform.script] does not work in tests and also will not
/// work for `import`ed files.
String getTestPath() =>
    const LocalFileSystem().path.dirname(currentDartFilePath());

/// Returns the [File] for the specified path within  the `test` directory.
File getTestFile(String pathPosix) {
  const localFs = LocalFileSystem();
  return localFs.file(
    localFs.path.join(
      getTestPath(),
      io.Platform.isWindows ? pathPosix.toWindows() : pathPosix,
    ),
  );
}

extension WindowsPath on String {
  String toWindows() => replaceAll('/', r'\');
}
