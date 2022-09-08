```yaml
resource_importer:
  destination: 'lib/foo.resources.dart'
  # Optional.  The path to the generated `.dart` file.  If not specified,
  # `lib/resources.resource_importer.dart` will be used by default.

  resources:
  # Required.  The list of resources to import.

    myResourceName:
    # Required.  The name of the resource.  This will be directly used as the
    # name of the generated Dart variable, so it must be a valid Dart
    # identifier and must be unique.

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

    myBinaryResourceName: 'path/to/file'
    # A shorthand syntax is also provided for `Uint8List` types.
```
