# `GET /rahbar/hisobot/filial` — Client-Side Contract & Logic

Mobil ilova (Flutter) `rahbar` (rahbar/manager) rolida filiallar bilan ishlaydigan barcha logika shu faylda yig'ilgan. Backend jamoasi uchun — API kontraktini tasdiqlash va nomuvofiqliklarni aniqlash maqsadida.

## Call site

`lib/features/rahbar/data/datasources/rahbar_remote_datasource.dart:257`

```dart
Future<Map<String, dynamic>> getFilial({String? sana}) {
  return _getMap(ApiConstants.rahbarHisobotFilial, {
    if (sana != null) ...{'sana': sana, 'date': sana},
  });
}
```

Sana berilganda ikkala parametr (`sana` va `date`) ham bir xil qiymat bilan yuboriladi (ehtiyot chorasi). Endpoint 4 ta ekrandan chaqiriladi:

- `RahbarFilialPage`
- `RahbarDashboardPage`
- `RahbarKundalikPage`
- `RahbarRealtimeMapPage`

## Response shape (client tomonidan o'qiladigan maydonlar)

```jsonc
{
  "filiallar": [
    {
      "id": 6,                 // int, yoki "unassigned" psevdo-filial uchun null
      "nom": "IT PROGRESS 1",  // filial nomi (shuningdek "name" ham tekshiriladi)
      "lat": 40.133, "lng": 67.822, "radius": 200,
      "jami": 5, "kelgan": 5,
      "xodimlar": [
        {
          "id": 3560,                      // shuningdek: staff_id, user_id, xodim_id
          "name": "Abdumajidov Javohir",    // shuningdek: "xodim"
          "bolim": "Dastur", "lavozim": "Dasturchi",
          "photo": "https://...",
          "check_in": "08:56", "check_out": null,   // shuningdek: "in"/"out"
          "counts": { "events": 1, "in": 1, "out": 0, "sessions": 1, "open": 1 }
        }
      ]
    }
  ]
}
```

## 1. "Unassigned staff" psevdo-filialni aniqlash

`filiallar` massividagi bitta element hech qaysi real filialga biriktirilmagan xodimlarni ifodalaydi. Client buni shunday aniqlaydi:

```dart
final isUnassigned =
    fMap['id'] == null ||                          // ← asosiy, ishonchli belgi
    fNom.isEmpty ||
    fNom.toLowerCase().contains('biriktirilmagan') ||
    fNom.toLowerCase().contains('unassigned') ||
    fNom.toLowerCase() == 'null';
```

`id: null` shu guruh uchun barqaror belgi ekanligi tasdiqlangan; nom bo'yicha tekshiruvlar faqat ehtiyot choralari sifatida qoldirilgan.

**Backend'dan so'rov:** ushbu endpoint'ning har qanday chaqiruvida (sana bilan/sanasiz, istalgan filial konfiguratsiyasida) `id: null` doim shu guruh uchun kafolatlanganini tasdiqlab bering — shunda fallback (nom bo'yicha) tekshiruvlarni keyinchalik olib tashlash mumkin bo'ladi.

## 2. Xodimni filialga moslashtirish (ustuvorlik tartibi)

Davomat qatorlari boshqa chaqiruvdan (`getKundalik`) keladi, so'ng `filiallar[].xodimlar`dan tuzilgan xaritalar orqali filialga moslashtiriladi (`_getStaffBranchId`):

1. **Xodim ID bo'yicha** — `xodimlar[].id` (yoki `staff_id`/`user_id`/`xodim_id`) davomat obyektining `id`si bilan solishtiriladi.
2. **Xodim ismi bo'yicha** — aniq moslik, so'ng so'zlar bo'yicha "fuzzy" moslik (`xodimlar[].name`/`xodim` va davomat obyektining `name`i).
3. **`filialName` maydoni bo'yicha** — bevosita davomat obyektida (`getKundalik`dan) keladi, filial nomlariga solishtiriladi.
4. **`filialId` maydoni bo'yicha** — bevosita davomat obyektida keladi.
5. Yuqoridagilarning hech biri mos kelmasa → "unassigned" deb hisoblanadi (hech qachon birinchi filialga sukut bo'yicha biriktirilmaydi).

**Savol backend'ga:** xodim ID'si uchun qaysi maydon asosiy (kanonik) hisoblanadi — `id`, `staff_id`, `user_id` yoki `xodim_id`? Client barcha to'rttasini tekshiradi, chunki amalda nomuvofiqliklar kuzatilgan. Ideal holatda `getFilial`ning `xodimlar[].id`si va `getKundalik`ning davomat `id`si bir xil odam uchun doim bir xil qiymatda bo'lishi kerak — shuni tasdiqlab bering.

## 3. Har bir ekranda qanday ishlatiladi

| Ekran | Xatti-harakat |
|---|---|
| `RahbarFilialPage` | "Unassigned" guruhni butunlay yashiradi; faqat real filiallarni (`id != null`) ko'rsatadi. |
| `RahbarDashboardPage` / `RahbarKundalikPage` | "Unassigned" guruhni tanlanadigan filtr sifatida ko'rsatadi (client ichida `id: 0` deb belgilanadi — bu faqat lokal, backend'ga hech qachon yuborilmaydi), shunda bu xodimlar butunlay ko'zdan g'oyib bo'lib qolmaydi; `jami`/`kelgan` qiymatlari shu chip'ning umumiy sonlariga qo'shiladi. |
| `RahbarRealtimeMapPage` | Qo'shimcha ravishda `filiallar[].lat/lng/radius`ni zaxira geofence manbai sifatida ishlatadi — `/rahbar/lokatsiya/filial` (`getLocations`) hech qanday filial qaytarmagan holatlarda. |

## 4. Backend'ga ochiq savol

"Unassigned" guruhning `jami`/`kelgan` qiymatlari boshqa joyda qaytariladigan umumiy (kompaniya bo'yicha) statistikaga allaqachon qo'shilganmi (masalan, dashboard'ning umumiy `totalStaff`/`presentCount`)? Agar ha bo'lsa, client uni boshqa joyda qayta hisoblamasligi kerak; agar yo'q bo'lsa, hozircha uni faqat client tomonida yig'yapmiz.

**Ixtiyoriy, orqaga mos yaxshilanish:** shu bitta elementga aniq `"is_unassigned": true` boolean maydonini qo'shish (mavjud `id`/`nom` o'zgarmaydi) client tomonidagi barcha taxmin qilish logikasini butunlay olib tashlaydi — lekin bu majburiy emas, hozirgi `id: null` bilan ishlash ishonchli.
