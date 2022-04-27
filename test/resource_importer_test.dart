import 'dart:convert';

import 'package:dart_style/dart_style.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:resource_importer/src/resource_importer.dart';
import 'package:test/test.dart';

import 'expected/test.resources.dart' as resources;
import 'test_common.dart';

void main() {
  const packageRootPath = r'D:\src\package';

  var fs = setUpMemoryFileSystem(packageRootPath, FileSystemStyle.windows);

  setUp(() {
    fs.currentDirectory = packageRootPath;
  });

  test('Generated output matches expected output', () async {
    await processYamlConfiguration(fs: fs);

    var destinationPath = destinationPathPosix.toWindows();

    var generatedFile = fs.file(destinationPath);
    expect(generatedFile.existsSync(), true);

    // Output should be already formatted.
    var contents = generatedFile.readAsStringSync();
    var formatter = DartFormatter();
    expect(contents, formatter.format(contents));

    const localFs = LocalFileSystem();
    var testPath = getTestPath();
    var expectedContents = localFs
        .file(localFs.path.join(testPath, 'expected', 'test.resources.dart'))
        .readAsStringSync();
    expect(contents, formatter.format(expectedContents));
  });

  test('Generated output is correct', () {
    expect(resources.stringResource, multilineString);
    expect(resources.stringListResource, LineSplitter.split(multilineString));
    expect(resources.binaryResource, binaryData);
    expect(resources.shorthandBinaryResource, binaryData);
    expect(resources.base64Resource.data(), binaryData);
    expect(resources.gzippedResource.data(), binaryData);
  });

  // TODO: Test failure messages.
}
