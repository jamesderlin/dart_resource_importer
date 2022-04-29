// This file is assigned to the public domain.

import 'dart:convert';
import 'dart:typed_data';

/// A class that wraps [base64]-encoded binary data.
class Base64Data {
  /// The base64-encoded string.
  final String encodedString;

  /// Constructor.
  const Base64Data(this.encodedString);

  /// Returns the decoded binary data.
  Uint8List data() => base64.decode(encodedString);
}
