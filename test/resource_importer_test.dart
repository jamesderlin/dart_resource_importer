import 'dart:convert';
import 'dart:io' as io;

import 'package:dart_style/dart_style.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:logging/logging.dart' as log;
import 'package:resource_importer/src/resource_importer.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'expected/test.resources.dart' as resources;
import 'test_common.dart';

void main() {
  const packageRootPath = r'D:\src\package';

  // Set to `log.Level.ALL` to see output from expected failures.
  log.Logger.root.level = log.Level.WARNING;
  log.Logger.root.onRecord.listen(print);

  test('Generated output matches expected output', () async {
    var fs = setUpMemoryFileSystem(
      yaml: allYaml,
      packageRootPath: packageRootPath,
      style: FileSystemStyle.windows,
    );

    var destinationPath = destinationPathPosix.toWindows();
    var generatedFile = fs.file(destinationPath);

    expect(generatedFile.existsSync(), false);
    expect(generatedFile.parent.existsSync(), false);

    await processYamlConfiguration(fs: fs);

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
    expect(resources.shorterBinaryResource, binaryData);
    expect(resources.shortestBinaryResource, binaryData);
    expect(resources.base64Resource.data(), binaryData);
    expect(resources.gzippedResource.data(), binaryData);
  });

  group('Unusual YAML configurations', () {
    test('No `resource_importer` block', () async {
      var fs = setUpMemoryFileSystem(
        yaml: '\n',
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );
      await expectLater(processYamlConfiguration(fs: fs), completes);
    });

    test('Empty `resource_importer` block', () async {
      const emptyTopLevelYaml = 'resource_importer:\n';
      var fs = setUpMemoryFileSystem(
        yaml: emptyTopLevelYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );
      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(InstanceWithSubstrings<YamlException>([packageName, 'empty'])),
      );
    });

    test('No explicit destination path', () async {
      const emptyDestinationYaml = //
          'resource_importer:\n'
          '  resources:\n'
          '    stringResource:\n'
          "      path: '$multilineTextFilePathPosix'\n"
          '      type: String\n';
      var fs = setUpMemoryFileSystem(
        yaml: emptyDestinationYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );
      await expectLater(processYamlConfiguration(fs: fs), completes);

      expect(fs.isFileSync('/lib/resources.$packageName.dart'), true);
    });

    test('Missing `resources` block', () async {
      const emptyResourceListYaml = //
          'resource_importer:\n'
          '  destination: test.resources.dart\n';
      var fs = setUpMemoryFileSystem(
        yaml: emptyResourceListYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );
      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<YamlException>(['resources', 'required']),
        ),
      );
    });

    test('Empty `resources` block', () async {
      const emptyResourceListYaml = //
          'resource_importer:\n'
          '  resources:\n';
      var fs = setUpMemoryFileSystem(
        yaml: emptyResourceListYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );
      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<YamlException>(['resources', 'empty']),
        ),
      );
    });

    test('Invalid `resource_importer` value', () async {
      const invalidTopLevelYaml = 'resource_importer: 123\n';

      var fs = setUpMemoryFileSystem(
        yaml: invalidTopLevelYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );
      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<YamlException>(['Invalid value', '123']),
        ),
      );
    });

    test('Invalid `resources` value', () async {
      const invalidResourcesYaml = //
          'resource_importer:\n'
          '  resources: 123\n';

      var fs = setUpMemoryFileSystem(
        yaml: invalidResourcesYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );
      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<YamlException>(['Invalid value', '123']),
        ),
      );
    });

    test('Duplicate resources', () async {
      const duplicateResourceYaml = //
          'resource_importer:\n'
          '  resources:\n'
          "    someDuplicateResource: '$multilineTextFilePathPosix'\n"
          "    someDuplicateResource: '$multilineTextFilePathPosix'\n";

      var fs = setUpMemoryFileSystem(
        yaml: duplicateResourceYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );

      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<YamlException>(['someDuplicateResource']),
        ),
      );
    });

    test('Empty resource', () async {
      const emptyResourceYaml = //
          'resource_importer:\n'
          '  resources:\n'
          '    someEmptyResource:\n';

      var fs = setUpMemoryFileSystem(
        yaml: emptyResourceYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );

      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<YamlException>(
            ['No value', 'someEmptyResource'],
          ),
        ),
      );
    });

    test('Missing path for resource', () async {
      const missingPathYaml = //
          'resource_importer:\n'
          '  resources:\n'
          '    someMissingPath:\n'
          '      type: String\n';
      var fs = setUpMemoryFileSystem(
        yaml: missingPathYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );

      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<YamlException>(['No path', 'someMissingPath']),
        ),
      );
    });

    test('Empty path for resource', () async {
      const emptyPathYaml = //
          'resource_importer:\n'
          '  resources:\n'
          '    someMissingPath:\n'
          '      path:\n';
      var fs = setUpMemoryFileSystem(
        yaml: emptyPathYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );

      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<YamlException>(['Invalid value', 'path']),
        ),
      );
    });

    test('Non-existent file for resource', () async {
      const nonExistentResourceYaml = //
          'resource_importer:\n'
          '  resources:\n'
          "    nonExistentResource: 'nonExistentPath/file'\n";

      var fs = setUpMemoryFileSystem(
        yaml: nonExistentResourceYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );

      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<io.FileSystemException>(['nonExistentPath']),
        ),
      );
    });

    test('Invalid resource type', () async {
      const invalidTypeYaml = //
          'resource_importer:\n'
          '  resources:\n'
          '    unsupported:\n'
          "      path: '$multilineTextFilePathPosix'\n"
          '      type: someInvalidType\n';

      var fs = setUpMemoryFileSystem(
        yaml: invalidTypeYaml,
        packageRootPath: '/',
        style: FileSystemStyle.posix,
      );

      await expectLater(
        processYamlConfiguration(fs: fs),
        throwsA(
          InstanceWithSubstrings<YamlException>(['someInvalidType']),
        ),
      );
    });
  });
}

/// A [Matcher] that checks if the matched object is of a specified type and
/// includes the specified substring in its [Object.toString] representation.
class InstanceWithSubstrings<T> extends CustomMatcher {
  final List<String> _substrings;

  InstanceWithSubstrings(this._substrings)
      : super('a $T that contains all substrings', '', _substrings);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    log.Logger.root.info(() => 'Logged exception: $item');
    if (item is! T) {
      matchState[null] = 'is not a $T.';
      return false;
    }

    for (var substring in _substrings) {
      if (!item.toString().contains(substring)) {
        matchState[null] = 'does not contain "$substring".';
        return false;
      }
    }
    return true;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) =>
      StringDescription(matchState[null] as String);
}
