import 'package:charcode/charcode.dart';

// ignore: public_member_api_docs
extension ListStartsWith<E> on List<E> {
  /// Returns [true] if `this` starts with [other] in order.
  bool startsWith(Iterable<E> other) {
    var iterator = this.iterator;
    var otherIterator = other.iterator;

    while (true) {
      var hasElementsLeft = iterator.moveNext();
      var otherHasElementsLeft = otherIterator.moveNext();

      if (!otherHasElementsLeft) {
        return true;
      }
      if (!hasElementsLeft) {
        return false;
      }
      if (iterator.current != otherIterator.current) {
        return false;
      }
    }
  }
}

/// A generator that escapes [runes] to store as a double-quoted [String]
/// literal.
Iterable<int> escapeRunes(Runes runes) sync* {
  for (var rune in runes) {
    switch (rune) {
      case $lf:
        yield $backslash;
        yield $n;
        break;
      case $cr:
        yield $backslash;
        yield $r;
        break;
      case $bs:
        yield $backslash;
        yield $b;
        break;
      case $tab:
        yield $backslash;
        yield $t;
        break;
      case $vt:
        yield $backslash;
        yield $v;
        break;
      case $ff:
        yield $backslash;
        yield $f;
        break;
      case $backslash:
      case $dollar:
      case $doubleQuote:
        yield $backslash;
        yield rune;
        break;
      default:
        // TODO: Generate a Unicode escape for non-ASCII characters?
        yield rune;
        break;
    }
  }
}

/// Escapes a [String] to store it as a double-quoted [String] literal.
String escapeString(String s) => String.fromCharCodes(escapeRunes(s.runes));
