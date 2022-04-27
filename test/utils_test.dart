import 'package:resource_importer/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('List.startsWith:', () {
    test('empty Lists', () {
      expect(<int>[].startsWith(<int>[]), true);
      expect(<int>[].startsWith([1]), false);
      expect([1].startsWith(<int>[]), true);
    });

    test('normal usage', () {
      expect([1, 2, 3].startsWith([1]), true);
      expect([1, 2, 3].startsWith([1, 2]), true);
      expect([1, 2, 3].startsWith([1, 2, 3]), true);
      expect([1, 2, 3].startsWith([1, 2, 3, 4]), false);
      expect([1, 2, 3].startsWith([0]), false);
      expect([1, 2, 3].startsWith([2]), false);
      expect([1, 2, 3].startsWith([3]), false);
      expect([1, 2, 3].startsWith([1, 1]), false);
      expect([1, 2, 3].startsWith([0, 1]), false);
    });
  });

  test('escapeString', () {
    expect(escapeString(''), '');
    expect(escapeString('ordinary'), 'ordinary');
    expect(escapeString('new\nlines'), r'new\nlines');
    expect(escapeString('"\r\n\b\t\v\f\\'), r'\"\r\n\b\t\v\f\\');
  });
}
