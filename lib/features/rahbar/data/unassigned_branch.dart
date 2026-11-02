/// `hisobot/filial` javobidagi filialsiz xodimlar guruhi
/// (`is_unassigned: true`) nomi — tab sarlavhasi serverdan olinadi, shunda
/// backend nomni o'zgartirsa ilovani yangilash shart emas. Nom bo'sh yoki
/// guruh yo'q bo'lsa — `null` (sahifa tarjimadagi zaxira matnni qo'yadi).
String? unassignedBranchName(List<Object?> rawFiliallar) {
  for (final f in rawFiliallar) {
    if (f is! Map || f['is_unassigned'] != true) continue;
    final nom = (f['nom'] ?? f['name'] ?? '').toString().trim();
    if (nom.isNotEmpty && nom.toLowerCase() != 'null') return nom;
  }
  return null;
}
