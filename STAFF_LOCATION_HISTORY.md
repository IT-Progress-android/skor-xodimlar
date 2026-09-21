# Xodim harakat tarixi (GPS breadcrumb trail) — Backend'ga so'rov

## Maqsad

Rahbar rolida real-time xarita sahifasida (`RahbarRealtimeMapPage`) hozircha faqat xodimning **joriy (live)** joylashuvi ko'rsatiladi. Yangi talab: rahbar bitta xodimni tanlab, o'sha xodim smena davomida **qaysi yo'lni bosib o'tganini** (aniq marshrut, vaqt bo'yicha nuqtalar ketma-ketligi) xaritada chiziq (polyline) ko'rinishida ko'ra olishi kerak — "free run" / "paths traversed, precisely" degani shu.

## Nima allaqachon bor (client tomon tekshirildi)

Loyihada bu funksiya uchun **hech qanday tayyor narsa yo'q** — na backend endpoint, na client kodi. Lekin quyidagi belgilar shuni ko'rsatadiki, backend allaqachon xodimning GPS nuqtalarini vaqt bo'yicha saqlab boryotgan bo'lishi mumkin, chunki xodim ilovasi (staff app) quyidagi endpoint'larga muntazam ma'lumot yuboradi:

| Endpoint (mavjud, faqat yozish yo'nalishida) | Vazifasi |
|---|---|
| `POST /bot/staff/lokatsiya` | Xodimning joriy koordinatasini yuboradi (davriy) |
| `POST /bot/staff/lokatsiya/boshla` | GPS kuzatuv sessiyasini boshlaydi |
| `POST /bot/staff/lokatsiya/toxtat` | GPS kuzatuv sessiyasini to'xtatadi |
| `POST /bot/staff/lokatsiya/event` | Geofence'ga kirish/chiqish hodisasini yuboradi |

Bularning barchasi **faqat yozish (staff → backend)** yo'nalishida — rahbar tomonida bu ma'lumotni **o'qib olish uchun** hech qanday endpoint yo'q.

## So'ralayotgan yangi endpoint

**Taklif qilinayotgan yo'l:** `GET /rahbar/xodim/harakat` (yoki backend qulay deb hisoblagan nom, masalan `/rahbar/lokatsiya/tarix`)

**Parametrlar:**
| Parametr | Turi | Majburiymi | Izoh |
|---|---|---|---|
| `xodim_id` | int | ha | Qaysi xodim uchun |
| `sana` | string (`YYYY-MM-DD`) | ha | Qaysi kun uchun |
| `session_id` | int | yo'q | Agar bir kunda bir nechta kuzatuv sessiyasi bo'lishi mumkin bo'lsa (masalan, `boshla`/`toxtat` orasidagi har bir davr alohida sessiya) |

**Kutilayotgan javob:**

```jsonc
{
  "xodim_id": 3560,
  "sana": "2026-09-21",
  "nuqtalar": [
    { "lat": 40.13356665, "lng": 67.82268316, "vaqt": "08:56:03", "holat": "ishga_keldi" },
    { "lat": 40.13360000, "lng": 67.82270000, "vaqt": "09:12:41", "holat": null },
    { "lat": 40.13401234, "lng": 67.82300000, "vaqt": "09:45:10", "holat": "geofence_chiqdi" },
    { "lat": 40.13356665, "lng": 67.82268316, "vaqt": "18:02:15", "holat": "ishdan_ketdi" }
  ]
}
```

- `nuqtalar` — vaqt bo'yicha o'sish tartibida (chronological) tartiblangan massiv.
- `holat` — ixtiyoriy, agar shu nuqta bir hodisaga (kirish/chiqish, ishga kelish/ketish) to'g'ri kelsa, shuni belgilaydi. `null` — oddiy davriy nuqta.
- Nuqtalar zichligi (necha soniyada bitta) backend tomonda GPS push chastotasiga bog'liq — client buni belgilamaydi, faqat kelgan nuqtalarni chizadi.

## Client tomonda keyingi qadamlar (endpoint tayyor bo'lgach)

1. **Entity:** `RahbarLocationHistoryPoint` (`lat`, `lng`, `time`, `holat`) — `lib/features/rahbar/domain/entities/rahbar_entity.dart`ga qo'shiladi.
2. **Datasource method:** `getStaffLocationHistory({required int xodimId, required String sana, int? sessionId})` — `rahbar_remote_datasource.dart`ga qo'shiladi, xuddi boshqa `get*` metodlari kabi.
3. **UI:** `RahbarRealtimeMapPage`da xodim kartasiga "Harakat tarixini ko'rish" tugmasi qo'shiladi; bosilganda shu kun uchun nuqtalar so'raladi va `Polyline` sifatida xaritaga chiziladi (hozirgi `_drawInAppRouteToStaff`dagi bitta segmentli chiziqdan farqli, ko'p nuqtali marshrut).
4. Boshlanish/tugash nuqtalarida alohida marker (masalan yashil — ishga kelgan joy, qizil — ishdan ketgan joy) qo'yiladi.

## Ochiq savollar backend'ga

- Yuqoridagi endpoint yo'li va javob formati mos keladimi, yoki backend'da allaqachon boshqa nom bilan mavjudmi?
- Bitta kunda nechta nuqta saqlanadi (taxminiy chastota)? Agar juda ko'p bo'lsa (masalan har 5 soniyada), client tomonda polyline'ni soddalashtirish (downsampling) kerak bo'lishi mumkin.
- `session_id` kerakmi, yoki bitta kun uchun bitta uzluksiz ro'yxat yetarlimi?
