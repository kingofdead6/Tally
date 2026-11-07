import 'package:tally_app/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nb = ' ';

  test('formats DA with spaced thousands', () {
    expect(Money.format(12500), '12${nb}500${nb}DA');
    expect(Money.format(1250.5), '1${nb}250,50${nb}DA');
    expect(Money.format(0), '0${nb}DA');
    expect(Money.format(999.999), '1${nb}000${nb}DA');
  });

  test('signs amounts by type', () {
    expect(Money.format(300, withSign: true, income: true), '+300${nb}DA');
    expect(Money.format(300, withSign: true, income: false), '−300${nb}DA');
    expect(Money.format(-40), '−40${nb}DA');
  });

  test('parses what people type', () {
    expect(Money.parse('12 500'), 12500);
    expect(Money.parse('1500,5'), 1500.5);
    expect(Money.parse('1500.25'), 1500.25);
    expect(Money.parse(''), isNull);
    expect(Money.parse('abc'), isNull);
    expect(Money.parse('1,2,3'), isNull);
  });

  test('compact axis labels', () {
    expect(Money.compact(1200), '1,2k');
    expect(Money.compact(45000), '45k');
    expect(Money.compact(1300000), '1,3M');
    expect(Money.compact(500), '500');
  });
}
