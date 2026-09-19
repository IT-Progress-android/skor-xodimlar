class ApiConstants {
  static const String baseUrl = 'https://app.skor.uz/api';

  // Auth & Device
  static const staffLogin = '/bot/staff/login';
  static const staffLogout = '/bot/staff/logout';
  static const staffFcmToken = '/bot/staff/fcm-token';
  static const staffTil = '/bot/staff/til';

  // Attendance
  static const attendanceDay = '/bot/staff/attendance/day';
  static const attendanceWeek = '/bot/staff/attendance/week';
  static const attendanceMonth = '/bot/staff/attendance/month';
  static const attendanceYear = '/bot/staff/attendance/year';
  static const checkLocation = '/bot/staff/check-location';

  // Face verify
  static const faceVerify = '/bot/staff/face-verify';

  // Applications
  static const ariza = '/bot/staff/ariza';
  static const arizaTurlari = '/bot/staff/ariza/turlari';
  static const arizaBekor = '/bot/staff/ariza/bekor';

  // Rahbar (Admin) Endpoints per Rahbar-Kabineti-API.pdf & Bosh-Sahifa-Timeout.pdf
  static const rahbarLogin = '/rahbar/login';
  static const rahbarBosh = '/rahbar/bosh';
  static const rahbarDashboard = '/rahbar/dashboard';
  static const rahbarHisobotKundalik = '/rahbar/hisobot/kundalik';
  static const rahbarHisobotXodimlar = '/rahbar/hisobot/xodimlar';
  static const rahbarHisobotFilial = '/rahbar/hisobot/filial';
  static const rahbarFilialCrud = '/rahbar/lokatsiya/filial';
  static const rahbarHisobotKunlik = '/rahbar/hisobot/kunlik';
  static const rahbarHisobotQoldiruvchilar = '/rahbar/hisobot/qoldiruvchilar';
  static const rahbarBugalteriyaOylik = '/rahbar/bugalteriya/oylik';
  static const rahbarArizalar = '/rahbar/arizalar';
  static const rahbarLokatsiyaLive = '/rahbar/lokatsiya/live';

  // Staff Live GPS Tracking & Geofence (MOBIL_UCHUN_GEOFENCE_FACEID_XAVFSIZLIK.md)
  static const staffLokatsiya = '/bot/staff/lokatsiya';
  static const staffLokatsiyaBoshla = '/bot/staff/lokatsiya/boshla';
  static const staffLokatsiyaToxtat = '/bot/staff/lokatsiya/toxtat';
  static const geofenceZones = '/bot/staff/geofence-zones';
  static const staffLokatsiyaEvent = '/bot/staff/lokatsiya/event';
  static const staffSecurityReport = '/bot/staff/security/report';
}
