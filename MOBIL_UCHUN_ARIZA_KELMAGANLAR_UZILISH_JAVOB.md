# 📬 Backenddan javob: `BACKEND_UCHUN_ARIZA_KELMAGANLAR_UZILISH.md`

**Kimga:** Mobil ilova (Flutter) jamoasiga
**Kimdan:** Backend
**Mavzu:** Ariza push'lari, "kelmaganlar" push'i va GPS uzilish hisobidagi uzilish — barcha so'ralgan ishlar bajarildi

---

## 0. Qisqacha xulosa

| # | Band | Holat |
|---|---|---|
| 1 | Ariza yuborilganda rahbarga push (`ariza_new`) | ✅ Qo'shildi (bundan oldin backendda umuman yo'q edi) |
| 1.1 | Ariza tasdiqlangan/rad etilganda xodimga push (`manual_review`) | ✅ Qo'shildi |
| 2 | Smena+5 daqiqada kelmaganlar haqida rahbarga push (`absent_alert`) | ✅ Qo'shildi, yangi scheduler (`davomat:kelmaganlar`) |
| 3 | GPS uzilish birinchi nuqta kelganda yopilsin | ✅ Tuzatildi — endi "scheduler ishga tushgan payt" emas, va darhol (zaxira kutmay) yopiladi |
| 3.1 | "Keldim" qilib, kun bo'yi nuqta kelmaydigan holat | ✅ Yangi nazorat qo'shildi (`no_signal`, 10 daqiqa chegara) |

0-bo'limdagi sinovda `task_done` (xodim "Bajardim" qilganda rahbarga push) kelmagani haqida — bu band ushbu hujjat doirasidagi yangi ish emas, kod ichida allaqachon yuborilayotgani ko'rinadi (`TaskPushService::rahbarga()`, `BotStaffTopshiriqController.php:211`). Productiondagi `laravel.log`dan "TOPSHIRIQ PUSH" yozuvini (2026-11-02, soat ~09:59, token oxiri `…fLbOqmqGAOrk`) men bu yerdan (lokal muhit) ko'ra olmayman — shu voqea uchun log tekshirilishi kerak, buni alohida ko'rib chiqishni so'rayman.

---

## 1. Ariza yuborilganda — rahbarga push

`BotArizaController::store()` (xodim ariza yuborgan joy) endi `Ariza::create()`dan keyin filial rahbar(lar)iga push yuboradi — yangi `App\Services\ArizaPushService::rahbargaYangi()` orqali, javobni kechiktirmasin deb `app()->terminating()` ichida (TaskPushService bilan bir xil naqsh).

**Rahbar qidirish mantiqi:** xodimning `poliklinika_id` (filial)iga biriktirilgan `school_admin`/`director` rollari; topilmasa — filialsiz (umumiy) rahbarlar. Bu LOKATSIYA_UZILISHI_NAZORATI.md'dagi bilan bir xil qidiruv bo'lgani uchun endi `User::filialRahbarlari($schoolId, $filialId)` static metodiga chiqarildi va ikkala joyda ham shundan foydalaniladi.

Haqiqiy yuborilgan shakl (`FcmService::arizaYangi()`):

```json
{
  "notification": { "title": "Yangi ariza", "body": "Ismatov Sobir: Xizmat safari, 16.11" },
  "data": {
    "type": "ariza_new",
    "ariza_id": "123",
    "staff_id": "3558"
  },
  "android": { "notification": { "channel_id": "general_channel" } },
  "apns": { "payload": { "aps": { "sound": "default" } } }
}
```

TZ'dagi shakl bilan bir xil — `data.type` aynan `ariza_new`, `android.channel_id` = `general_channel` (sizning so'rovingizda ham shu kanal ko'rsatilgan edi).

### 1.1. Rahbar tasdiqlagan/rad etganda — xodimga push

`BoshqaruvController::arizaTasdiqla()` / `::arizaRad()` (mobil rahbar API) **va** `ArizaController::tasdiqla()` / `::radEt()` (veb panel) — ikkalasida ham, muvaffaqiyatli yangilangandan keyin `ArizaPushService::xodimgaNatija()` chaqiriladi. Rahbar arizani qaysi interfeys orqali ko'rib chiqishidan qat'i nazar (mobil yoki veb panel) xodimga push boradi.

```json
{
  "notification": { "title": "Arizangiz rad etildi", "body": "Xizmat safari, 16.11 Sabab: ..." },
  "data": {
    "type": "manual_review",
    "ariza_id": "123",
    "holat": "rad_etildi"
  },
  "android": { "notification": { "channel_id": "manual_review_channel" } },
  "apns": { "payload": { "aps": { "sound": "default" } } }
}
```

`data.type = "manual_review"` — siz yozganingizdek, bu tur/kanal ilovada "Qo'lda belgilash" natijasi uchun allaqachon bor, ariza natijasi ham shu orqali keladi. Til (uz/ru/en/ky) xodimning `til` ustuniga qarab tanlanadi — `fcm.ariza_tasdiqlandi_title`/`fcm.ariza_rad_title` kalitlari 4 tilga ham qo'shildi.

---

## 2. Smena boshlanganidan 5 daqiqa keyin — kelmaganlar

Yangi scheduler buyrug'i: `php artisan davomat:kelmaganlar` (`app/Console/Commands/DavomatKelmaganlarCommand.php`), har daqiqa ishga tushadi (`routes/console.php`, `davomat:eslatma` bilan bir xil naqsh — "hozir − 5 daqiqa" qaysi smenaning boshlanish vaqtiga teng kelsa, o'sha smena tekshiriladi).

Qoidalar — barchasi so'ralganidek:
- Tasdiqlangan arizasi bor xodim chetlanadi (`ArizaService::sanagaMap`).
- Ish kuni bo'lmagan/dam olish kunidagi xodim chetlanadi (`Student::ishKunimi`).
- Filial (`poliklinika_id`) + smena + kun bo'yicha guruhlanadi, har guruhga **BITTA** push. Yangi `absent_alerts` jadvali (unique: school+filial+smena+sana) shu "kuniga bir marta"ni kafolatlaydi.
- Hech kim kechikmagan guruh uchun push yuborilmaydi (guruh bo'sh bo'lsa, umuman ishlanmaydi).
- Matnda eng ko'pi 3 ism, qolgani "va yana N kishi" (4 va undan kam bo'lsa — hammasi ko'rsatiladi).

```json
{
  "notification": { "title": "10 ta xodim ishga kelmadi", "body": "Ismatov Sobir, Abdumajidov Javohir, Eshmatov Begzod va yana 7 kishi" },
  "data": {
    "type": "absent_alert",
    "filial_id": "6",
    "sana": "2026-11-02",
    "smena": "09:00",
    "count": "10"
  },
  "android": { "notification": { "channel_id": "general_channel" } },
  "apns": { "payload": { "aps": { "sound": "default" } } }
}
```

**Diqqat:** filialsiz xodim (tashkilotda filial tuzilmasi bo'lmasa) guruhida `data` ichida `filial_id` kaliti umuman YO'Q (bo'sh/`"0"` emas — kalit o'zi yo'q). Agar ilova shu holatni boshqacha kutayotgan bo'lsa (masalan bo'sh satr yoki `"0"`), aytib qo'ying — moslashtiramiz.

---

## 3. GPS uzilish — endi birinchi nuqta kelganda yopiladi

Ikki narsa o'zgardi:

1. **Darhol yopish.** Har safar haqiqiy (shubhali/mock bo'lmagan) GPS nuqtasi saqlanganda (`/lokatsiya`, `/lokatsiya/paket`, `/lokatsiya/event` — uchalasi ham), yangi `LokatsiyaNazoratService::nuqtaKeldi()` chaqiriladi. Agar shu xodimda ochiq uzilish bo'lsa — darhol yopiladi, scheduler navbatini (30 soniya) kutmaydi.
2. **To'g'ri `tugadi` vaqti.** Ilgari zaxira yo'l (scheduler) uzilishni "hozir" (scheduler ishga tushgan payt) bilan yopardi — shuning uchun uzilish davomiyligi haqiqatdan uzunroq chiqardi (aynan sizning 104/73 nuqtalik misolingizdagi holat). Endi ikkala yo'lda ham (darhol va zaxira) `tugadi` = uzilish boshlanganidan keyingi **ENG BIRINCHI** haqiqiy GPS nuqtasining `recorded_at`'i.

Zaxira yo'l (scheduler, `LokatsiyaNazoratCommand`) saqlanib qoldi — agar darhol yopish biror sababga ko'ra ishlamay qolsa (masalan xato), scheduler baribir to'g'ri vaqt bilan yopadi.

### 3.1. Uzilish umuman yozilmaydigan holat — tuzatildi

Sabab topildi: `/holat` (heartbeat) va boshqa so'rovlar "tirik" belgisini (`last_seen_at`) yangilab turadi, lekin bu haqiqiy GPS nuqtasi kelayotganini bildirmaydi — Borotov Lazizbek/Tursunmurodov Temur kabi xodimlarda aynan shu bo'lgan: ilova "ishlab turgan", lekin kun bo'yi atigi 1-2 ta nuqta saqlangan.

Yechim: endi haqiqiy nuqta vaqti alohida kuzatiladi (`staff_lokatsiya_holat.last_point_at`, yangi ustun). Scheduler har safar health='ok' va so'rovlar jimlik chegarasidan (5 daqiqa) ichkarida bo'lsa ham, **oxirgi haqiqiy nuqtadan 10 daqiqadan ko'proq** o'tgan bo'lsa — `sabab: no_signal` bilan uzilish ochadi va rahbarga push ketadi. Chegara (`LOC_NO_POINT_MIN`, standart 10 daqiqa) `.env`da sozlanadi.

---

## Nima o'zgarmadi / mobil tomondan tasdiqlash kerak bo'lgan narsalar

- Push formatlari (JSON shakllar) TZ'dagi bilan bir xil — yuqoridagilar `FcmService` ichidan to'g'ridan-to'g'ri olingan.
- `manual_review`/`manual_review_channel` ariza uchun ham, "qo'lda belgilash" so'rovi uchun ham ishlatiladi — ikkisini ajratish kerak bo'lsa, `data.ariza_id` bor/yo'qligiga qarab farqlash mumkin (qo'lda belgilash natijasida bu kalit yo'q).
- `absent_alert`da `filial_id` yo'q bo'lishi mumkinligi haqida yuqorida yozilgan — javob kutamiz.
- `task_done` push'i haqida (0-bo'lim, 2-qator) — log tekshiriladi, alohida xabar beramiz.
