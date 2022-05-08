# resource_importer

Imports resource files as string or binary literals in Dart code.

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
generated files to source control, though.)

This is primarily intended for non-Flutter Dart projects where bundling
additional files can be inconvenient (e.g. console programs distributed as
standalone executables, tests for Dart for the Web).

## How?

### Configuration syntax

See [the example].

### Usage

1. Modify your `pubspec.yaml` file to add:

    ```yaml
    dev_dependencies:
      resource_importer: ^0.1.0
    ```

2. Add a `resource_importer` block to your `pubspec.yaml` file as described
   in [the example].

3. Run `dart run resource_importer` from the directory that contains your
   `pubspec.yaml` file to generate code.  Currently this is not automatic and
   instead is expected to be run manually as needed.

The [`Base64Data`] and [`GzippedData`] types are custom classes provided by
`resource_importer`.  If you use them, you must use a regular dependency:

  ```yaml
  dependencies:
    resource_importer: ^0.1.0
  ```

and then use [`Base64Data.data()`] or [`GzippedData.data()`] respectively to
access their decoded bytes as `Uint8List`s. Note that `GzippedData` depends on
`dart:io` and therefore cannot be used for Dart for the Web.

[the example]: https://pub.dev/packages/resource_importer/example
[`Base64Data`]: https://pub.dev/documentation/resource_importer/latest/base64_data/Base64Data-class.html
[`GzippedData`]: https://pub.dev/documentation/resource_importer/latest/gzipped_data/GzippedData-class.html
[`Base64Data.data()`]: https://pub.dev/documentation/resource_importer/latest/base64_data/Base64Data/data.html
[`GzippedData.data()`]: https://pub.dev/documentation/resource_importer/latest/gzipped_data/GzippedData/data.html
