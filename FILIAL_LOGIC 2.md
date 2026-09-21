# `GET /rahbar/hisobot/filial` — Backend javobi

Kodni (`app/Http/Controllers/Api/Rahbar/HisobotController.php::filial()` va shu bilan bog'liq `xodimlarRoyxati()`, hamda `DashboardController::index()`) to'liq o'qib chiqib, barcha ochiq savollaringizga aniq javob topildi.

## 1. "Unassigned" psevdo-filial — `id: null` kafolatlanganmi?

**Ha, 100% kafolatlangan, har doim.** `filial()` metodida bu guruh shartsiz, kodda qattiq yozilgan:

```php
$guruh[0] = ['id' => null, 'nom' => 'Filial biriktirilmagan', ...];
```

Sana, filtr yoki boshqa parametrlardan qat'i nazar bu qiymat hech qachon o'zgarmaydi. Yagona shart — bu guruh **faqat kamida bitta biriktirilmagan xodim bo'lgandagina** javobda keladi (bo'sh bo'lsa butunlay olib tashlanadi — `unset($guruh[0])`). Ya'ni: massivda uni ko'rsangiz, `id` doim `null`.

**Qo'shildi:** endi shu guruhda (va faqat shu guruhda) qo'shimcha aniq maydon ham bor — `"is_unassigned": true` (real filiallarda `false`). Endi `id === null`ga ham, nom bo'yicha tekshiruvga ham hojat yo'q — client shu bittasiga tayanishi mumkin. Eski nom-asosli fallback tekshiruvlarni xohlasangiz olib tashlashingiz mumkin, lekin zarar qilmaydi (ular hech qachon ishga tushmaydi, chunki `is_unassigned`/`id` aniqroq).

## 2. Xodim ID — qaysi maydon kanonik?

Faqat **`id`**. Kodni tekshirdim: `getFilial()` (`filial()`) va `getKundalik()` (`kundalik()`) — ikkalasi ham bitta xil yordamchi funksiyadan (`xodimlarRoyxati()`) foydalanadi, va ikkalasida ham `xodimlar[].id` — bitta xil `students.id` ustuni. Butun `app/Http/Controllers/Api/Rahbar/` papkasi bo'yicha qidirdim — `staff_id`, `user_id`, `xodim_id` degan JSON kalitlar **hech qayerda yo'q**. Faqat `id` bor, va u har doim bir xil odam uchun bir xil qiymat beradi.

**Xulosa:** `staff_id`/`user_id`/`xodim_id` bo'yicha tekshiruvlarni client'da xavfsiz olib tashlashingiz mumkin — ular hech qachon ishlamaydi (bu kalitlar backend javobida umuman yo'q), shunchaki keraksiz kod.

## 3. "Unassigned" guruhning `jami`/`kelgan`i boshqa joyda qo'shilganmi?

**Ha, allaqachon qo'shilgan — qayta hisoblamang.** `DashboardController::index()`dagi (bosh ekran, `totalStaff`/`presentCount` uchun) va `HisobotController::kundalik()`/`xodimlar()`dagi umumiy `hisob.jami`/`hisob.kelgan` — bularning barchasi **filial bo'yicha umuman filtr qo'ymasdan**, tashkilotdagi BARCHA `type=staff` xodimni sanaydi (`poliklinika_id` bor-yo'qligidan qat'i nazar). Ya'ni biriktirilmagan xodimlar bu umumiy sonlarga **avvaldan kiritilgan** — `filial()` endpoint faqat SHU umumiy ro'yxatni filial bo'yicha guruhlarga bo'lib ko'rsatadi, "unassigned" esa shunchaki "hech qaysi guruhga tushmagan qoldiq" degani, alohida/qo'shimcha statistika emas.

**Amaliy natija client uchun:** agar dashboard'dagi `jami_xodim`/`kelgan` bilan filiallar bo'yicha chip'lar yig'indisini solishtirsangiz — ular teng chiqishi kerak (real filiallar + unassigned = umumiy jami). Agar mos kelmasa, menga xabar bering — bu holda boshqa joyda xato bor demakdir.

## O'zgargan javob shakli (`is_unassigned` qo'shildi)

```jsonc
{
  "filiallar": [
    { "id": 6, "nom": "IT PROGRESS 1", "is_unassigned": false, "lat": 40.133, ... },
    { "id": null, "nom": "Filial biriktirilmagan", "is_unassigned": true, "lat": null, "lng": null, "radius": null, "jami": 2, "kelgan": 1, "xodimlar": [...] }
  ]
}
```

Boshqa hech narsa (maydon nomlari, `xodimlar[]` shakli) o'zgarmadi — faqat `is_unassigned` qo'shildi, eski kod buzilmaydi.
