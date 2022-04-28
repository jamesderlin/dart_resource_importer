# resource_importer

Imports resource files as literals in Dart code.

## What?

`resource_importer` probably is best described with an example.  You can add a
`resource_importer` block to your Dart package's `pubspec.yaml` file that
specifies some resource files:

```yaml
resource_importer:
  resources:
    myImage: 'assets/image.png'
    myLicense:
      path: 'LICENSE'
      type: String
```

Running `resource_importer` then will generate a file (by default named
`lib/resources.resource_importer.dart`) that looks like:

```dart
var myImage = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00,
  0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x30,
  // ...
]);

var myLicense =
    "Copyright (C) 2022 James D. Lin\n\nThis software is provided 'as-is', ..."
```

That file then can be `import`ed by other Dart code:

```dart
import 'package:my_package/resources.resource_importer.dart' as resources;

void main() {
  print(resources.myLicense);
}
```

## Why?

Honestly, most people probably shouldn't be using this. **Flutter projects
instead should use proper assets** that are packaged with your application. You
usually don't want large textual representations of binary files in your source
tree, wasting cycles from the Dart compiler and analyzer and possibly wasting
space in your source control system. (You often shouldn't be committing
generated files to source control anyway.)

This is primarily intended for non-Flutter Dart projects where bundling
additional files is inconvenient (e.g. console programs distributed as
standalone executables, tests for Dart for the Web).

## How?

### Configuration syntax

```yaml
resource_importer:
  destination: 'lib/foo.resources.dart'
  # Optional.  The path to the generated `.dart` file.  If not specified,
  # `lib/resources.resource_importer.dart` will be used by default.

  resources:
  # Required.  The list of resources to import.

    resourceName:
    # Required.  The name of the resource.  This will be directly used as the
    # name of the generated Dart variable, so it must be a valid Dart
    # identifier.

      path: 'path/to/file'
      # Required.  The path to the file to import.  Relative paths are treated
      # as relative to the package's root directory (i.e., the directory
      # containing the `pubspec.yaml` file).

      type: Uint8List
      # Optional.  The type of the resource.  Corresponds to the type of the
      # generated variable.  Allowed types are:
      #
      # * `Uint8List`
      #     The default if no type is specified.  Imports the specified file
      #     as raw bytes stored in a `Uint8List`.
      #
      # * `String`
      #     Assumes that the specified file is a UTF-8-encoded text file and
      #     imports it as a `String` literal.
      #
      # * `List<String>`
      #     Like `String` except that the imported file is split into separate
      #     lines.
      #
      # * `Base64Data`
      #     Imports a binary file as a base64-encoded `String` literal.
      #
      # * `GzippedData`
      #     Like `Uint8List` but compressed with gzip.

    binaryResourceName: 'path/to/file'
    # A shorthand syntax is also provided for `Uint8List` types.
```

### Usage

1. Modify your `pubspec.yaml` to add:

    ```yaml
    dev_dependencies:
      resource_importer: ^0.1.0
    ```

2. Run `dart run resource_importer` from within your package to process the
   `resource_importer` configuration in your `pubspec.yaml` and to perform
   code generation.  Currently this is expected to be done manually and will
   not be performed automatically.

The [`Base64Data`] and [`GzippedData`] types are custom classes provided by
`resource_importer`.  If you use them, you must use a regular dependency:

  ```yaml
  dependencies:
    resource_importer: ^0.1.0
  ```

And then use [`Base64Data.data()`] or [`GzippedData.data()`] respectively to
access their decoded bytes as `Uint8List`s. Note that `GzippedData` depends on
`dart:io` and therefore cannot be used for Dart for the Web.

[`Base64Data`]: https://pub.dev/packages/resource_importer/latest/base64_data/Base64Data-class.html
[`GzippedData`]: https://pub.dev/packages/resource_importer/latest/gzipped_data/GzippedData-class.html
[`Base64Data.data()`]: https://pub.dev/packages/resource_importer/latest/base64_data/Base64Data/data.html
[`GzippedData.data()`]: https://pub.dev/packages/resource_importer/latest/gzipped_data/GzippedData/data.html
