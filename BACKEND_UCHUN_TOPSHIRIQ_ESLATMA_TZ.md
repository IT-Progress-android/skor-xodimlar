# 📋 TZ: Ochilmagan topshiriq bo'yicha xodimga soatlik eslatma

**Kimga:** Backend jamoasiga
**Kimdan:** Mobil ilova (Flutter) jamoasi
**Sana:** 2026-11-03
**Maqsad:** Xodim berilgan topshiriqni ochmaguncha unga har soatda eslatma boradi. Quyidagi logikani implementatsiya qiling, 7-bo'limdagi savollarga javob bering.

---

## 1. Bir gapda

> Xodim topshiriqni **ochmaguncha**, uning **smena vaqtida**, topshiriq berilganidan boshlab **har 1 soatda** eslatma push'i boradi. Ochgandan keyin soatlik eslatma to'xtaydi. Muddat tugashidan **1 soat oldin** esa bajarilmagan har bir topshiriq uchun bitta eslatma keladi.

---

## 2. "Ochdi" nimani bildiradi

- Xodim **topshiriq sahifasini ochganda** (`GET /bot/staff/topshiriq/{id}`) ijrochi yozuvida `seen_at` to'ldiriladi, agar u bo'sh bo'lsa.
- Topshiriqlar ro'yxati (`GET /bot/staff/topshiriq`) va push kelishi `seen_at` ni **o'zgartirmaydi**.
- Push bosilganda ilova topshiriq sahifasini ochadi, ya'ni yuqoridagi `GET` chaqiriladi va `seen_at` shu orqali yoziladi.
- `seen_at` ilovada allaqachon ishlatiladi: xodim modelida `seen_at`, rahbar sahifasida "Ko'rilmagan" / "Ko'rildi: …".

---

## 3. Soatlik eslatma ("ochilmagan")

### 3.1. Topshiriq qachon eslatmaga tushadi
Ijrochi (xodim + topshiriq juftligi) uchun **hammasi** bajarilsa:
1. `seen_at` **bo'sh**.
2. Holati **`jarayonda`** (bajarilmagan, muddati o'tmagan).
3. Topshiriq bekor qilinmagan, xodim olib tashlanmagan, boshqaga o'tkazilmagan.
4. Ijrochiga berilganiga **kamida 1 soat** bo'lgan (`berilgan_vaqt + 1 soat <= hozir`).
5. Muddat hali tugamagan (`muddat > hozir`).

### 3.2. Qachon yuboriladi
- Har bir ijrochi uchun eslatmalar **berilgan vaqtdan +1 soat, +2 soat, +3 soat…** da.
  - Masalan, 10:20 da berilsa: 11:20, 12:20, 13:20…
- Faqat xodimning **smena vaqti ichida va ish kunida**: smena boshlanishi ≤ hozir < smena tugashi, `Student::ishKunimi`.
- Smenadan tashqarida to'g'ri kelgan eslatma **o'tkazib yuboriladi**, keyin to'planib yuborilmaydi. Keyingi eslatma navbatdagi soatda, agar u smena ichida bo'lsa.
  - Masalan, smena 09:00–18:00, topshiriq 17:30 da berildi: 18:30 da yo'q, ertasi kuni birinchi eslatma 09:30 da.
- Kunlik yoki umumiy **chegara yo'q**. Ochilmaguncha va muddat tugaguncha davom etadi.
- Vaqt mintaqasi: **Asia/Tashkent**.

### 3.3. Bir nechta ochilmagan topshiriq: bitta push
- Bir xodimga bir vaqtda **bitta** push boradi, alohida-alohida emas.
- Scheduler har daqiqa ishlaydi. Shu daqiqada kamida bitta topshirig'ining eslatma vaqti kelgan xodimga push yuboriladi. Push'ga uning **hozirgi barcha ochilmagan** topshiriqlari kiradi (3.1 shartlari bo'yicha, 4-shartsiz ham).
- Bir xodimga eslatmalar orasida **kamida 50 daqiqa** bo'lishi kerak. Har xil vaqtda berilgan topshiriqlar har 20 daqiqada push chiqarmasligi uchun shu chegara.
  - Taklif: oxirgi push vaqtini saqlang, `hozir - oxirgi_push < 50 daqiqa` bo'lsa o'tkazib yuboring.

### 3.4. Push ko'rinishi

**1 ta ochilmagan topshiriq:**
```json
{
  "notification": {
    "title": "Topshiriq hali ochilmagan",
    "body": "Hisobot tayyorlash"
  },
  "data": {
    "type": "task_reminder",
    "task_id": "123",
    "count": "1"
  },
  "android": { "notification": { "channel_id": "task_channel" } },
  "apns": { "payload": { "aps": { "sound": "default", "content-available": 1 } } }
}
```

**Bir nechta:**
```json
{
  "notification": {
    "title": "3 ta topshiriq ochilmagan",
    "body": "Hisobot tayyorlash, Ombor sanog'i, Mijozga qo'ng'iroq"
  },
  "data": {
    "type": "task_reminder",
    "count": "3"
  },
  "android": { "notification": { "channel_id": "task_channel" } },
  "apns": { "payload": { "aps": { "sound": "default", "content-available": 1 } } }
}
```

- `title`: 1 ta bo'lsa "Topshiriq hali ochilmagan", ko'p bo'lsa "N ta topshiriq ochilmagan".
- `body`: eng ko'pi **3 ta nom**, undan ko'p bo'lsa "va yana N ta".
- `data.type` aynan **`task_reminder`** bo'lsin. Ilova `task_` bilan boshlanadigan turlarni topshiriq push'i deb taniydi.
- `task_id`: faqat 1 ta topshiriq bo'lsa. Ilova shu topshiriqni ochadi. `task_id` bo'lmasa, topshiriqlar ro'yxati ochiladi.
- Til: xodim tanlagan til (uz/ru/en/ky).
- Faqat **xodim** tokenlariga. Rahbarga bu push yuborilmaydi.

---

## 4. Muddatdan 1 soat oldin

- Xodim topshiriqni **ochgan** bo'lsa ham, `jarayonda` holatida (bajarilmagan) bo'lsa, `muddat - 1 soat` da **bitta** eslatma.
- Bu eslatma **smenaga qaramaydi**: muddat 23:00 bo'lsa ham 22:00 da yuboriladi.
- Har bir ijrochi + topshiriq uchun **bir marta**. Muddat o'zgarsa, yangi muddat bo'yicha yana bir marta.
- Agar topshiriq berilganda muddatgacha 1 soatdan kam qolgan bo'lsa, yuborilmaydi: yangi topshiriq push'ining o'zi yetarli.
- Shu daqiqada soatlik eslatma ham to'g'ri kelsa, ikkala push ketmasin: muddat eslatmasi yetarli. Soatlik eslatma navbatdagi soatga qoladi.

```json
{
  "notification": {
    "title": "Muddat tugashiga 1 soat qoldi",
    "body": "Hisobot tayyorlash"
  },
  "data": {
    "type": "task_deadline_soon",
    "task_id": "123"
  },
  "android": { "notification": { "channel_id": "task_channel" } },
  "apns": { "payload": { "aps": { "sound": "default", "content-available": 1 } } }
}
```

---

## 5. Eslatma qachon to'xtaydi yoki qayta boshlanadi

| Hodisa | Soatlik eslatma | Muddat eslatmasi |
|---|---|---|
| Xodim topshiriqni ochdi (`seen_at` yozildi) | ⛔ to'xtaydi | qoladi |
| Xodim "Bajardim" bosdi | ⛔ | ⛔ |
| Muddat o'tdi | ⛔ | — |
| Rahbar bekor qildi | ⛔ | ⛔ |
| Xodim topshiriqdan olib tashlandi | ⛔ | ⛔ |
| Boshqa xodimga o'tkazildi | ⛔ eski xodimga; yangi xodim uchun **yangidan** boshlanadi (o'tkazilgan vaqtdan +1 soat) | yangi xodimga |
| Yordamchi qo'shildi | yordamchi uchun **yangidan** boshlanadi (qo'shilgan vaqtdan +1 soat) | yordamchiga ham |
| Rahbar **qaytardi** (izoh bilan) | 🔄 `seen_at = null` qilinadi, xodim ochguncha **qayta boshlanadi** (qaytarilgan vaqtdan +1 soat) | yana bir marta |
| Rahbar muddatni yoki matnni o'zgartirdi | `seen_at` **o'zgarmaydi** | yangi muddat bo'yicha |

---

## 6. Rahbar tomonida

- Rahbarga **push yuborilmaydi**.
- Rahbar topshiriq sahifasida (`GET /rahbar/topshiriq/{id}`) har bir ijrochi uchun ko'radi:
  - `seen_at` (bor);
  - **yangi maydon** `reminder_count`: shu ijrochiga necha marta soatlik eslatma ketgan (qaytarilganda nolga tushmaydi, jami).
- Ilovada "Ko'rilmagan · 4 marta eslatildi" ko'rinishida chiqaramiz. Maydon kelgach, ilova tomonda qo'shamiz.

---

## 7. Savollar

1. `seen_at` hozir aynan qayerda yoziladi: `GET /bot/staff/topshiriq/{id}` dami? Ro'yxat (`GET /bot/staff/topshiriq`) uni yozib qo'ymayaptimi? Yozsa, soatlik eslatma deyarli hech qachon ketmaydi.
2. Qaytarilganda (`returnTask`) `seen_at` hozir tozalanadimi? Yo'q bo'lsa, tozalanishi kerak (5-bo'lim).
3. Xodimning smenasi topshiriq ijrochisi uchun qanday aniqlanadi? Bir xodimda bir nechta smena yoki tungi smena (23:00–07:00) bo'lishi mumkinmi?
4. Hozir topshiriq bo'yicha xodimga qaysi push turlari ketadi (yangi topshiriq, qaytarildi, o'tkazildi, muddat o'zgardi…)? `type` nomlari ro'yxatini yozing. `task_reminder` va `task_deadline_soon` ular bilan to'qnashmasligi kerak.
5. Takrorlanmaslik uchun qaysi jadvalda nimani saqlaysiz (masalan, ijrochi qatorida `last_reminder_at`, `reminder_count`, `deadline_reminded_for`)?
6. Qo'lda sinash uchun `--dry-run` buyrug'i bo'ladimi (masalan, `php artisan topshiriq:eslatma --dry-run --vaqt=2026-11-04 11:20`)?

---

## 8. Ilova tomonida (ma'lumot uchun)

| Holat | Ilova |
|---|---|
| `task_reminder` keldi, `task_id` bor | Bossa shu topshiriq sahifasi ochiladi, natijada `seen_at` yoziladi |
| `task_reminder` keldi, `task_id` yo'q | Bossa topshiriqlar ro'yxati ochiladi |
| `task_deadline_soon` | Bossa shu topshiriq ochiladi |
| Ilova ochiq | Ilova bildirishnomani o'zi ko'rsatadi va ro'yxatga yozadi |
| Rahbar ilovasi | `task_reminder` / `task_deadline_soon` ni e'tiborsiz qoldiradi |

Hozirgi ilova bu turlarni qo'shimcha o'zgarishsiz qabul qiladi (`task_` prefiksi, `task_channel`). Faqat `reminder_count` ko'rsatish uchun ilovani yangilaymiz.

---

Javobni `MOBIL_UCHUN_TOPSHIRIQ_ESLATMA_TZ_JAVOB.md` nomi bilan yuboring.
