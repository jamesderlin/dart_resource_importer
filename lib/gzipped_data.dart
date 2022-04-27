import 'dart:io' as io;
import 'dart:typed_data';

/// A class that wraps gzip-compressed binary data.
class GzippedData {
  /// The compressed bytes.
  final Uint8List compressedBytes;

  /// Constructor.
  const GzippedData(this.compressedBytes);

  /// Returns the decompressed bytes.
  Uint8List data() {
    var originalBytes = io.gzip.decode(compressedBytes);
    return originalBytes is Uint8List
        ? originalBytes
        : Uint8List.fromList(originalBytes);
  }
}