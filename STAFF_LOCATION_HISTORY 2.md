# Xodim harakat tarixi (GPS breadcrumb trail) — Backend javobi

**Holat: TAYYOR.** Yangi endpoint ochish shart bo'lmadi — bu funksiya uchun deyarli bir xil ishni bajaradigan endpoint allaqachon bor edi (`lokatsiya` bo'limida, rahbar xaritasi uchun), shuning uchun **shu mavjud endpoint kengaytirildi**.

## Endpoint

```
GET /api/rahbar/lokatsiya/tarix/{xodim_id}?sana=YYYY-MM-DD
```

- Himoya: xuddi boshqa `rahbar/*` endpointlari kabi — `api.rahbar` middleware (Bearer token).
- `{xodim_id}` — URL path'da (query parametr emas).
- `sana` — ixtiyoriy, berilmasa bugungi kun (`RahbarController::sana()` bilan bir xil qoida).
- `session_id` — **qo'llab-quvvatlanmaydi**, pastga qarang ("Ochiq savollarga javob").

## Javob

```jsonc
{
  "status": "ok",
  "xodim": {
    "id": 113,
    "name": "Eshmatov Begzod",
    "photo": "https://.../storage/xxx.jpg"
  },
  "sana": "2026-07-20",
  "count": 670,
  "nuqtalar": [
    {
      "lat": 40.133364,
      "lng": 67.822758,
      "vaqt": "09:28:40",
      "holat": null,
      "inside": true,
      "distance_m": 59
    },
    {
      "lat": 40.135145,
      "lng": 67.823241,
      "vaqt": "12:42:00",
      "holat": "hududdan_chiqdi",
      "inside": false,
      "distance_m": 219
    },
    {
      "lat": 40.133348,
      "lng": 67.822771,
      "vaqt": "14:02:48",
      "holat": "hududga_kirdi",
      "inside": true,
      "distance_m": 57
    }
  ]
}
```

**Original so'rovdagi shakldan farqlari** (bilib turing, aslida yaxshiroq/foydaliroq bo'lishi uchun o'zgartirildi):

- `xodim_id` — query emas, URL path'da (`{id}`), boshqa barcha `rahbar/*` endpointlar bilan bir xil konventsiya.
- `nuqtalar[].holat` — so'ralgandek `"ishga_keldi"` / `"ishdan_ketdi"` emas. Bu ma'lumot **davomat tizimidan** (FaceID/terminal) keladi, GPS nuqtalaridan emas — ikkalasi mustaqil manba, bittasini ikkinchisiga bog'lab qo'yish noto'g'ri bo'lardi (masalan xodim ishga terminal orqali kirgan bo'lishi mumkin, lekin o'sha payt GPS nuqtasi umuman kelmagan bo'lishi mumkin). Shuning uchun `holat` faqat GPS ma'lumotining o'zidan chiqadigan narsani bildiradi: **geofence chegarasidan chiqish/kirish** (`hududga_kirdi` / `hududdan_chiqdi` / oddiy nuqta bo'lsa `null`).
- `inside` (bool|null) va `distance_m` — qo'shimcha, so'rovda yo'q edi, lekin marshrutni xaritada bo'yash uchun foydali bo'lishi mumkin (masalan hududdan tashqaridagi segmentni boshqa rangda chizish).
- Boshlanish/tugash marker'lari (yashil/qizil) uchun `holat`ga suyanish shart emas — client oddiy `nuqtalar.first` / `nuqtalar.last` olsa yetarli (kunning birinchi va oxirgi GPS nuqtasi).

## Ochiq savollarga javob

1. **Endpoint yo'li mos keladimi?** Yo'q, chunki xuddi shu vazifani bajaradigan endpoint allaqachon bor edi — yangisini ochish o'rniga o'shani ishlatish ma'qul topildi (yuqoridagi yo'l).
2. **Bitta kunda nechta nuqta saqlanadi?** Bu backend tomonidan belgilanmaydi — butunlay xodim ilovasi GPS'ni qanchalik tez-tez yuborishiga bog'liq (mavjud namunada, masalan, ~9 soatlik ish kunida ~670 ta nuqta chiqdi, ya'ni o'rtacha ~50 soniyada bitta — lekin bu qat'iy qoida emas, network holatiga qarab farq qiladi). **Downsampling kerak bo'lsa, client tomonda qilinishi kerak** — backend hamma nuqtani xom holda beradi.
3. **`session_id` kerakmi?** Hozircha **yo'q** — `staff_locations` jadvalida sessiya tushunchasi umuman yo'q (kuzatuv boshlash/to'xtatish alohida guruh sifatida emas, faqat vaqt bo'yicha tekis nuqtalar oqimi sifatida saqlanadi). Bitta kun uchun bitta uzluksiz ro'yxat hozircha yetarli. Agar kelajakda bir kunda bir nechta alohida sessiyani ajratib ko'rsatish zarurati chiqsa (masalan tushlik vaqtida GPS o'chirilgan bo'lsa), buni alohida so'rov sifatida qayta ko'rib chiqamiz.

## Client tomonda keyingi qadamlar

O'zgarishsiz qoldi — original hujjatdagi rejaga mos:

1. **Entity:** `RahbarLocationHistoryPoint` (`lat`, `lng`, `vaqt`, `holat`, `inside`, `distance_m`).
2. **Datasource method:** `getStaffLocationHistory({required int xodimId, required String sana})` → `GET /rahbar/lokatsiya/tarix/$xodimId?sana=$sana`.
3. **UI:** `RahbarRealtimeMapPage`da xodim kartasiga "Harakat tarixini ko'rish" tugmasi, `Polyline` chizish.
4. Boshlanish/tugash nuqtalarida marker — `nuqtalar.first` / `nuqtalar.last` orqali (yuqoriga qarang, `holat`ga bog'liq emas).
