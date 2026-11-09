# 📮 Backend uchun (2): Topshiriq eslatmasi — javobga izohlar

**Kimga:** Backend jamoasiga
**Kimdan:** Mobil ilova (Flutter) jamoasi
**Sana:** 2026-11-03
**Javob:** `MOBIL_UCHUN_TOPSHIRIQ_ESLATMA_TZ_JAVOB.md` ga

---

## 0. Qisqacha

Rahmat, asosiy logika to'g'ri ishlayapti. Qabul qilganlarimiz:

- ✅ Eski 2 soatlik `task_reminder` olib tashlangani. `task_reminder` endi "soatlik, ochilmagan", `task_deadline_soon` esa "muddatdan 1 soat oldin" ma'nosida.
- ✅ `seen_at` faqat `show()` da yoziladi, `qaytar()` da tozalanadi.
- ✅ 3-bo'limdagi qaror: 50 daqiqa to'sig'iga tushgan soat nuqtasi tashlab yuboriladi. Bu bizga mos, chunki keyingi push baribir xodimning **barcha** ochilmagan topshiriqlarini o'z ichiga oladi, hech narsa yo'qolmaydi.
- ✅ Tungi smena, har daqiqalik scheduler.

Lekin javobda TZ'ning bir nechta bandi tilga olinmagan. Iltimos, quyidagilarni tasdiqlang yoki qo'shing.

---

## 1. 🔴 `reminder_count` rahbar API'sida (TZ 6-bo'lim)

`task_assignees.reminder_count` ustuni qo'shilgan, lekin u `GET /rahbar/topshiriq/{id}` javobida ijrochilar ro'yxatida chiqyaptimi? Bizga har bir ijrochi obyektida shunday kerak:

```json
{
  "staff_id": 3560,
  "holat": "jarayonda",
  "seen_at": null,
  "reminder_count": 4
}
```

Ilovada "Ko'rilmagan · 4 marta eslatildi" deb chiqaramiz.

---

## 2. 🟠 Push matni — haqiqiy payload'ni ko'rsating

Dry-run'da faqat `staff#3557 (1 ta): 03.11.2026 kungi topshiriqlar` ko'rindi. Bu topshiriq nomimi? Iltimos, bitta xodim uchun to'liq FCM payload'ni (`notification.title`, `notification.body`, `data`) dry-run'da chiqarib yuboring. Kutilgani:

| Holat | `title` | `body` | `data` |
|---|---|---|---|
| 1 ta | Topshiriq hali ochilmagan | `<nom>` | `type=task_reminder`, `task_id`, `count=1` |
| 3 ta | 3 ta topshiriq ochilmagan | `<nom1>, <nom2>, <nom3>` | `type=task_reminder`, `count=3`, `task_id` **yo'q** |
| 5 ta | 5 ta topshiriq ochilmagan | `<nom1>, <nom2>, <nom3> va yana 2 ta` | `type=task_reminder`, `count=5` |
| Muddat | Muddat tugashiga 1 soat qoldi | `<nom>` | `type=task_deadline_soon`, `task_id` |

Hammasida `android.notification.channel_id = task_channel` va `apns...content-available = 1` borligini ham tasdiqlang.

---

## 3. 🟠 Til (TZ 3.4)

Matn xodim tanlagan tilda (uz/ru/en/ky) ketyaptimi? Ruscha `title` misolini yozib bering.

---

## 4. 🟠 O'tkazish va yordamchi (TZ 5-bo'lim)

Javobda faqat `qaytar()` tilga olingan. Quyidagilarda `reminder_cycle_started_at` to'g'ri qo'yilyaptimi?

| Hodisa | Kutilgan |
|---|---|
| Boshqa xodimga o'tkazildi | Eski ijrochiga eslatma to'xtaydi. Yangi ijrochi: `reminder_cycle_started_at = o'tkazilgan vaqt`, `seen_at = null` |
| Yordamchi qo'shildi | Yordamchi: `reminder_cycle_started_at = qo'shilgan vaqt` |
| Yangi topshiriq yaratildi | `reminder_cycle_started_at = yaratilgan vaqt` (yoki `null` bo'lsa `created_at` ishlatiladi?) |
| Bekor qilindi / olib tashlandi | Hech qanday eslatma yo'q |
| Muddat o'zgardi | `seen_at` va sikl o'zgarmaydi, muddat eslatmasi yangi muddat bo'yicha yana bir marta |

**Deploy'dan oldin yaratilgan** ochilmagan topshiriqlar uchun `reminder_cycle_started_at` nima bo'ldi (migratsiyada to'ldirildimi)?

---

## 5. 🟡 Chekka holatlar (TZ 4-bo'lim)

1. Topshiriq berilganda muddatgacha **1 soatdan kam** qolgan bo'lsa, `task_deadline_soon` **yuborilmasligi** kerak. Shunday ishlayaptimi?
2. Bir xodimga shu daqiqada ham soatlik, ham muddat eslatmasi to'g'ri kelsa, **faqat** `task_deadline_soon` ketsin. Shunday ishlayaptimi?
3. Muddat eslatmasi soatlik eslatmaning 50 daqiqa to'sig'ini **yangilamasligi** kerak (ular alohida). Hozir qanday?

---

## 6. Ilova tomonida

- `task_reminder` va `task_deadline_soon` ilovaning hozirgi versiyasida o'zgarishsiz ishlaydi. Bosilganda topshiriq ochiladi, `task_id` bo'lmasa ro'yxat ochiladi.
- Ertaga smena vaqtida emulatorda xodim akkaunti bilan jonli tekshiramiz. Kelgan push'larni logdan sizga yuboramiz.

Javobni `MOBIL_UCHUN_TOPSHIRIQ_ESLATMA_2_JAVOB.md` nomi bilan yuboring.
