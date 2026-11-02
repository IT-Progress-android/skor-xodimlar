import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/features/rahbar/data/unassigned_branch.dart';

void main() {
  test('filialsiz guruh nomi serverdan olinadi', () {
    final filiallar = [
      {'id': 5, 'nom': 'Xovos filiali', 'xodimlar': <Object>[]},
      {'id': null, 'nom': 'Asosiy bino', 'is_unassigned': true},
    ];
    expect(unassignedBranchName(filiallar), 'Asosiy bino');
  });

  test('nom bo\'sh yoki guruh yo\'q — null (zaxira matn)', () {
    expect(unassignedBranchName([]), isNull);
    expect(
      unassignedBranchName([
        {'id': null, 'nom': '  ', 'is_unassigned': true},
      ]),
      isNull,
    );
    expect(
      unassignedBranchName([
        {'id': 3, 'nom': 'Filial'},
      ]),
      isNull,
    );
  });
}
