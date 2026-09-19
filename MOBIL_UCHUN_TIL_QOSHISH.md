# 📱 MOBIL ILOVA UCHUN — Ko'p tillilik (uz/ru/en/ky) qo'shildi

**Kimga:** Mobil ilova (Flutter, Skor Xodimlar) jamoasiga
**Holat:** ✅ Backend tomoni tayyor, kodga yozilgan va jonli sinovdan o'tkazilgan (2026-09-18). CRM (admin panel) allaqachon 4 tilda to'liq ishlayapti — endi navbat mobil ilovada.
**Nima uchun:** Tizimga 4 ta til qo'shildi: o'zbekcha (`uz`), ruscha (`ru`), inglizcha (`en`), qirg'izcha (`ky`). Quyida mobil ilova tomonidan qilinishi kerak bo'lgan ishlar va API tafsilotlari.

---

## 0. Tezkor xulosa (agar vaqtingiz kam bo'lsa)

1. Ilova ochilganda/login bo'lganda `GET /api/bot/staff/til` chaqiring — kelgan `til` qiymati bo'yicha ilovaning o'z ichki tilini o'rnating.
2. Foydalanuvchi ilova ichida tilni almashtirsa — `POST /api/bot/staff/til` bilan serverga ham yozib qo'ying (aks holda push-xabarlar eski tilda kelaveradi).
3. Ilovaning o'z interfeys matnlari (tugmalar, sahifalar) — bu backend ishi emas, buni siz o'zingiz Flutter i18n (`.arb` fayllar) orqali qilasiz.
4. (Ixtiyoriy, lekin tavsiya etiladi) — boshqa 3 til uchun push-xabar ovozi/kanali qo'shish — 3-bo'limga qarang.

---

## 1. Backend qanday ishlaydi (tushunish uchun)

- Ilovaning **o'z interfeysi** (tugmalar, sahifa matnlari) backend'dan kelmaydi — buni siz Flutter'ning o'z i18n mexanizmi (masalan `flutter_localizations` + `.arb` fayllar) orqali qilasiz. Backend bunga aralashmaydi.
- Backend faqat xodim **qaysi tilni tanlaganini eslab qoladi** (`students.til` ustuni: `uz` / `ru` / `en` / `ky`, standart — `uz`), shu bilan **server tomonidan yuboriladigan matnlar** shu tilda chiqadi:
  - Davomat eslatmasi push-xabari (`FcmService::davomatEslatmasi`) — sarlavha va matn
  - "Qo'lda belgilash" natijasi haqidagi push-xabar (`FcmService::qoldaBelgilashNatija`)

## 2. API — til saqlash/o'qish

Boshqa `bot/staff/*` endpointlar bilan bir xil naqsh (Bearer token yo'q, `phone` + ixtiyoriy `id` orqali xodim aniqlanadi).

### Tilni o'qish (masalan, login/ochilishda, boshqa qurilmada oldin tanlangan tilni bilish uchun)
```
GET /api/bot/staff/til?phone=998901234567&id=123
```
Muvaffaqiyatli javob (200):
```json
{ "status": "success", "til": "ru" }
```
Xodim topilmasa (404):
```json
{ "status": "not_found", "message": "Xodim topilmadi" }
```

### Tilni saqlash (foydalanuvchi ilovada tilni almashtirganda chaqiring)
```
POST /api/bot/staff/til
Content-Type: application/json

{
  "phone": "998901234567",
  "id": 123,
  "til": "ru"
}
```
`til` qiymati faqat `uz`, `ru`, `en`, `ky` bo'lishi mumkin. `id` ixtiyoriy (boshqa `bot/staff/*` endpointlar bilan bir xil — bir raqamda bir nechta xodim bo'lsa aniqlik uchun kerak).

Muvaffaqiyatli javob (200):
```json
{ "status": "success", "til": "ru", "message": "Til saqlandi" }
```

Xato javoblari (422 — validatsiya):
```json
// noto'g'ri til kodi yuborilsa (masalan "fr")
{ "status": "error", "message": "The selected til is invalid.", "errors": { "til": ["The selected til is invalid."] } }

// phone yuborilmasa
{ "status": "error", "message": "phone maydoni majburiy.", "errors": { "phone": ["phone maydoni majburiy."] } }
```
*(Eslatma: xato xabarlari hozircha aralash tilda chiqishi mumkin — bu backend'ning umumiy validatsiya til sozlamasiga bog'liq, `til` maydoniga aloqasi yo'q. Ilova tomonida bu xabarlarni ekranga chiqarish shart emas — shunchaki "xato" holatini status kod orqali aniqlash kifoya.)*

Xodim topilmasa (404):
```json
{ "status": "not_found", "message": "Xodim topilmadi" }
```

**Tavsiya:** ilova ochilganda/login bo'lganda `GET`ni chaqirib, natijadagi `til` bo'yicha ilovaning o'z ichki tilini o'rnating; foydalanuvchi tilni ilovada o'zgartirganda `POST` bilan serverga ham yozib qo'ying — shu orqali push-xabarlar to'g'ri tilda keladi.

## 3. Push-xabar ovozi (davomat eslatmasi) — sizdan kerak bo'lgan qo'shimcha ish

Hozirgi (o'zbekcha) push-xabar `davomat_voice_channel_v2` kanali va `davomat_sound` ovoz fayli orqali keladi — **bu o'zgarmadi**, eski ilova versiyalari buzilmaydi.

Boshqa 3 til uchun backend endi quyidagi kanal/ovoz nomlarini yuboradi:

| Til | Android `channel_id` | Android/iOS ovoz fayli nomi |
|---|---|---|
| ru | `davomat_voice_channel_v2_ru` | `davomat_sound_ru` (`.wav` — iOS uchun) |
| en | `davomat_voice_channel_v2_en` | `davomat_sound_en` |
| ky | `davomat_voice_channel_v2_ky` | `davomat_sound_ky` |

**Sizdan kerak bo'lgan ish (ixtiyoriy, lekin ovozli eslatma to'liq ishlashi uchun tavsiya etiladi):**
1. Har bir til uchun ovozli fayl tayyorlang (masalan TTS orqali "Внимание, до отметки посещаемости осталось 10 минут" kabi), Android'da `res/raw/davomat_sound_ru.mp3` (va `_en`, `_ky`) sifatida joylashtiring, iOS uchun bundle'ga `davomat_sound_ru.wav` va h.k. qo'shing.
2. Android tomonda har bir til uchun **alohida notification channel** yarating (`davomat_voice_channel_v2_ru` va h.k., yuqoridagi jadval bo'yicha) — Android'da kanal ovozi faqat kanal **birinchi marta yaratilganda** biriktiriladi, keyin o'zgarmaydi, shuning uchun har bir til uchun alohida (bir martalik) kanal kerak.

Agar buni hozircha qilmasangiz — hech narsa buzilmaydi, faqat boshqa tildagi foydalanuvchilar uchun push-xabar matni tarjima qilingan holda keladi, lekin standart tizim ovozi bilan (maxsus ovoz o'rniga).

## 4. Nima o'zgarmadi

- `/fcm-token`, login, davomat va boshqa barcha mavjud `bot/staff/*` endpointlar — **hech narsa o'zgarmadi**, orqaga moslik saqlanadi.
- Yangi `til` ustuni standart holatda `uz` — hech qanday til yubormasangiz ham, hamma narsa avvalgidek o'zbek tilida ishlayveradi.

## 5. Sinov natijalari (2026-09-18, lokal serverda tekshirildi)

| Holat | Natija |
|---|---|
| `GET /api/bot/staff/til` (til hali tanlanmagan) | ✅ `{"status":"success","til":"uz"}` |
| `POST /api/bot/staff/til` (`til: "ru"`) | ✅ `{"status":"success","til":"ru","message":"Til saqlandi"}` |
| Shundan keyin `GET` | ✅ `{"status":"success","til":"ru"}` — saqlangan qiymat qaytadi |
| `POST` noto'g'ri til kodi bilan (`"fr"`) | ✅ 422 xato qaytadi |
| `GET` mavjud bo'lmagan telefon raqami bilan | ✅ 404 `not_found` qaytadi |
