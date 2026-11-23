import 'package:flutter_test/flutter_test.dart';
import 'package:tm_classifier/services/classifier.dart';

void main() {
  test('parses standard labels', () {
    expect(parseLabels('0 Mug\n1 Bottle\n'), ['Mug', 'Bottle']);
  });
  test('parses Windows line endings and multiword labels', () {
    expect(parseLabels('0 Mug\r\n1 Bottle\r\n2 Car keys\r\n\r\n'), ['Mug', 'Bottle', 'Car keys']);
  });
}
