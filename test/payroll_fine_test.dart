import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';

void main() {
  const item = RahbarPayrollItemEntity(
    id: 1,
    name: 'A',
    bolim: '',
    lavozim: '',
    maosh: 1230000,
    tolovTuri: 'soatbay',
    kelganKun: 10,
    jamiIshlanganSoat: 80,
    kechikishSoni: 3,
    kechikishDaqiqa: 117,
    hisoblangan: 1290000,
    jarima: 60000,
  );

  test('har kechikishga — umumiy summa', () {
    final r = item.withFineFrom(
      const PayrollSettings(jarimaRejimi: 'har_kechikish', jarimaSumma: 50000),
    );
    expect(r.jarima, 150000);
    expect(r.maosh, 1140000);
  });

  test('har daqiqaga', () {
    final r = item.withFineFrom(
      const PayrollSettings(jarimaRejimi: 'har_daqiqa', jarimaSumma: 1000),
    );
    expect(r.jarima, 117000);
  });

  test('umumiy kalit o\'chiq — jarima yo\'q', () {
    final r = item.withFineFrom(
      const PayrollSettings(jarimaSumma: 50000, jarimaYoqilgan: false),
    );
    expect(r.jarima, 0);
    expect(r.maosh, 1290000);
  });

  test('xodimning alohida summasi ustun', () {
    const own = RahbarPayrollItemEntity(
      id: 2,
      name: 'B',
      bolim: '',
      lavozim: '',
      maosh: 0,
      tolovTuri: 'oylik',
      kelganKun: 0,
      jamiIshlanganSoat: 0,
      kechikishSoni: 2,
      jarimaSummaShaxsiy: 30000,
    );
    final r = own.withFineFrom(const PayrollSettings(jarimaSumma: 50000));
    expect(r.jarima, 60000);
    expect(r.maosh, 0);
  });
}
