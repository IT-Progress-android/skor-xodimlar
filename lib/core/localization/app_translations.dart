class AppTranslations {
  static const Map<String, Map<String, String>> translations = {
    'uz': {
      // Navigation
      'nav_home': 'Asosiy',
      'nav_history': 'Tarix',
      'nav_applications': 'Arizalar',
      'nav_profile': 'Profil',

      // Login
      'login_logout_reason_elsewhere':
          'Hisobingizga boshqa qurilmadan kirildi. Davom etish uchun qaytadan kiring.',
      'login_session_expired':
          'Sessiya muddati tugadi. Iltimos, qaytadan kiring.',
      'login_enter_phone': 'Telefon raqamni kiriting',
      'login_phone_length_error': 'Raqam 9 xonali bo\'lishi kerak',
      'login_enter_credentials': 'Login va parolni kiriting',
      'login_person_code_title': 'Tizim raqamingizni kiriting',
      'login_person_code_hint': 'Masalan: 31632',
      'login_person_code_note':
          'Bu raqamni rahbaringiz yoki administrator aytadi.',
      'login_continue': 'Davom etish',
      'login_contact_us': 'Biz bilan bog\'lanish',
      'login_contact_desc':
          'Tizimga kirish bo\'yicha yordam yoki ma\'lumot olish uchun quyidagi raqamga qo\'ng\'iroq qiling:',
      'login_welcome': 'Xush kelibsiz!',
      'login_select_type': 'Tizimga kirish turini tanlang',
      'login_no_account': 'Hisobingiz yo\'qmi? ',
      'login_phone_label': 'Foydalanuvchi raqami',
      'login_submit': 'Kirish',
      'login_admin_login_label': 'Rahbar logini',
      'login_admin_login_hint': 'rahbar@tashkilot.uz',
      'login_password_label': 'Parol',
      'login_admin_submit': 'Rahbar sifatida kirish',
      'login_role_staff': 'Xodim',
      'login_role_admin': 'Rahbar',

      // Home
      'attendance_check_in_label': 'Kelish',
      'attendance_check_out_label': 'Ketish',
      'home_greeting_named': 'Assalomu alaykum, {name}!',
      'home_greeting': 'Assalomu alaykum!',
      'home_today_date': 'Bugungi sana: {date}',
      'home_today_attendance_time': 'Bugungi davomat vaqti: {time}',
      'home_currently_working': 'Hozir ishda',
      'home_not_working': 'Hozir ishda emas',
      'home_delay_label': 'Kechikish: {delay}',
      'home_pending_request':
          '{label} so\'rovingiz rahbar tasdig\'ini kutmoqda',
      'home_sent_at': 'Yuborilgan: {date}',
      'home_timeline_title': 'Davomat vaqti',
      'home_events_count': '{count} ta harakat',
      'home_check_in_title': 'Ishga kelish',
      'home_check_in_recorded': 'Kelish vaqti qayd etilgan',
      'home_check_in_not_recorded': 'Hali kelish vaqti belgilanmadi',
      'home_check_out_title': 'Ishdan ketish',
      'home_check_out_recorded': 'Ketish vaqti qayd etilgan',
      'home_check_out_not_recorded': 'Hali ketish vaqti belgilanmadi',

      // Check-in
      'checkin_user_not_found':
          'Foydalanuvchi topilmadi. Iltimos, qaytadan tizimga kiring.',
      'checkin_confirm_checkin_title': 'Kelishni tasdiqlash',
      'checkin_confirm_checkout_title': 'Ketishni tasdiqlash',
      'checkin_incomplete_data':
          'Ma\'lumotlar to\'liq emas. Qaytadan urinib ko\'ring.',
      'checkin_verifying_face': 'Yuzingiz tekshirilmoqda...',
      'checkin_verifying_location': 'Lokatsiya tekshirilmoqda...',
      'checkin_marked_by_location':
          'Lokatsiya bo\'yicha belgilandi (yuz tekshiruvisiz)',
      'checkin_saved_successfully': 'Muvaffaqiyatli saqlandi!',
      'checkin_face_not_matched':
          'Yuzingiz mos kelmadi. Qaytadan urinib ko\'ring.',
      'checkin_face_invalid_ref':
          'Bazadagi rasmingiz yaroqsiz. Tashkilot rahbariga murojaat qiling.',
      'checkin_face_photo_missing':
          'Tizimda rasmingiz mavjud emas. Rahbarga murojaat qiling.',
      'checkin_face_verify_error': 'Yuzni tekshirishda xatolik yuz berdi.',
      'checkin_too_far_km': 'Siz ish joyidan {km} km uzoqdasiz.',
      'checkin_get_closer_m': 'Ish joyiga yaqinlashing — {meters} metr qoldi.',
      'checkin_outside_zone_distance':
          'Ruxsat etilgan hududdan tashqaridasiz.\nMasofa: {distance}',
      'checkin_outside_zone': 'Ruxsat etilgan hududdan tashqaridasiz.',
      'checkin_save_error': 'Davomatni saqlashda xatolik yuz berdi.',
      'checkin_pending_review_sent':
          'So\'rovingiz rahbarga yuborildi, tasdiqlanishi kutilmoqda.',
      'checkin_pending_review_id':
          'So\'rov raqami: {id}. Rahbar tasdiqlagach davomat qayd etiladi.',
      'checkin_pending_review_note':
          'Rahbar tasdiqlagach davomat qayd etiladi.',
      'checkin_already_recorded': 'Allaqachon qayd etilgan: {time}',
      'checkin_already_recorded_generic': 'Bu davomat allaqachon qayd etilgan.',
      'checkin_recorded_success': 'Muvaffaqiyatli qayd etildi: {time}',
      'generic_error_retry': 'Xatolik yuz berdi. Qaytadan urinib ko\'ring.',
      'checkin_back_to_main': 'Asosiyga qaytish',
      'checkin_no_photo_title': 'Sizga rasm yuklanmagan',
      'checkin_no_photo_desc':
          'Yuz orqali tekshirish uchun tizimda rasmingiz bo\'lishi kerak. '
          'Iltimos, rahbaringizga murojaat qiling.\n\n'
          'Hozircha joylashuv bo\'yicha belgilashingiz mumkin — bunda '
          'davomat rahbar tasdig\'idan keyin qayd etiladi.',
      'checkin_mark_by_location': 'Lokatsiya bo\'yicha belgilash',
      'checkin_engine_down': 'Yuz tekshiruvi vaqtincha ishlamayapti.',
      'checkin_engine_down_desc':
          'Yuz tekshiruvisiz, faqat joylashuv bo\'yicha davom etishingiz mumkin.',
      'checkin_slide_to_checkin': 'Davomat qilish uchun suring',
      'checkin_slide_to_checkout': 'Ketish uchun suring',
      'checkin_confirmed_in': 'Keldim',
      'checkin_confirmed_out': 'Ketdim',

      // Attendance card
      'attendance_details': 'Tafsilot',
      'attendance_present': 'Kelgan',
      'attendance_absent': 'Kelmagan',
      'attendance_sessions_summary':
          '{sessions} marta kirib chiqqan · {events} ta yozuv',
      'attendance_open_sessions': '{count} ta yopilmagan',
      'attendance_sessions_title': 'Sessiyalar (Kirish-chiqish juftliklari):',
      'attendance_session_minutes': '{minutes} daqiqa',
      'attendance_session_open': 'Yopilmagan sessiya',
      'attendance_events_title': 'Barcha yozuvlar (Turniket/App harakatlari):',
      'attendance_event_in': 'Kirdi',
      'attendance_event_out': 'Chiqdi',

      // Select organization / Splash
      'select_org_title': 'Tashkilotni tanlang',
      'splash_tagline': 'Xodimlarni Boshqarish Tizimi',

      // Applications
      'no': 'Yo\'q',
      'ariza_cancel_title': 'Arizani bekor qilish',
      'ariza_cancel_confirm': '{name} ({date}) arizasini bekor qilmoqchimisiz?',
      'ariza_cancel_yes': 'Ha, bekor qilish',
      'applications_title': 'Arizalarim',
      'ariza_tab_all': 'Hamma',
      'ariza_tab_pending': 'Kutilmoqda',
      'ariza_tab_approved': 'Tasdiqlandi',
      'ariza_tab_rejected': 'Rad etildi',
      'ariza_new': 'Yangi ariza',
      'ariza_empty_title': 'Bu holatda ariza yo\'q',
      'ariza_empty_desc': 'Tanlangan kategoriya bo\'yicha ariza topilmadi.',
      'no_internet_title': 'Internet aloqasi yo\'q',
      'error_occurred_title': 'Xatolik yuz berdi',
      'ariza_form_date_range_info':
          'Ariza faqat oxirgi 30 kun ichidagi va kelajakdagi sanalarga '
          'yozilishi mumkin.',
      'ariza_form_missing_fields':
          'Iltimos, ariza turi va kamida boshlanish sanasini tanlang',
      'ariza_form_invalid_date_range':
          'Tugash sanasi boshlanish sanasidan oldin bo\'lishi mumkin emas',
      'ariza_form_submitted_success': 'Arizangiz muvaffaqiyatli yuborildi',
      'ariza_form_type_label': 'Ariza turi',
      'ariza_form_type_hint': 'Ariza turini tanlang',
      'ariza_form_start_date_label': 'Boshlanish sanasi',
      'ariza_form_end_date_label': 'Tugash sanasi',
      'ariza_form_pick_date': 'Sana tanlang',
      'ariza_form_optional': 'Ixtiyoriy',
      'ariza_form_duration': 'Davomiyligi: {days} kun',
      'ariza_form_reason_label': 'Izoh / Sabab (ixtiyoriy)',
      'ariza_form_reason_hint': 'Ariza sababini yozing...',
      'ariza_form_submit': 'Arizani Yuborish',
      'ariza_sheet_title': 'Yangi ariza yuborish',
      'ariza_sheet_date_range_info':
          'Ariza faqat oxirgi 30 kun ichidagi va kelajakdagi sanalarga yoziladi.',
      'ariza_sheet_reason_label': 'Sabab / Izoh (ixtiyoriy)',
      'ariza_sheet_reason_hint':
          'Xizmat safari maqsadi yoki ariza sababini yozing...',
      'ariza_sheet_submit': 'Arizani yuborish',
      'ariza_sheet_submitted_success':
          'Arizangiz muvaffaqiyatli yuborildi. Tasdiqlanishini kuting.',
      'ariza_card_days_count': '{days} kun',
      'ariza_card_comment': 'Izoh: {text}',
      'ariza_card_review_note': 'Sabab / Izoh: {text}',

      // Notifications
      'notif_just_now': 'Hozirgina',
      'notif_minutes_ago': '{minutes} daqiqa oldin',
      'notif_today_at': 'Bugun, {time}',
      'notif_yesterday_at': 'Kecha, {time}',
      'notif_all_marked_read': 'Barcha bildirishnomalar o\'qildi',
      'notif_clear_all_title': 'Barchasini o\'chirish',
      'notif_clear_all_confirm':
          'Barcha bildirishnomalarni tozalashni xohlaysizmi?',
      'notif_clear': 'Tozalash',
      'notif_go_to_attendance': 'Davomatdan o\'tish',
      'notif_delete': 'O\'chirish',
      'notif_title': 'Bildirishnomalar',
      'notif_mark_all_read': 'Barchasini o\'qilgan qilish',
      'notif_clear_all_menu': 'Barchasini tozalash',
      'notif_filter_all': 'Barchasi',
      'notif_filter_attendance': 'Davomat',
      'notif_filter_system': 'Tizim',
      'notif_empty_title': 'Bildirishnomalar yo\'q',
      'notif_empty_desc':
          'Davomat eslatmalari va tizim xabarlari shu yerda aks etadi.',
      'attendance_history_title': 'Davomat tarixi',
      'attendance_tab_week': 'Hafta',
      'attendance_tab_month': 'Oy',
      'attendance_tab_year': 'Yil',
      'attendance_history_empty_title': 'Bu davrda davomat yozuvi yo\'q',
      'attendance_history_empty_desc':
          'Tanlangan davr uchun keldi-ketdi yozuvi topilmadi.',

      // Rahbar dashboard
      'rahbar_logout_title': 'Rahbar kabinetidan chiqish',
      'rahbar_logout_confirm':
          'Tizimdan chiqib, kirish sahifasiga qaytmoqchimisiz?',
      'rahbar_logout_yes': 'Ha, chiqish',
      'rahbar_dashboard_title': 'Rahbar Kabineti',
      'rahbar_logout_tooltip': 'Chiqish',
      'rahbar_today_stats': 'Bugungi ko\'rsatkichlar',
      'rahbar_date_stats': '{date} ko\'rsatkichlari',
      'rahbar_no_data_notice': 'Bu sana uchun davomat yozuvlari mavjud emas.',
      'rahbar_no_data_notice_with_last':
          'Bu sana uchun davomat yozuvlari mavjud emas (oxirgi yozuv: {date}).',
      'rahbar_kpi_late': 'Kechikkan',
      'rahbar_review_applications': 'Arizalar ko\'rib chiqish',
      'rahbar_pending_ariza_count': '{count} ta ariza tasdiqlash kutilmoqda',
      'rahbar_new_arizalar': 'Yangi arizalar',
      'rahbar_view_all_count': 'Barchasi ({count} ta) →',
      'rahbar_staff_fallback': 'Xodim',
      'rahbar_ariza_fallback': 'Ariza',
      'rahbar_ariza_summary': '{turi} · {days} kun',
      'rahbar_late_section_title': 'Kechikkanlar',
      'rahbar_no_late_in_branch': 'Ushbu filialda kechikkanlar yo\'q',
      'rahbar_delay_minutes': '+{minutes} daq',
      'rahbar_department_fallback': 'Bo\'lim',
      'rahbar_departments_attendance': 'Bo\'limlar bo\'yicha davomat',
      'rahbar_load_failed': 'Ma\'lumotlarni yuklab bo\'lmadi',
      'rahbar_delay_hours_mins': '{hours} soat {mins} daq kechikkan',
      'rahbar_delay_hours': '{hours} soat kechikkan',
      'rahbar_delay_mins': '{mins} daqiqa kechikkan',
      'rahbar_delay_raw': '{delay} kechikkan',
      'rahbar_filter_kelganlar': 'Kelganlar',
      'rahbar_filter_kelmaganlar': 'Kelmaganlar',
      'rahbar_kundalik_title': 'Kundalik Davomat',
      'rahbar_prev_day': 'Oldingi kun',
      'rahbar_next_day': 'Keyingi kun',
      'rahbar_search_hint': 'Ism, bo\'lim yoki lavozim...',
      'rahbar_search_no_staff': '"{query}" bo\'yicha xodim topilmadi',
      'rahbar_filter_no_data': '{filter} bo\'yicha ma\'lumot yo\'q',
      'rahbar_try_different_search': 'Qidiruv so\'zini o\'zgartirib ko\'ring',
      'rahbar_no_staff_on_date':
          '{date} sanasida ushbu toifada xodimlar topilmadi',
      'rahbar_entry_label': 'Kirish',
      'rahbar_exit_label': 'Chiqish',
      'rahbar_at_work_short': 'Ishda',
      'rahbar_hours_worked': '{hours} soat',
      'rahbar_currently_at_work_inside': 'Hozir ish joyida (ichkarida)',
      'rahbar_nav_home': 'Bosh sahifa',
      'rahbar_nav_reports': 'Hisobotlar',
      'rahbar_nav_map': 'Xarita',
      'rahbar_nav_payroll': 'Bugalteriya',
      'rahbar_report_kundalik_title': 'Kundalik davomat',
      'rahbar_report_kundalik_desc': 'Bir kun — har bir xodim qatori',
      'rahbar_report_xodimlar_title': 'Xodimlar davomati',
      'rahbar_report_xodimlar_desc': 'Oraliq bo\'yicha yig\'ma hisob',
      'rahbar_report_kunlik_title': 'Kunlik davomat',
      'rahbar_report_kunlik_desc': 'Har kun uchun umumiy foiz',
      'rahbar_report_qoldiruvchilar_title': 'Ko\'p qoldiruvchilar',
      'rahbar_report_qoldiruvchilar_desc': 'Eng ko\'p kelmaganlar',
      'rahbar_report_filial_title': 'Filial xodimlari',
      'rahbar_report_filial_desc': 'Filial kesimida',
      'rahbar_no_data_in_range': 'Bu oraliqda ma\'lumot yo\'q',
      'rahbar_kunlik_summary':
          'Kelgan: {present}/{total}  ·  Kechikkan: {late}  ·  Arizali: {ariza}',
      'rahbar_kunlik_legend':
          'Rang: 🟢 80% va undan yuqori   🟠 50–79%   🔴 50% dan past',
      'rahbar_terminal_not_connected': 'Terminal hali ulanmagan',
      'rahbar_no_data_this_date': 'Bu sanada ma\'lumot yo\'q',
      'rahbar_no_attendance_data_generic':
          'Davomat ma\'lumoti yo\'q yoki yozuv yuborilmagan.',
      'rahbar_go_to_date': '{date} ga o\'tish',
      'rahbar_no_absentees': 'Qoldiruvchilar yo\'q — hammasi joyida 👍',
      'rahbar_absent_days_count': '{absent} / {total} kun',
      'rahbar_payroll_title': 'Bugalteriya / Maoshlar',
      'rahbar_payroll_empty_title': 'Maosh ma\'lumotlari yo\'q',
      'rahbar_payroll_empty_desc':
          'Ushbu oy uchun hali xodimlar maosh hisoblari kiritilmagan',
      'rahbar_payroll_sum': '{amount} so\'m',
      'rahbar_payroll_days_present': 'Kelgan kunlar: {days} kun',
      'rahbar_payroll_hours_worked': 'Ishlangan: {hours} soat',
      'rahbar_branches_not_found': 'Filiallar topilmadi',
      'rahbar_branches_empty_desc':
          'Hozircha birorta filial ma\'lumotlari mavjud emas.',
      'rahbar_branch_fallback': 'Filial',
      'rahbar_all_branches': 'Barchasi',
      'rahbar_arrived_count': '{present} / {total} keldi',
      'rahbar_branch_no_staff': 'Ushbu filialda xodimlar mavjud emas',
      'rahbar_ariza_approve_title': 'Arizani tasdiqlash',
      'rahbar_ariza_reject_title': 'Arizani rad etish',
      'rahbar_ariza_confirm_approve':
          '{name}ning "{turi}" arizasini tasdiqlaysizmi?',
      'rahbar_ariza_confirm_reject':
          '{name}ning "{turi}" arizasini rad etasizmi?',
      'rahbar_ariza_comment_hint': 'Izoh / Sabab yozing (ixtiyoriy)...',
      'rahbar_approve': 'Tasdiqlash',
      'rahbar_reject': 'Rad etish',
      'rahbar_arizalar_list_title': 'Arizalar Ro\'yxati',
      'rahbar_no_arizalar_title': 'Kelib tushgan arizalar yo\'q',
      'rahbar_no_arizalar_desc':
          'Xodimlardan tasdiqlash uchun yuborilgan arizalar mavjud emas',
      'rahbar_ariza_type_days': 'Turi: {turi} · {days} kun',
      'rahbar_ariza_date_range': 'Sana: {from} — {to}',
      'add_staff_fill_all_fields': 'Barcha maydonlarni to\'ldiring',
      'add_staff_title': 'Hodim / O\'quvchi qo\'shish',
      'add_staff_success_desc':
          'Xodim: {name}\nYangi xodim muvaffaqiyatli saqlandi.',
      'ok': 'OK',
      'add_staff_search': 'Qidirish',
      'add_staff_step2_title': 'Lavozim ma\'lumotlari',
      'add_staff_step3_title': 'Shaxsiy ma\'lumotlar',
      'add_staff_surname_label': 'Familiya (masalan: Ergashov / Ergasheva)',
      'add_staff_surname_hint': 'Familiyani kiriting...',
      'add_staff_name_label': 'Ism',
      'add_staff_phone_label': 'Telefon',
      'add_staff_gender_label': 'Jinsi: ',
      'add_staff_male': 'Erkak',
      'add_staff_female': 'Ayol',
      'add_staff_step4_title': 'Rasm va Yakunlash',
      'assign_zone_default_name_staff': '{name} — Ish hududi',
      'assign_zone_default_name_new': 'Yangi filial (Ish hududi)',
      'assign_zone_name_required': 'Iltimos, ish hududi nomini kiriting',
      'assign_zone_saved_success':
          '✅ "{name}" ish hududi ({radius}m) muvaffaqiyatli saqlandi!',
      'assign_zone_error': 'Xatolik: {error}',
      'assign_zone_title': 'Ish joyi hududini belgilash',
      'assign_zone_staff_label': 'Xodim: {name}',
      'assign_zone_instruction':
          'Xaritadan biror joyni bosing — atrofiga aylana hudud chiziladi',
      'assign_zone_name_field_label': 'Hudud / Filial nomi',
      'assign_zone_radius_label': 'Aylanasi radiusi:',
      'assign_zone_radius_value': '{radius} metr',
      'assign_zone_saving': 'Saqlanmoqda...',
      'assign_zone_save_button': 'Hududni saqlash va biriktirish',
      'rahbar_call': 'Qo\'ng\'iroq qilish',
      'rahbar_period_label': 'Davr: {from} — {to}',
      'rahbar_attendance_percent': '{percent}% davomat',
      'rahbar_attendance_metrics_title': 'Davomat ko\'rsatkichlari',
      'rahbar_kpi_days_present_title': 'Kelgan kunlar',
      'rahbar_kpi_days_absent_title': 'Kelmagan kunlar',
      'rahbar_kpi_days_late_title': 'Kechikkan kunlar',
      'rahbar_kpi_days_leave_title': 'Arizali / Sababli',
      'rahbar_kpi_hours_total_title': 'Jami ishlagan vaqt',
      'rahbar_kpi_delay_total_title': 'Jami kechikish',
      'rahbar_hours_mins_short': '{hours} s {mins} daq',
      'rahbar_minutes_plain': '{mins} daqiqa',
      'rahbar_search_staff_name': 'Xodim ismini qidirish...',
      'rahbar_data_not_found': 'Ma\'lumot topilmadi',
      'rahbar_no_staff_data_period':
          'Bu davr uchun xodimlar davomati ma\'lumotlari mavjud emas',
      'rahbar_on_leave_short': 'Arizali',
      'rahbar_main_office': 'Bosh Ofis',
      'rahbar_time_ago': '{time} ({min} daq oldin)',
      'rahbar_badge_at_work': 'Ishda',
      'rahbar_badge_left': 'Ketgan',
      'rahbar_badge_outside': 'Tashqarida',
      'rahbar_checkin_time_label': 'Kelish vaqti',
      'rahbar_checkout_time_label': 'Ketish vaqti',
      'rahbar_status_label': 'Holati',
      'rahbar_assign_zone_button': 'Xodimga yangi ish hududi belgilash',
      'rahbar_view_route_button': 'Ichki xaritada marshrutni ko\'rish',
      'rahbar_map_title': 'Xodimlar Lokatsiyasi',
      'rahbar_new_zone_button': 'Yangi hudud',
      'rahbar_live_badge': 'JONLI',
      'rahbar_total_count': 'Jami: {count}',
      'rahbar_inside_count': 'Ishda: {count}',
      'rahbar_outside_count': 'Tashqarida: {count}',
      'rahbar_route_label': 'Yo\'nalish: {name}',
      'rahbar_search_staff_plural': 'Xodimlarni qidirish...',
      'offline_reconnected': 'Internet aloqasi qayta tiklandi!',
      'offline_still_no_internet':
          'Hali ham internet yo\'q. Iltimos, ulanishni tekshiring.',
      'offline_title': 'Internet aloqasi mavjud emas',
      'offline_desc':
          'Skor Xodimlar ilovasi ishlashi, davomatni qayd etish va '
          'ma\'lumotlarni sinxronlash uchun internet talab etiladi.',
      'offline_tip_wifi': 'Wi-Fi yoki mobil internet yoqilganini tekshiring',
      'offline_tip_balance':
          'Tarifingizda megabayt yoki balans borligiga ishonch hosil qiling',
      'offline_tip_airplane':
          'Samolyot (Flight) rejimi o\'chiqligini tekshiring',
      'offline_tip_vpn':
          'Agar VPN yoqilgan bo\'lsa, uni vaqtincha to\'xtatib ko\'ring',
      'offline_understood': 'Tushunarli',
      'offline_checking': 'Kutilmoqda...',
      'offline_recheck': 'Qayta tekshirish',
      'location_disclosure_title': 'Joylashuv ma\'lumotlaridan foydalanish',
      'location_disclosure_statement':
          '"Skor Xodimlar" ilovasi xodimlarning ish vaqtida hududda ekanligini '
          'real vaqt rejimida qayd etish va davomat monitoringini yuritish '
          'uchun joylashuv (geolokatsiya) ma\'lumotlarini to\'playdi. Ushbu '
          'ma\'lumotlar ilova yopiq bo\'lganda yoki undan foydalanilmayotgan '
          'paytda ham (fonda / background) to\'planishi mumkin.',
      'location_feature_time_title': 'Ish vaqti va davomat nazorati',
      'location_feature_time_desc':
          'Tashkilot hududiga kelish va ketish vaqtlari avtomatik hisoblanadi.',
      'location_feature_privacy_title': 'Maxfiylik va xavfsizlik',
      'location_feature_privacy_desc':
          'Joylashuv ma\'lumotlari faqat ish beruvchi tizimida ishlatiladi, '
          'uchinchi shaxslarga berilmaydi va reklamalar uchun foydalanilmaydi.',
      'location_accept': 'Tushundim va roziman',
      'location_decline': 'Hozir emas (Rad etish)',
      'bg_location_disclosure_title': 'Doimiy joylashuv (Fon rejimi)',
      'bg_location_disclosure_statement':
          '"Skor Xodimlar" ilovasi xodimning tashkilot hududida ekanligini '
          'ish vaqtida avtomatik monitoring qilish va davomatni aniq yuritish uchun '
          'joylashuv ma\'lumotlarini ilova yopiq bo\'lganda yoki undan '
          'foydalanilmayotgan paytda ham (fonda) to\'playdi.\n\n'
          'Ushbu imkoniyat ishlashi uchun keyingi sozlamalar oynasida '
          '"Har doim ruxsat berish" parametrini tanlang.',
      'bg_location_open_settings': 'Sozlamalarga o\'tish',
      'bg_location_cancel': 'Hozir emas (Rad etish)',
      'no_internet_default_message':
          'Ma\'lumotlarni yuklab bo\'lmadi. Tarmoqqa ulanishni tekshirib, '
          'qayta urinib ko\'ring.',
      'no_internet_reload': 'Qayta yuklash',
      'no_internet_tips_tooltip': 'Tavsiyalar',
      'app_update_default_title': 'Ilovani yangilang',
      'app_update_default_desc':
          'Iltimos, barcha funksiyalardan foydalanish uchun ilovani eng '
          'so\'nggi versiyasiga yangilang.',
      'app_update_button': 'Yangilash',
      'app_update_later': 'Keyinroq',
      'offline_banner_restored_title': 'Internet aloqasi tiklandi',
      'offline_banner_offline_title': 'Internet aloqasi yo\'q',
      'offline_banner_restored_desc': 'Tizim aloqasi qayta o\'rnatildi',
      'offline_banner_offline_desc': 'Tarmoqqa ulanishni tekshiring',
      'selfie_position_face': 'Yuzingizni doira ichiga joylang',
      'selfie_camera_permission_denied': 'Kameraga ruxsat berilmadi',
      'selfie_camera_not_found': 'Kamera topilmadi',
      'selfie_camera_open_failed': 'Kamerani ochib bo\'lmadi',
      'selfie_face_not_detected': 'Yuz aniqlanmadi',
      'selfie_only_one_face': 'Faqat bitta yuz ko\'rinishi kerak',
      'selfie_come_closer': 'Yaqinroq keling',
      'selfie_move_back': 'Bir oz uzoqroq turing',
      'selfie_hold_still': 'Ushlab turing...',
      'selfie_blink_once': 'Ko\'zingizni bir marta qisib oching',
      'selfie_capturing': 'Suratga olinmoqda...',
      'selfie_capture_error': 'Rasmga olishda xatolik',
      'selfie_permission_denied_desc':
          'Kameradan foydalanishga ruxsat berilmagan.\nIltimos, sozlamalardan '
          'ruxsat bering.',
      'selfie_camera_unavailable': 'Kamera mavjud emas',
      'selfie_open_settings': 'Sozlamalarni ochish',
      'selfie_close_eyes': 'Ko\'zingizni yumib oching',
      'selfie_hold_in_circle': 'Yuzingizni doira ichida ushlab turing',

      // Error formatter (non-widget layers — blocs/repositories/datasources)
      'err_unknown': 'Noma\'lum xatolik yuz berdi. Qaytadan urinib ko\'ring.',
      'err_connection_timeout':
          'Serverga ulanish vaqti tugadi. Internet aloqasini tekshirib, '
          'qayta urinib ko\'ring.',
      'err_receive_timeout':
          'Server javob bermadi. Iltimos, birozdan so\'ng qayta urinib '
          'ko\'ring.',
      'err_connection_error':
          'Internetga ulanmagansiz yoki tarmoq juda sekin. Ulanishni '
          'tekshiring.',
      'err_cancelled': 'Amal bekor qilindi.',
      'err_bad_certificate': 'Xavfsiz ulanishda xatolik yuz berdi.',
      'err_status_400': 'Noto\'g\'ri so\'rov yuborildi.',
      'err_status_401':
          'Sessiya muddati tugagan. Iltimos, qaytadan tizimga kiring.',
      'err_status_403': 'Ushbu amalni bajarish uchun ruxsat berilmagan.',
      'err_status_404': 'Ma\'lumot yoki xizmat manzili topilmadi.',
      'err_status_405':
          'Server bilan aloqa uzildi. Iltimos, qayta urinib ko\'ring.',
      'err_status_413':
          'Yuklanayotgan fayl yoki rasm hajmi juda katta. Qaytadan urinib '
          'ko\'ring.',
      'err_status_419': 'Xavfsizlik kaliti eskirgan. Qaytadan urinib ko\'ring.',
      'err_status_422': 'Kiritilgan ma\'lumotlar to\'g\'ri kelmadi.',
      'err_status_429':
          'So\'rovlar soni ko\'payib ketdi. Iltimos, biroz kuting.',
      'err_status_500':
          'Serverda vaqtinchalik xatolik yuz berdi. Birozdan so\'ng urinib '
          'ko\'ring.',
      'err_status_5xx':
          'Serverda profilaktika yoki ta\'mirlash ishlari olib borilmoqda.',
      'err_status_unknown':
          'Server bilan bog\'lanishda xatolik yuz berdi ({code}).',
      'err_unknown_code': 'noma\'lum',
      'err_image_too_large': 'Rasm hajmi juda katta. Qaytadan suratga oling.',
      'err_network_socket':
          'Internetga ulanmagansiz yoki tarmoq sekin. Ulanishni tekshiring.',
      'err_timeout_generic':
          'Server javob berish vaqti tugadi. Qaytadan urinib ko\'ring.',
      'err_server_crash':
          'Serverda vaqtinchalik nosozlik yuz berdi. Birozdan so\'ng urinib '
          'ko\'ring.',
      'err_user_not_found': 'Foydalanuvchi topilmadi. Qaytadan tizimga kiring.',
      'err_too_many_requests':
          'Juda ko\'p so\'rov yuborildi. Iltimos, biroz kuting.',
      'err_validation': 'Kiritilgan ma\'lumotlarda xatolik bor.',
      'err_no_face':
          'Yuz aniqlanmadi. Yuzingizni ekranga to\'g\'rilab, qaytadan suratga '
          'oling.',
      'err_format':
          'Server ma\'lumotlarida nosozlik. Iltimos, qayta urinib ko\'ring.',
      'err_unexpected':
          'Kutilmagan xatolik yuz berdi. Iltimos, ilovani qayta ishga '
          'tushiring.',
      'err_html_page':
          'Serverda texnik ishlar olib borilmoqda. Birozdan so\'ng qayta '
          'urinib ko\'ring.',
      'err_generic': 'Xatolik yuz berdi. Iltimos, qayta urinib ko\'ring.',
      'err_phone_not_registered': 'Bu raqam tizimda ro\'yxatdan o\'tmagan',
      'err_phone_ambiguous_badge':
          'Bu raqam bir nechta xodimga biriktirilgan. Tizim (badge) '
          'raqamingizni kiriting.',
      'err_phone_ambiguous_blocked':
          'Bu raqam bir nechta xodimga biriktirilgan. Kirish vaqtincha '
          'to\'xtatilgan — administratorga murojaat qiling.',
      'err_request_truncated':
          'Internet aloqasida muammo bor — so\'rov serverga to\'liq yetib '
          'bormadi. Wi-Fi ga ulanib yoki mobil internetni o\'chirib-yoqib, '
          'qaytadan urinib ko\'ring.',
      'err_invalid_phone_format': 'Telefon raqam formati noto\'g\'ri',
      'err_server_generic': 'Serverda xatolik. Birozdan keyin urinib ko\'ring',
      'err_no_internet': 'Internetga ulanmagansiz',
      'err_could_not_connect': 'Serverga bog\'lanib bo\'lmadi.',
      'face_verify_success': 'Muvaffaqiyatli',
      'face_verify_no_match':
          'Yuzingiz mos kelmadi. Iltimos, o\'zingizni tekshirib, qaytadan '
          'urinib ko\'ring.',
      'face_verify_ref_invalid':
          'Bazadagi rasmingiz yaroqsiz. Adminga murojaat qiling.',
      'face_verify_face_not_visible':
          'Yuzingiz ko\'rinmadi. Yuzni ramka ichiga joylang.',
      'face_verify_photo_missing':
          'Sizga rasm yuklanmagan. Adminga murojaat qiling.',
      'face_verify_timeout':
          'Server javob bermadi. Birozdan keyin qayta urinib ko\'ring.',
      'face_verify_not_configured':
          'Yuz tekshiruvi xizmati sozlanmagan. Adminga murojaat qiling.',
      'face_verify_unavailable':
          'Xizmat vaqtincha ishlamayapti. Birozdan keyin urinib ko\'ring.',
      'err_empty_image': 'Rasm bo\'sh. Qaytadan suratga oling.',
      'err_connection_lost':
          'Server bilan aloqa uzildi. Iltimos, qayta urinib ko\'ring.',
      'err_server_action_failed': 'Server xatosi yuz berdi',
      'err_attendance_failed': 'Davomat belgilashda xatolik yuz berdi',
      'err_profile_load_failed': 'Profil ma\'lumotlarini yuklashda xatolik',
      'err_profile_load_could_not': 'Profil ma\'lumotlarini yuklab bo\'lmadi',
      'err_photo_upload_failed': 'Rasmni yuklashda xatolik yuz berdi',
      'err_photo_upload_could_not': 'Rasmni yuklab bo\'lmadi',
      'profile_phone_updated': 'Telefon raqam yangilandi',
      'err_phone_duplicate': 'Bu raqam boshqa xodimga biriktirilgan',
      'err_phone_change_failed': 'Telefon raqamni almashtirib bo\'lmadi',
      'err_phone_change_error': 'Telefon raqamni almashtirishda xatolik',
      'err_arizalar_load_failed': 'Arizalarni yuklab bo\'lmadi',
      'err_ariza_turlari_load_failed': 'Ariza turlarini yuklab bo\'lmadi',
      'err_ariza_submit_failed': 'Arizani yuborib bo\'lmadi',
      'ariza_earliest_date_note': ' (Eng erta sana: {date})',
      'err_ariza_submit_error': 'Arizani yuborishda xatolik',
      'ariza_cancelled_default': 'Ariza bekor qilindi',
      'err_ariza_cancel_failed': 'Arizani bekor qilib bo\'lmadi',
      'err_ariza_cancel_error': 'Arizani bekor qilishda xatolik',
      'update_notes_default_1': 'Yangi imkoniyatlar va yaxshilanishlar',
      'update_notes_default_2': 'Ilova tezligi va barqarorligi oshirildi',
      'notif_channel_attendance_name': 'Davomat eslatmalari',
      'notif_channel_attendance_desc':
          'Davomatdan o\'tish uchun maxsus ovozli bildirishnomalar',
      'notif_channel_review_name': 'So\'rov natijalari',
      'notif_channel_review_desc':
          'Qo\'lda belgilash so\'rovi tasdiqlangani yoki rad etilgani haqida',
      'notif_attendance_reminder_title': 'Davomat eslatmasi',
      'notif_attendance_reminder_body': 'Hurmatli xodim, davomatdan o\'ting!',
      'notif_test_title': 'Davomat eslatmasi (Sinov)',
      'notif_test_body':
          'Hurmatli xodim, davomatdan o\'tish vaqtiga 10 daqiqa qoldi.',
      'gps_channel_name': 'Skor GPS',
      'gps_channel_desc': 'Ish vaqti hisobi faol',
      'gps_notification_title': 'Skor — Davomat tizimi',
      'status_kelgan': 'Kelgan',
      'status_kelmagan': 'Kelmagan',
      'status_kutilmoqda': 'Kutilmoqda',
      'status_tasdiqlangan': 'Tasdiqlangan',
      'status_rad_etilgan': 'Rad etilgan',
      'status_kechikkan': 'Kechikkan',
      'ariza_type_javob_sorash': 'Javob so\'rash',
      'ariza_type_tatil': 'Ta\'til',
      'ariza_type_kasallik': 'Kasallik',
      'ariza_type_xizmat_safari': 'Xizmat safari',
      'ariza_type_sababsiz': 'Sababsiz',
      'ariza_type_boshqa': 'Boshqa',
      'duration_hours_mins': '{hours} soat {mins} minut',
      'duration_hours': '{hours} soat',
      'duration_mins': '{mins} minut',
      'notif_default_title': 'Bildirishnoma',

      // Profile
      'profile_title': 'Profil',
      'phone_number': 'Telefon raqam',
      'organization': 'Tashkilot',
      'position': 'Lavozim',
      'department': 'Bo\'lim',
      'shift': 'Smena',
      'work_days': 'Ish kunlari',
      'face_verify': 'Yuz tasdiqlash (HikCentral)',
      'face_configured': 'Sozlangan (Faol)',
      'face_not_configured': 'Sozlanmagan',
      'app_version': 'Ilova versiyasi',
      'app_language': 'Ilova tili',
      'select_language': 'Tilni tanlang',
      'select_language_desc': 'O\'zingizga qulay tilni tanlang',
      'logout': 'Tizimdan chiqish',
      'logout_confirmation_title': 'Chiqishni tasdiqlang',
      'logout_confirmation_desc':
          'Haqiqatan ham hisobingizdan chiqmoqchimisiz?',
      'camera_photo': 'Kamera orqali rasmga olish',
      'gallery_photo': 'Galereyadan tanlash',
      'photo_uploading': 'Rasm yuklanmoqda...',
      'phone_updating': 'Telefon raqam yangilanmoqda...',
      'profile_loading': 'Profil yuklanmoqda...',
      'photo_picker_error': 'Rasm tanlashda xatolik',
      'latest_version_installed': 'Sizda eng so\'nggi versiya o\'rnatilgan',
      'refresh': 'Yangilash',
      'user': 'Foydalanuvchi',

      // Weekdays Full
      'weekday_mon': 'Dushanba',
      'weekday_tue': 'Seshanba',
      'weekday_wed': 'Chorshanba',
      'weekday_thu': 'Payshanba',
      'weekday_fri': 'Juma',
      'weekday_sat': 'Shanba',
      'weekday_sun': 'Yakshanba',

      // Weekdays Short
      'weekday_short_mon': 'Dush',
      'weekday_short_tue': 'Sesh',
      'weekday_short_wed': 'Chor',
      'weekday_short_thu': 'Pay',
      'weekday_short_fri': 'Jum',
      'weekday_short_sat': 'Shan',
      'weekday_short_sun': 'Yak',

      // Weekdays Mini
      'weekday_mini_mon': 'Du',
      'weekday_mini_tue': 'Se',
      'weekday_mini_wed': 'Ch',
      'weekday_mini_thu': 'Pa',
      'weekday_mini_fri': 'Ju',
      'weekday_mini_sat': 'Sh',
      'weekday_mini_sun': 'Ya',

      // Common & Actions
      'cancel': 'Bekor qilish',
      'save': 'Saqlash',
      'close': 'Yopish',
      'confirm': 'Tasdiqlash',
      'retry': 'Qayta urinish',
      'error': 'Xatolik',
      'success': 'Muvaffaqiyatli',
      'today': 'Bugun',
      'everyday_7': 'Har kuni (7 kunlik)',
      'days_format': '{count} kunlik',
      'single_day_format': '{day} (1 kun)',
    },
    'ru': {
      // Navigation
      'nav_home': 'Главная',
      'nav_history': 'История',
      'nav_applications': 'Заявки',
      'nav_profile': 'Профиль',

      // Login
      'login_logout_reason_elsewhere':
          'Вход в ваш аккаунт был выполнен с другого устройства. Чтобы продолжить, войдите снова.',
      'login_session_expired':
          'Срок действия сессии истёк. Пожалуйста, войдите снова.',
      'login_enter_phone': 'Введите номер телефона',
      'login_phone_length_error': 'Номер должен состоять из 9 цифр',
      'login_enter_credentials': 'Введите логин и пароль',
      'login_person_code_title': 'Введите ваш системный номер',
      'login_person_code_hint': 'Например: 31632',
      'login_person_code_note':
          'Этот номер вам сообщит ваш руководитель или администратор.',
      'login_continue': 'Продолжить',
      'login_contact_us': 'Связаться с нами',
      'login_contact_desc':
          'Чтобы получить помощь или информацию по входу в систему, позвоните по номеру ниже:',
      'login_welcome': 'Добро пожаловать!',
      'login_select_type': 'Выберите тип входа в систему',
      'login_no_account': 'Нет аккаунта? ',
      'login_phone_label': 'Номер пользователя',
      'login_submit': 'Войти',
      'login_admin_login_label': 'Логин руководителя',
      'login_admin_login_hint': 'rahbar@tashkilot.uz',
      'login_password_label': 'Пароль',
      'login_admin_submit': 'Войти как руководитель',
      'login_role_staff': 'Сотрудник',
      'login_role_admin': 'Руководитель',

      // Home
      'attendance_check_in_label': 'Приход',
      'attendance_check_out_label': 'Уход',
      'home_greeting_named': 'Здравствуйте, {name}!',
      'home_greeting': 'Здравствуйте!',
      'home_today_date': 'Сегодняшняя дата: {date}',
      'home_today_attendance_time': 'Время посещения сегодня: {time}',
      'home_currently_working': 'Сейчас на работе',
      'home_not_working': 'Сейчас не на работе',
      'home_delay_label': 'Опоздание: {delay}',
      'home_pending_request':
          'Ваш запрос на "{label}" ожидает подтверждения руководителя',
      'home_sent_at': 'Отправлено: {date}',
      'home_timeline_title': 'Время посещения',
      'home_events_count': '{count} действия',
      'home_check_in_title': 'Приход на работу',
      'home_check_in_recorded': 'Время прихода зафиксировано',
      'home_check_in_not_recorded': 'Время прихода ещё не отмечено',
      'home_check_out_title': 'Уход с работы',
      'home_check_out_recorded': 'Время ухода зафиксировано',
      'home_check_out_not_recorded': 'Время ухода ещё не отмечено',

      // Check-in
      'checkin_user_not_found':
          'Пользователь не найден. Пожалуйста, войдите в систему заново.',
      'checkin_confirm_checkin_title': 'Подтверждение прихода',
      'checkin_confirm_checkout_title': 'Подтверждение ухода',
      'checkin_incomplete_data': 'Данные неполные. Попробуйте снова.',
      'checkin_verifying_face': 'Ваше лицо проверяется...',
      'checkin_verifying_location': 'Проверяется местоположение...',
      'checkin_marked_by_location':
          'Отмечено по местоположению (без проверки лица)',
      'checkin_saved_successfully': 'Успешно сохранено!',
      'checkin_face_not_matched': 'Ваше лицо не совпало. Попробуйте снова.',
      'checkin_face_invalid_ref':
          'Ваше фото в базе повреждено. Обратитесь к руководителю организации.',
      'checkin_face_photo_missing':
          'В системе нет вашего фото. Обратитесь к руководителю.',
      'checkin_face_verify_error': 'Произошла ошибка при проверке лица.',
      'checkin_too_far_km': 'Вы находитесь в {km} км от места работы.',
      'checkin_get_closer_m':
          'Подойдите ближе к месту работы — осталось {meters} метров.',
      'checkin_outside_zone_distance':
          'Вы находитесь за пределами разрешённой зоны.\nРасстояние: {distance}',
      'checkin_outside_zone': 'Вы находитесь за пределами разрешённой зоны.',
      'checkin_save_error': 'Произошла ошибка при сохранении посещаемости.',
      'checkin_pending_review_sent':
          'Ваш запрос отправлен руководителю, ожидается подтверждение.',
      'checkin_pending_review_id':
          'Номер запроса: {id}. После подтверждения руководителем посещаемость '
          'будет зафиксирована.',
      'checkin_pending_review_note':
          'После подтверждения руководителем посещаемость будет зафиксирована.',
      'checkin_already_recorded': 'Уже зафиксировано: {time}',
      'checkin_already_recorded_generic': 'Эта посещаемость уже зафиксирована.',
      'checkin_recorded_success': 'Успешно зафиксировано: {time}',
      'generic_error_retry': 'Произошла ошибка. Попробуйте снова.',
      'checkin_back_to_main': 'Вернуться на главную',
      'checkin_no_photo_title': 'Ваше фото не загружено',
      'checkin_no_photo_desc':
          'Для проверки по лицу в системе должно быть ваше фото. Пожалуйста, '
          'обратитесь к своему руководителю.\n\n'
          'Пока вы можете отметиться по местоположению — в этом случае '
          'посещаемость будет зафиксирована после подтверждения руководителем.',
      'checkin_mark_by_location': 'Отметиться по местоположению',
      'checkin_engine_down': 'Проверка лица временно не работает.',
      'checkin_engine_down_desc':
          'Без проверки лица вы можете продолжить только по местоположению.',
      'checkin_slide_to_checkin': 'Проведите, чтобы отметить приход',
      'checkin_slide_to_checkout': 'Проведите, чтобы отметить уход',
      'checkin_confirmed_in': 'Я пришёл',
      'checkin_confirmed_out': 'Я ушёл',

      // Attendance card
      'attendance_details': 'Подробнее',
      'attendance_present': 'Присутствовал',
      'attendance_absent': 'Отсутствовал',
      'attendance_sessions_summary':
          '{sessions} раз(а) вход-выход · {events} записей',
      'attendance_open_sessions': '{count} не закрыто',
      'attendance_sessions_title': 'Сессии (пары вход-выход):',
      'attendance_session_minutes': '{minutes} мин.',
      'attendance_session_open': 'Незакрытая сессия',
      'attendance_events_title': 'Все записи (действия турникета/приложения):',
      'attendance_event_in': 'Вошёл',
      'attendance_event_out': 'Вышел',

      // Select organization / Splash
      'select_org_title': 'Выберите организацию',
      'splash_tagline': 'Система управления сотрудниками',

      // Applications
      'no': 'Нет',
      'ariza_cancel_title': 'Отменить заявку',
      'ariza_cancel_confirm': 'Отменить заявку «{name}» ({date})?',
      'ariza_cancel_yes': 'Да, отменить',
      'applications_title': 'Мои заявки',
      'ariza_tab_all': 'Все',
      'ariza_tab_pending': 'В ожидании',
      'ariza_tab_approved': 'Одобрено',
      'ariza_tab_rejected': 'Отклонено',
      'ariza_new': 'Новая заявка',
      'ariza_empty_title': 'В этой категории заявок нет',
      'ariza_empty_desc': 'По выбранной категории заявки не найдены.',
      'no_internet_title': 'Нет подключения к интернету',
      'error_occurred_title': 'Произошла ошибка',
      'ariza_form_date_range_info':
          'Заявку можно оформить только на даты в пределах последних 30 дней '
          'и на будущие даты.',
      'ariza_form_missing_fields':
          'Пожалуйста, выберите тип заявки и хотя бы дату начала',
      'ariza_form_invalid_date_range':
          'Дата окончания не может быть раньше даты начала',
      'ariza_form_submitted_success': 'Ваша заявка успешно отправлена',
      'ariza_form_type_label': 'Тип заявки',
      'ariza_form_type_hint': 'Выберите тип заявки',
      'ariza_form_start_date_label': 'Дата начала',
      'ariza_form_end_date_label': 'Дата окончания',
      'ariza_form_pick_date': 'Выберите дату',
      'ariza_form_optional': 'Необязательно',
      'ariza_form_duration': 'Продолжительность: {days} дн.',
      'ariza_form_reason_label': 'Комментарий / Причина (необязательно)',
      'ariza_form_reason_hint': 'Напишите причину заявки...',
      'ariza_form_submit': 'Отправить заявку',
      'ariza_sheet_title': 'Отправить новую заявку',
      'ariza_sheet_date_range_info':
          'Заявка оформляется только на даты в пределах последних 30 дней и '
          'будущие даты.',
      'ariza_sheet_reason_label': 'Причина / Комментарий (необязательно)',
      'ariza_sheet_reason_hint':
          'Опишите цель командировки или причину заявки...',
      'ariza_sheet_submit': 'Отправить заявку',
      'ariza_sheet_submitted_success':
          'Ваша заявка успешно отправлена. Ожидайте подтверждения.',
      'ariza_card_days_count': '{days} дн.',
      'ariza_card_comment': 'Комментарий: {text}',
      'ariza_card_review_note': 'Причина / Комментарий: {text}',

      // Notifications
      'notif_just_now': 'Только что',
      'notif_minutes_ago': '{minutes} мин. назад',
      'notif_today_at': 'Сегодня, {time}',
      'notif_yesterday_at': 'Вчера, {time}',
      'notif_all_marked_read': 'Все уведомления прочитаны',
      'notif_clear_all_title': 'Удалить всё',
      'notif_clear_all_confirm': 'Очистить все уведомления?',
      'notif_clear': 'Очистить',
      'notif_go_to_attendance': 'Перейти к посещаемости',
      'notif_delete': 'Удалить',
      'notif_title': 'Уведомления',
      'notif_mark_all_read': 'Отметить все как прочитанные',
      'notif_clear_all_menu': 'Очистить все',
      'notif_filter_all': 'Все',
      'notif_filter_attendance': 'Посещаемость',
      'notif_filter_system': 'Система',
      'notif_empty_title': 'Нет уведомлений',
      'notif_empty_desc':
          'Здесь будут отображаться напоминания о посещаемости и системные '
          'сообщения.',
      'attendance_history_title': 'История посещаемости',
      'attendance_tab_week': 'Неделя',
      'attendance_tab_month': 'Месяц',
      'attendance_tab_year': 'Год',
      'attendance_history_empty_title': 'За этот период нет записей',
      'attendance_history_empty_desc':
          'За выбранный период записей о приходе-уходе не найдено.',

      // Rahbar dashboard
      'rahbar_logout_title': 'Выход из кабинета руководителя',
      'rahbar_logout_confirm':
          'Выйти из системы и вернуться на страницу входа?',
      'rahbar_logout_yes': 'Да, выйти',
      'rahbar_dashboard_title': 'Кабинет руководителя',
      'rahbar_logout_tooltip': 'Выйти',
      'rahbar_today_stats': 'Сегодняшние показатели',
      'rahbar_date_stats': 'Показатели за {date}',
      'rahbar_no_data_notice': 'На эту дату нет записей о посещаемости.',
      'rahbar_no_data_notice_with_last':
          'На эту дату нет записей о посещаемости (последняя запись: {date}).',
      'rahbar_kpi_late': 'Опоздали',
      'rahbar_review_applications': 'Рассмотреть заявки',
      'rahbar_pending_ariza_count': '{count} заявок ожидают подтверждения',
      'rahbar_new_arizalar': 'Новые заявки',
      'rahbar_view_all_count': 'Все ({count}) →',
      'rahbar_staff_fallback': 'Сотрудник',
      'rahbar_ariza_fallback': 'Заявка',
      'rahbar_ariza_summary': '{turi} · {days} дн.',
      'rahbar_late_section_title': 'Опоздавшие',
      'rahbar_no_late_in_branch': 'В этом филиале опоздавших нет',
      'rahbar_delay_minutes': '+{minutes} мин.',
      'rahbar_department_fallback': 'Отдел',
      'rahbar_departments_attendance': 'Посещаемость по отделам',
      'rahbar_load_failed': 'Не удалось загрузить данные',
      'rahbar_delay_hours_mins': 'Опоздание на {hours} ч {mins} мин',
      'rahbar_delay_hours': 'Опоздание на {hours} ч',
      'rahbar_delay_mins': 'Опоздание на {mins} мин',
      'rahbar_delay_raw': 'Опоздание на {delay}',
      'rahbar_filter_kelganlar': 'Пришедшие',
      'rahbar_filter_kelmaganlar': 'Отсутствующие',
      'rahbar_kundalik_title': 'Дневная посещаемость',
      'rahbar_prev_day': 'Предыдущий день',
      'rahbar_next_day': 'Следующий день',
      'rahbar_search_hint': 'Имя, отдел или должность...',
      'rahbar_search_no_staff': 'По запросу "{query}" сотрудники не найдены',
      'rahbar_filter_no_data': 'Нет данных по категории «{filter}»',
      'rahbar_try_different_search': 'Попробуйте изменить поисковый запрос',
      'rahbar_no_staff_on_date':
          'На {date} сотрудников в этой категории не найдено',
      'rahbar_entry_label': 'Приход',
      'rahbar_exit_label': 'Уход',
      'rahbar_at_work_short': 'На работе',
      'rahbar_hours_worked': '{hours} ч',
      'rahbar_currently_at_work_inside': 'Сейчас на месте (внутри)',
      'rahbar_nav_home': 'Главная',
      'rahbar_nav_reports': 'Отчёты',
      'rahbar_nav_map': 'Карта',
      'rahbar_nav_payroll': 'Бухгалтерия',
      'rahbar_report_kundalik_title': 'Дневная посещаемость',
      'rahbar_report_kundalik_desc': 'Один день — построчно по сотрудникам',
      'rahbar_report_xodimlar_title': 'Посещаемость сотрудников',
      'rahbar_report_xodimlar_desc': 'Сводный отчёт за период',
      'rahbar_report_kunlik_title': 'Ежедневная посещаемость',
      'rahbar_report_kunlik_desc': 'Общий процент за каждый день',
      'rahbar_report_qoldiruvchilar_title': 'Часто отсутствующие',
      'rahbar_report_qoldiruvchilar_desc': 'Наибольшее число пропусков',
      'rahbar_report_filial_title': 'Сотрудники филиала',
      'rahbar_report_filial_desc': 'В разрезе филиалов',
      'rahbar_no_data_in_range': 'За этот период нет данных',
      'rahbar_kunlik_summary':
          'Пришли: {present}/{total}  ·  Опоздали: {late}  ·  По заявке: {ariza}',
      'rahbar_kunlik_legend':
          'Цвет: 🟢 80% и выше   🟠 50–79%   🔴 ниже 50%',
      'rahbar_terminal_not_connected': 'Терминал ещё не подключён',
      'rahbar_no_data_this_date': 'На эту дату нет данных',
      'rahbar_no_attendance_data_generic':
          'Нет данных о посещаемости или запись не отправлена.',
      'rahbar_go_to_date': 'Перейти к {date}',
      'rahbar_no_absentees': 'Отсутствующих нет — всё в порядке 👍',
      'rahbar_absent_days_count': '{absent} / {total} дн.',
      'rahbar_payroll_title': 'Бухгалтерия / Зарплаты',
      'rahbar_payroll_empty_title': 'Нет данных о зарплате',
      'rahbar_payroll_empty_desc':
          'За этот месяц расчёты зарплаты сотрудников ещё не внесены',
      'rahbar_payroll_sum': '{amount} сум',
      'rahbar_payroll_days_present': 'Отработано дней: {days}',
      'rahbar_payroll_hours_worked': 'Отработано: {hours} ч',
      'rahbar_branches_not_found': 'Филиалы не найдены',
      'rahbar_branches_empty_desc': 'Пока нет данных ни по одному филиалу.',
      'rahbar_branch_fallback': 'Филиал',
      'rahbar_all_branches': 'Все',
      'rahbar_arrived_count': '{present} / {total} пришли',
      'rahbar_branch_no_staff': 'В этом филиале нет сотрудников',
      'rahbar_ariza_approve_title': 'Подтвердить заявку',
      'rahbar_ariza_reject_title': 'Отклонить заявку',
      'rahbar_ariza_confirm_approve':
          'Подтвердить заявку «{turi}» сотрудника {name}?',
      'rahbar_ariza_confirm_reject':
          'Отклонить заявку «{turi}» сотрудника {name}?',
      'rahbar_ariza_comment_hint':
          'Напишите комментарий / причину (необязательно)...',
      'rahbar_approve': 'Подтвердить',
      'rahbar_reject': 'Отклонить',
      'rahbar_arizalar_list_title': 'Список заявок',
      'rahbar_no_arizalar_title': 'Поступивших заявок нет',
      'rahbar_no_arizalar_desc':
          'От сотрудников не поступало заявок на подтверждение',
      'rahbar_ariza_type_days': 'Тип: {turi} · {days} дн.',
      'rahbar_ariza_date_range': 'Дата: {from} — {to}',
      'add_staff_fill_all_fields': 'Заполните все поля',
      'add_staff_title': 'Добавить сотрудника / ученика',
      'add_staff_success_desc':
          'Сотрудник: {name}\nНовый сотрудник успешно сохранён.',
      'ok': 'OK',
      'add_staff_search': 'Поиск',
      'add_staff_step2_title': 'Информация о должности',
      'add_staff_step3_title': 'Личные данные',
      'add_staff_surname_label': 'Фамилия (например: Эргашов / Эргашева)',
      'add_staff_surname_hint': 'Введите фамилию...',
      'add_staff_name_label': 'Имя',
      'add_staff_phone_label': 'Телефон',
      'add_staff_gender_label': 'Пол: ',
      'add_staff_male': 'Мужской',
      'add_staff_female': 'Женский',
      'add_staff_step4_title': 'Фото и завершение',
      'assign_zone_default_name_staff': '{name} — Рабочая зона',
      'assign_zone_default_name_new': 'Новый филиал (рабочая зона)',
      'assign_zone_name_required': 'Пожалуйста, введите название рабочей зоны',
      'assign_zone_saved_success':
          '✅ Рабочая зона «{name}» ({radius}м) успешно сохранена!',
      'assign_zone_error': 'Ошибка: {error}',
      'assign_zone_title': 'Обозначить рабочую зону',
      'assign_zone_staff_label': 'Сотрудник: {name}',
      'assign_zone_instruction':
          'Нажмите на точку на карте — вокруг неё будет очерчена круговая зона',
      'assign_zone_name_field_label': 'Название зоны / филиала',
      'assign_zone_radius_label': 'Радиус зоны:',
      'assign_zone_radius_value': '{radius} м',
      'assign_zone_saving': 'Сохранение...',
      'assign_zone_save_button': 'Сохранить и привязать зону',
      'rahbar_call': 'Позвонить',
      'rahbar_period_label': 'Период: {from} — {to}',
      'rahbar_attendance_percent': '{percent}% посещаемость',
      'rahbar_attendance_metrics_title': 'Показатели посещаемости',
      'rahbar_kpi_days_present_title': 'Дни присутствия',
      'rahbar_kpi_days_absent_title': 'Дни отсутствия',
      'rahbar_kpi_days_late_title': 'Дни опозданий',
      'rahbar_kpi_days_leave_title': 'По заявке / уважительно',
      'rahbar_kpi_hours_total_title': 'Всего отработано',
      'rahbar_kpi_delay_total_title': 'Всего опозданий',
      'rahbar_hours_mins_short': '{hours} ч {mins} мин',
      'rahbar_minutes_plain': '{mins} мин',
      'rahbar_search_staff_name': 'Поиск по имени сотрудника...',
      'rahbar_data_not_found': 'Данные не найдены',
      'rahbar_no_staff_data_period':
          'За этот период нет данных о посещаемости сотрудников',
      'rahbar_on_leave_short': 'По заявке',
      'rahbar_main_office': 'Главный офис',
      'rahbar_time_ago': '{time} ({min} мин назад)',
      'rahbar_badge_at_work': 'На работе',
      'rahbar_badge_left': 'Ушёл',
      'rahbar_badge_outside': 'Снаружи',
      'rahbar_checkin_time_label': 'Время прихода',
      'rahbar_checkout_time_label': 'Время ухода',
      'rahbar_status_label': 'Статус',
      'rahbar_assign_zone_button': 'Назначить новую рабочую зону',
      'rahbar_view_route_button': 'Посмотреть маршрут на карте',
      'rahbar_map_title': 'Местоположение сотрудников',
      'rahbar_new_zone_button': 'Новая зона',
      'rahbar_live_badge': 'ОНЛАЙН',
      'rahbar_total_count': 'Всего: {count}',
      'rahbar_inside_count': 'На работе: {count}',
      'rahbar_outside_count': 'Снаружи: {count}',
      'rahbar_route_label': 'Маршрут: {name}',
      'rahbar_search_staff_plural': 'Поиск сотрудников...',
      'offline_reconnected': 'Подключение к интернету восстановлено!',
      'offline_still_no_internet':
          'Интернета всё ещё нет. Пожалуйста, проверьте подключение.',
      'offline_title': 'Нет подключения к интернету',
      'offline_desc':
          'Для работы приложения Skor Xodimlar, отметки посещаемости и '
          'синхронизации данных требуется интернет.',
      'offline_tip_wifi': 'Проверьте, включён ли Wi-Fi или мобильный интернет',
      'offline_tip_balance':
          'Убедитесь, что на балансе есть мегабайты или средства',
      'offline_tip_airplane': 'Проверьте, что режим полёта выключен',
      'offline_tip_vpn': 'Если включён VPN, попробуйте временно его отключить',
      'offline_understood': 'Понятно',
      'offline_checking': 'Проверка...',
      'offline_recheck': 'Проверить снова',
      'location_disclosure_title': 'Использование данных о местоположении',
      'location_disclosure_statement':
          'Приложение «Skor Xodimlar» собирает данные о местоположении '
          '(геолокацию), чтобы в реальном времени фиксировать нахождение '
          'сотрудников на территории в рабочее время и вести мониторинг '
          'посещаемости. Эти данные могут собираться даже когда приложение '
          'закрыто или не используется (в фоновом режиме).',
      'location_feature_time_title': 'Контроль рабочего времени и посещаемости',
      'location_feature_time_desc':
          'Время прихода и ухода с территории организации рассчитывается '
          'автоматически.',
      'location_feature_privacy_title': 'Конфиденциальность и безопасность',
      'location_feature_privacy_desc':
          'Данные о местоположении используются только в системе работодателя, '
          'не передаются третьим лицам и не используются в рекламных целях.',
      'location_accept': 'Понятно, согласен(на)',
      'location_decline': 'Не сейчас (Отклонить)',
      'bg_location_disclosure_title': 'Доступ к местоположению в фоновом режиме',
      'bg_location_disclosure_statement':
          'Приложение «Skor Xodimlar» собирает данные о местоположении, '
          'даже когда приложение закрыто или не используется (в фоновом режиме), '
          'для автоматического учета рабочего времени и контроля нахождения '
          'сотрудника на рабочем месте.\n\n'
          'Для включения этой функции в следующем окне настроек '
          'выберите «Разрешать в любом режиме».',
      'bg_location_open_settings': 'Перейти в настройки',
      'bg_location_cancel': 'Не сейчас (Отклонить)',
      'no_internet_default_message':
          'Не удалось загрузить данные. Проверьте подключение к сети и '
          'попробуйте снова.',
      'no_internet_reload': 'Загрузить заново',
      'no_internet_tips_tooltip': 'Советы',
      'app_update_default_title': 'Обновите приложение',
      'app_update_default_desc':
          'Пожалуйста, обновите приложение до последней версии, чтобы '
          'пользоваться всеми функциями.',
      'app_update_button': 'Обновить',
      'app_update_later': 'Позже',
      'offline_banner_restored_title': 'Интернет-соединение восстановлено',
      'offline_banner_offline_title': 'Нет подключения к интернету',
      'offline_banner_restored_desc': 'Соединение с системой восстановлено',
      'offline_banner_offline_desc': 'Проверьте подключение к сети',
      'selfie_position_face': 'Разместите лицо внутри круга',
      'selfie_camera_permission_denied': 'Доступ к камере не предоставлен',
      'selfie_camera_not_found': 'Камера не найдена',
      'selfie_camera_open_failed': 'Не удалось открыть камеру',
      'selfie_face_not_detected': 'Лицо не обнаружено',
      'selfie_only_one_face': 'В кадре должно быть только одно лицо',
      'selfie_come_closer': 'Подойдите ближе',
      'selfie_move_back': 'Отойдите немного назад',
      'selfie_hold_still': 'Держите неподвижно...',
      'selfie_blink_once': 'Моргните один раз',
      'selfie_capturing': 'Идёт съёмка...',
      'selfie_capture_error': 'Ошибка при съёмке',
      'selfie_permission_denied_desc':
          'Доступ к камере не предоставлен.\nПожалуйста, разрешите доступ в '
          'настройках.',
      'selfie_camera_unavailable': 'Камера недоступна',
      'selfie_open_settings': 'Открыть настройки',
      'selfie_close_eyes': 'Закройте и откройте глаза',
      'selfie_hold_in_circle': 'Держите лицо внутри круга',

      // Error formatter (non-widget layers — blocs/repositories/datasources)
      'err_unknown': 'Произошла неизвестная ошибка. Попробуйте снова.',
      'err_connection_timeout':
          'Истекло время подключения к серверу. Проверьте интернет и '
          'попробуйте снова.',
      'err_receive_timeout':
          'Сервер не ответил. Пожалуйста, попробуйте немного позже.',
      'err_connection_error':
          'Нет подключения к интернету, или сеть слишком медленная. '
          'Проверьте соединение.',
      'err_cancelled': 'Действие отменено.',
      'err_bad_certificate': 'Ошибка при установке безопасного соединения.',
      'err_status_400': 'Отправлен некорректный запрос.',
      'err_status_401': 'Сессия истекла. Пожалуйста, войдите снова.',
      'err_status_403': 'Нет разрешения на выполнение этого действия.',
      'err_status_404': 'Данные или сервис не найдены.',
      'err_status_405': 'Связь с сервером прервана. Попробуйте снова.',
      'err_status_413':
          'Загружаемый файл или изображение слишком большое. Попробуйте '
          'снова.',
      'err_status_419': 'Ключ безопасности устарел. Попробуйте снова.',
      'err_status_422': 'Введённые данные некорректны.',
      'err_status_429':
          'Слишком много запросов. Пожалуйста, подождите немного.',
      'err_status_500':
          'На сервере временная ошибка. Попробуйте немного позже.',
      'err_status_5xx': 'На сервере проводятся технические работы.',
      'err_status_unknown': 'Ошибка связи с сервером ({code}).',
      'err_unknown_code': 'неизвестно',
      'err_image_too_large':
          'Размер изображения слишком большой. Сделайте снимок заново.',
      'err_network_socket':
          'Нет подключения к интернету, или сеть медленная. Проверьте '
          'соединение.',
      'err_timeout_generic':
          'Время ожидания ответа сервера истекло. Попробуйте снова.',
      'err_server_crash':
          'На сервере временная неполадка. Попробуйте немного позже.',
      'err_user_not_found': 'Пользователь не найден. Войдите в систему заново.',
      'err_too_many_requests':
          'Отправлено слишком много запросов. Пожалуйста, подождите.',
      'err_validation': 'В введённых данных есть ошибка.',
      'err_no_face':
          'Лицо не обнаружено. Расположите лицо перед экраном и сделайте '
          'снимок заново.',
      'err_format': 'Неполадка в данных сервера. Попробуйте снова.',
      'err_unexpected':
          'Произошла непредвиденная ошибка. Пожалуйста, перезапустите '
          'приложение.',
      'err_html_page':
          'На сервере проводятся технические работы. Попробуйте немного '
          'позже.',
      'err_generic': 'Произошла ошибка. Пожалуйста, попробуйте снова.',
      'err_phone_not_registered': 'Этот номер не зарегистрирован в системе',
      'err_phone_ambiguous_badge':
          'Этот номер привязан к нескольким сотрудникам. Введите свой '
          'системный номер (бейдж).',
      'err_phone_ambiguous_blocked':
          'Этот номер привязан к нескольким сотрудникам. Вход временно '
          'приостановлен — обратитесь к администратору.',
      'err_request_truncated':
          'Проблема с интернет-соединением — запрос не дошёл до сервера '
          'полностью. Подключитесь к Wi-Fi или перезапустите мобильный '
          'интернет и попробуйте снова.',
      'err_invalid_phone_format': 'Неверный формат номера телефона',
      'err_server_generic': 'Ошибка на сервере. Попробуйте немного позже',
      'err_no_internet': 'Нет подключения к интернету',
      'err_could_not_connect': 'Не удалось подключиться к серверу.',
      'face_verify_success': 'Успешно',
      'face_verify_no_match':
          'Ваше лицо не совпало. Пожалуйста, проверьте себя и попробуйте '
          'снова.',
      'face_verify_ref_invalid':
          'Ваше фото в базе повреждено. Обратитесь к администратору.',
      'face_verify_face_not_visible':
          'Ваше лицо не видно. Расположите лицо внутри рамки.',
      'face_verify_photo_missing':
          'У вас не загружено фото. Обратитесь к администратору.',
      'face_verify_timeout':
          'Сервер не ответил. Попробуйте снова через некоторое время.',
      'face_verify_not_configured':
          'Служба распознавания лиц не настроена. Обратитесь к '
          'администратору.',
      'face_verify_unavailable':
          'Служба временно не работает. Попробуйте позже.',
      'err_empty_image': 'Пустое фото. Сделайте снимок заново.',
      'err_connection_lost':
          'Связь с сервером прервана. Пожалуйста, попробуйте снова.',
      'err_server_action_failed': 'Произошла ошибка сервера',
      'err_attendance_failed': 'Ошибка при отметке посещаемости',
      'err_profile_load_failed': 'Ошибка при загрузке данных профиля',
      'err_profile_load_could_not': 'Не удалось загрузить данные профиля',
      'err_photo_upload_failed': 'Произошла ошибка при загрузке фото',
      'err_photo_upload_could_not': 'Не удалось загрузить фото',
      'profile_phone_updated': 'Номер телефона обновлён',
      'err_phone_duplicate': 'Этот номер уже закреплён за другим сотрудником',
      'err_phone_change_failed': 'Не удалось изменить номер телефона',
      'err_phone_change_error': 'Ошибка при изменении номера телефона',
      'err_arizalar_load_failed': 'Не удалось загрузить заявления',
      'err_ariza_turlari_load_failed': 'Не удалось загрузить типы заявлений',
      'err_ariza_submit_failed': 'Не удалось отправить заявление',
      'ariza_earliest_date_note': ' (Самая ранняя дата: {date})',
      'err_ariza_submit_error': 'Ошибка при отправке заявления',
      'ariza_cancelled_default': 'Заявление отменено',
      'err_ariza_cancel_failed': 'Не удалось отменить заявление',
      'err_ariza_cancel_error': 'Ошибка при отмене заявления',
      'update_notes_default_1': 'Новые возможности и улучшения',
      'update_notes_default_2': 'Повышена скорость и стабильность приложения',
      'notif_channel_attendance_name': 'Напоминания о посещаемости',
      'notif_channel_attendance_desc':
          'Специальные звуковые уведомления для отметки посещаемости',
      'notif_channel_review_name': 'Результаты запроса',
      'notif_channel_review_desc':
          'Об одобрении или отклонении запроса на ручную отметку',
      'notif_attendance_reminder_title': 'Напоминание о посещаемости',
      'notif_attendance_reminder_body':
          'Уважаемый сотрудник, пожалуйста, отметьте посещаемость!',
      'notif_test_title': 'Напоминание о посещаемости (Тест)',
      'notif_test_body':
          'Уважаемый сотрудник, до отметки посещаемости осталось 10 минут.',
      'gps_channel_name': 'Skor GPS',
      'gps_channel_desc': 'Учёт рабочего времени активен',
      'gps_notification_title': 'Skor — Система посещаемости',
      'status_kelgan': 'Пришёл',
      'status_kelmagan': 'Не пришёл',
      'status_kutilmoqda': 'Ожидается',
      'status_tasdiqlangan': 'Одобрено',
      'status_rad_etilgan': 'Отклонено',
      'status_kechikkan': 'Опоздал',
      'ariza_type_javob_sorash': 'Отпроситься',
      'ariza_type_tatil': 'Отпуск',
      'ariza_type_kasallik': 'Больничный',
      'ariza_type_xizmat_safari': 'Командировка',
      'ariza_type_sababsiz': 'Без причины',
      'ariza_type_boshqa': 'Другое',
      'duration_hours_mins': '{hours} ч {mins} мин',
      'duration_hours': '{hours} ч',
      'duration_mins': '{mins} мин',
      'notif_default_title': 'Уведомление',

      // Profile
      'profile_title': 'Профиль',
      'phone_number': 'Номер телефона',
      'organization': 'Организация',
      'position': 'Должность',
      'department': 'Отдел',
      'shift': 'Смена',
      'work_days': 'Рабочие дни',
      'face_verify': 'Распознавание лица (HikCentral)',
      'face_configured': 'Настроено (Активно)',
      'face_not_configured': 'Не настроено',
      'app_version': 'Версия приложения',
      'app_language': 'Язык приложения',
      'select_language': 'Выберите язык',
      'select_language_desc': 'Выберите удобный язык для работы с приложением',
      'logout': 'Выйти из системы',
      'logout_confirmation_title': 'Подтверждение выхода',
      'logout_confirmation_desc':
          'Вы действительно хотите выйти из своего аккаунта?',
      'camera_photo': 'Сделать снимок камерой',
      'gallery_photo': 'Выбрать из галереи',
      'photo_uploading': 'Загрузка фото...',
      'phone_updating': 'Обновление номера телефона...',
      'profile_loading': 'Загрузка профиля...',
      'photo_picker_error': 'Ошибка при выборе фото',
      'latest_version_installed': 'У вас установлена последняя версия',
      'refresh': 'Обновить',
      'user': 'Пользователь',

      // Weekdays Full
      'weekday_mon': 'Понедельник',
      'weekday_tue': 'Вторник',
      'weekday_wed': 'Среда',
      'weekday_thu': 'Четверг',
      'weekday_fri': 'Пятница',
      'weekday_sat': 'Суббота',
      'weekday_sun': 'Воскресенье',

      // Weekdays Short
      'weekday_short_mon': 'Пнд',
      'weekday_short_tue': 'Втр',
      'weekday_short_wed': 'Срд',
      'weekday_short_thu': 'Чтв',
      'weekday_short_fri': 'Птн',
      'weekday_short_sat': 'Сбт',
      'weekday_short_sun': 'Вск',

      // Weekdays Mini
      'weekday_mini_mon': 'Пн',
      'weekday_mini_tue': 'Вт',
      'weekday_mini_wed': 'Ср',
      'weekday_mini_thu': 'Чт',
      'weekday_mini_fri': 'Пт',
      'weekday_mini_sat': 'Сб',
      'weekday_mini_sun': 'Вс',

      // Common & Actions
      'cancel': 'Отмена',
      'save': 'Сохранить',
      'close': 'Закрыть',
      'confirm': 'Подтвердить',
      'retry': 'Повторить',
      'error': 'Ошибка',
      'success': 'Успешно',
      'today': 'Сегодня',
      'everyday_7': 'Каждый день (7 дней)',
      'days_format': '{count}-дневный',
      'single_day_format': '{day} (1 день)',
    },
    'en': {
      // Navigation
      'nav_home': 'Home',
      'nav_history': 'History',
      'nav_applications': 'Applications',
      'nav_profile': 'Profile',

      // Login
      'login_logout_reason_elsewhere':
          'Your account was signed in from another device. Please sign in again to continue.',
      'login_session_expired':
          'Your session has expired. Please sign in again.',
      'login_enter_phone': 'Enter your phone number',
      'login_phone_length_error': 'The number must be 9 digits',
      'login_enter_credentials': 'Enter login and password',
      'login_person_code_title': 'Enter your system (badge) number',
      'login_person_code_hint': 'e.g. 31632',
      'login_person_code_note':
          'Your manager or administrator will tell you this number.',
      'login_continue': 'Continue',
      'login_contact_us': 'Contact us',
      'login_contact_desc':
          'For help or information about signing in, call the number below:',
      'login_welcome': 'Welcome!',
      'login_select_type': 'Select your login type',
      'login_no_account': 'Don\'t have an account? ',
      'login_phone_label': 'User phone number',
      'login_submit': 'Log in',
      'login_admin_login_label': 'Manager login',
      'login_admin_login_hint': 'rahbar@tashkilot.uz',
      'login_password_label': 'Password',
      'login_admin_submit': 'Log in as manager',
      'login_role_staff': 'Staff',
      'login_role_admin': 'Manager',

      // Home
      'attendance_check_in_label': 'Check-in',
      'attendance_check_out_label': 'Check-out',
      'home_greeting_named': 'Hello, {name}!',
      'home_greeting': 'Hello!',
      'home_today_date': 'Today\'s date: {date}',
      'home_today_attendance_time': 'Today\'s attendance time: {time}',
      'home_currently_working': 'Currently at work',
      'home_not_working': 'Not at work',
      'home_delay_label': 'Delay: {delay}',
      'home_pending_request':
          'Your {label} request is awaiting manager approval',
      'home_sent_at': 'Sent: {date}',
      'home_timeline_title': 'Attendance time',
      'home_events_count': '{count} events',
      'home_check_in_title': 'Arrival at work',
      'home_check_in_recorded': 'Check-in time recorded',
      'home_check_in_not_recorded': 'Check-in time not yet recorded',
      'home_check_out_title': 'Departure from work',
      'home_check_out_recorded': 'Check-out time recorded',
      'home_check_out_not_recorded': 'Check-out time not yet recorded',

      // Check-in
      'checkin_user_not_found': 'User not found. Please sign in again.',
      'checkin_confirm_checkin_title': 'Confirm check-in',
      'checkin_confirm_checkout_title': 'Confirm check-out',
      'checkin_incomplete_data': 'Data is incomplete. Please try again.',
      'checkin_verifying_face': 'Verifying your face...',
      'checkin_verifying_location': 'Verifying location...',
      'checkin_marked_by_location':
          'Marked by location (without face verification)',
      'checkin_saved_successfully': 'Successfully saved!',
      'checkin_face_not_matched': 'Your face didn\'t match. Please try again.',
      'checkin_face_invalid_ref':
          'Your photo on file is invalid. Please contact your organization\'s '
          'manager.',
      'checkin_face_photo_missing':
          'Your photo isn\'t in the system. Please contact your manager.',
      'checkin_face_verify_error':
          'An error occurred while verifying your face.',
      'checkin_too_far_km': 'You are {km} km away from your workplace.',
      'checkin_get_closer_m':
          'Get closer to your workplace — {meters} meters left.',
      'checkin_outside_zone_distance':
          'You are outside the allowed zone.\nDistance: {distance}',
      'checkin_outside_zone': 'You are outside the allowed zone.',
      'checkin_save_error': 'An error occurred while saving attendance.',
      'checkin_pending_review_sent':
          'Your request has been sent to your manager and is awaiting approval.',
      'checkin_pending_review_id':
          'Request number: {id}. Attendance will be recorded once your manager '
          'approves.',
      'checkin_pending_review_note':
          'Attendance will be recorded once your manager approves.',
      'checkin_already_recorded': 'Already recorded: {time}',
      'checkin_already_recorded_generic':
          'This attendance has already been recorded.',
      'checkin_recorded_success': 'Successfully recorded: {time}',
      'generic_error_retry': 'An error occurred. Please try again.',
      'checkin_back_to_main': 'Back to home',
      'checkin_no_photo_title': 'No photo uploaded for you',
      'checkin_no_photo_desc':
          'Your photo needs to be in the system for face verification. Please '
          'contact your manager.\n\n'
          'For now, you can mark attendance by location — in that case it will '
          'be recorded after your manager\'s approval.',
      'checkin_mark_by_location': 'Mark by location',
      'checkin_engine_down': 'Face verification is temporarily unavailable.',
      'checkin_engine_down_desc':
          'Without face verification, you can only proceed by location.',
      'checkin_slide_to_checkin': 'Slide to check in',
      'checkin_slide_to_checkout': 'Slide to check out',
      'checkin_confirmed_in': 'Checked in',
      'checkin_confirmed_out': 'Checked out',

      // Attendance card
      'attendance_details': 'Details',
      'attendance_present': 'Present',
      'attendance_absent': 'Absent',
      'attendance_sessions_summary': '{sessions} sessions · {events} events',
      'attendance_open_sessions': '{count} unclosed',
      'attendance_sessions_title': 'Sessions (check-in/check-out pairs):',
      'attendance_session_minutes': '{minutes} min',
      'attendance_session_open': 'Unclosed session',
      'attendance_events_title': 'All events (turnstile/app actions):',
      'attendance_event_in': 'Entered',
      'attendance_event_out': 'Exited',

      // Select organization / Splash
      'select_org_title': 'Select organization',
      'splash_tagline': 'Staff Management System',

      // Applications
      'no': 'No',
      'ariza_cancel_title': 'Cancel application',
      'ariza_cancel_confirm': 'Cancel the "{name}" ({date}) application?',
      'ariza_cancel_yes': 'Yes, cancel it',
      'applications_title': 'My applications',
      'ariza_tab_all': 'All',
      'ariza_tab_pending': 'Pending',
      'ariza_tab_approved': 'Approved',
      'ariza_tab_rejected': 'Rejected',
      'ariza_new': 'New application',
      'ariza_empty_title': 'No applications in this category',
      'ariza_empty_desc': 'No applications found for the selected category.',
      'no_internet_title': 'No internet connection',
      'error_occurred_title': 'An error occurred',
      'ariza_form_date_range_info':
          'Applications can only be submitted for dates within the last 30 '
          'days or in the future.',
      'ariza_form_missing_fields':
          'Please select an application type and at least a start date',
      'ariza_form_invalid_date_range':
          'The end date cannot be before the start date',
      'ariza_form_submitted_success':
          'Your application was submitted successfully',
      'ariza_form_type_label': 'Application type',
      'ariza_form_type_hint': 'Select application type',
      'ariza_form_start_date_label': 'Start date',
      'ariza_form_end_date_label': 'End date',
      'ariza_form_pick_date': 'Pick a date',
      'ariza_form_optional': 'Optional',
      'ariza_form_duration': 'Duration: {days} days',
      'ariza_form_reason_label': 'Comment / Reason (optional)',
      'ariza_form_reason_hint': 'Write the reason for the application...',
      'ariza_form_submit': 'Submit application',
      'ariza_sheet_title': 'Submit new application',
      'ariza_sheet_date_range_info':
          'Applications are recorded only for dates within the last 30 days '
          'or in the future.',
      'ariza_sheet_reason_label': 'Reason / Comment (optional)',
      'ariza_sheet_reason_hint':
          'Write the purpose of the trip or the reason for the application...',
      'ariza_sheet_submit': 'Submit application',
      'ariza_sheet_submitted_success':
          'Your application was submitted successfully. Await approval.',
      'ariza_card_days_count': '{days} days',
      'ariza_card_comment': 'Comment: {text}',
      'ariza_card_review_note': 'Reason / Comment: {text}',

      // Notifications
      'notif_just_now': 'Just now',
      'notif_minutes_ago': '{minutes} minutes ago',
      'notif_today_at': 'Today, {time}',
      'notif_yesterday_at': 'Yesterday, {time}',
      'notif_all_marked_read': 'All notifications marked as read',
      'notif_clear_all_title': 'Clear all',
      'notif_clear_all_confirm': 'Clear all notifications?',
      'notif_clear': 'Clear',
      'notif_go_to_attendance': 'Go to attendance',
      'notif_delete': 'Delete',
      'notif_title': 'Notifications',
      'notif_mark_all_read': 'Mark all as read',
      'notif_clear_all_menu': 'Clear all',
      'notif_filter_all': 'All',
      'notif_filter_attendance': 'Attendance',
      'notif_filter_system': 'System',
      'notif_empty_title': 'No notifications',
      'notif_empty_desc':
          'Attendance reminders and system messages will appear here.',
      'attendance_history_title': 'Attendance history',
      'attendance_tab_week': 'Week',
      'attendance_tab_month': 'Month',
      'attendance_tab_year': 'Year',
      'attendance_history_empty_title': 'No attendance records for this period',
      'attendance_history_empty_desc':
          'No check-in/check-out records found for the selected period.',

      // Rahbar dashboard
      'rahbar_logout_title': 'Log out of manager cabinet',
      'rahbar_logout_confirm': 'Log out and return to the login screen?',
      'rahbar_logout_yes': 'Yes, log out',
      'rahbar_dashboard_title': 'Manager Cabinet',
      'rahbar_logout_tooltip': 'Log out',
      'rahbar_today_stats': 'Today\'s stats',
      'rahbar_date_stats': 'Stats for {date}',
      'rahbar_no_data_notice': 'No attendance records for this date.',
      'rahbar_no_data_notice_with_last':
          'No attendance records for this date (last record: {date}).',
      'rahbar_kpi_late': 'Late',
      'rahbar_review_applications': 'Review applications',
      'rahbar_pending_ariza_count': '{count} applications awaiting approval',
      'rahbar_new_arizalar': 'New applications',
      'rahbar_view_all_count': 'All ({count}) →',
      'rahbar_staff_fallback': 'Staff',
      'rahbar_ariza_fallback': 'Application',
      'rahbar_ariza_summary': '{turi} · {days} days',
      'rahbar_late_section_title': 'Late arrivals',
      'rahbar_no_late_in_branch': 'No late arrivals in this branch',
      'rahbar_delay_minutes': '+{minutes} min',
      'rahbar_department_fallback': 'Department',
      'rahbar_departments_attendance': 'Attendance by department',
      'rahbar_load_failed': 'Could not load data',
      'rahbar_delay_hours_mins': '{hours}h {mins}m late',
      'rahbar_delay_hours': '{hours}h late',
      'rahbar_delay_mins': '{mins} min late',
      'rahbar_delay_raw': '{delay} late',
      'rahbar_filter_kelganlar': 'Present',
      'rahbar_filter_kelmaganlar': 'Absent',
      'rahbar_kundalik_title': 'Daily Attendance',
      'rahbar_prev_day': 'Previous day',
      'rahbar_next_day': 'Next day',
      'rahbar_search_hint': 'Name, department or position...',
      'rahbar_search_no_staff': 'No staff found for "{query}"',
      'rahbar_filter_no_data': 'No data for "{filter}"',
      'rahbar_try_different_search': 'Try a different search term',
      'rahbar_no_staff_on_date': 'No staff found in this category on {date}',
      'rahbar_entry_label': 'Entry',
      'rahbar_exit_label': 'Exit',
      'rahbar_at_work_short': 'At work',
      'rahbar_hours_worked': '{hours}h',
      'rahbar_currently_at_work_inside': 'Currently at the workplace (inside)',
      'rahbar_nav_home': 'Home',
      'rahbar_nav_reports': 'Reports',
      'rahbar_nav_map': 'Map',
      'rahbar_nav_payroll': 'Payroll',
      'rahbar_report_kundalik_title': 'Daily attendance',
      'rahbar_report_kundalik_desc': 'One day — row per staff member',
      'rahbar_report_xodimlar_title': 'Staff attendance',
      'rahbar_report_xodimlar_desc': 'Summary report for a period',
      'rahbar_report_kunlik_title': 'Day-by-day attendance',
      'rahbar_report_kunlik_desc': 'Overall percentage for each day',
      'rahbar_report_qoldiruvchilar_title': 'Frequent absentees',
      'rahbar_report_qoldiruvchilar_desc': 'Most absences',
      'rahbar_report_filial_title': 'Branch staff',
      'rahbar_report_filial_desc': 'Broken down by branch',
      'rahbar_no_data_in_range': 'No data in this range',
      'rahbar_kunlik_summary':
          'Present: {present}/{total}  ·  Late: {late}  ·  On leave: {ariza}',
      'rahbar_kunlik_legend':
          'Color: 🟢 80% and above   🟠 50–79%   🔴 below 50%',
      'rahbar_terminal_not_connected': 'Terminal not yet connected',
      'rahbar_no_data_this_date': 'No data for this date',
      'rahbar_no_attendance_data_generic':
          'No attendance data, or nothing was submitted.',
      'rahbar_go_to_date': 'Go to {date}',
      'rahbar_no_absentees': 'No frequent absentees — all good 👍',
      'rahbar_absent_days_count': '{absent} / {total} days',
      'rahbar_payroll_title': 'Payroll / Salaries',
      'rahbar_payroll_empty_title': 'No salary data',
      'rahbar_payroll_empty_desc':
          'Staff salary calculations haven\'t been entered for this month yet',
      'rahbar_payroll_sum': '{amount} UZS',
      'rahbar_payroll_days_present': 'Days present: {days}',
      'rahbar_payroll_hours_worked': 'Worked: {hours}h',
      'rahbar_branches_not_found': 'No branches found',
      'rahbar_branches_empty_desc': 'No branch data is available yet.',
      'rahbar_branch_fallback': 'Branch',
      'rahbar_all_branches': 'All',
      'rahbar_arrived_count': '{present} / {total} present',
      'rahbar_branch_no_staff': 'No staff in this branch',
      'rahbar_ariza_approve_title': 'Approve application',
      'rahbar_ariza_reject_title': 'Reject application',
      'rahbar_ariza_confirm_approve': 'Approve {name}\'s "{turi}" application?',
      'rahbar_ariza_confirm_reject': 'Reject {name}\'s "{turi}" application?',
      'rahbar_ariza_comment_hint': 'Write a comment / reason (optional)...',
      'rahbar_approve': 'Approve',
      'rahbar_reject': 'Reject',
      'rahbar_arizalar_list_title': 'Applications List',
      'rahbar_no_arizalar_title': 'No incoming applications',
      'rahbar_no_arizalar_desc':
          'No applications have been submitted by staff for approval',
      'rahbar_ariza_type_days': 'Type: {turi} · {days} days',
      'rahbar_ariza_date_range': 'Date: {from} — {to}',
      'add_staff_fill_all_fields': 'Fill in all fields',
      'add_staff_title': 'Add staff / student',
      'add_staff_success_desc':
          'Staff: {name}\nNew staff member saved successfully.',
      'ok': 'OK',
      'add_staff_search': 'Search',
      'add_staff_step2_title': 'Position details',
      'add_staff_step3_title': 'Personal details',
      'add_staff_surname_label': 'Surname (e.g. Ergashov / Ergasheva)',
      'add_staff_surname_hint': 'Enter surname...',
      'add_staff_name_label': 'First name',
      'add_staff_phone_label': 'Phone',
      'add_staff_gender_label': 'Gender: ',
      'add_staff_male': 'Male',
      'add_staff_female': 'Female',
      'add_staff_step4_title': 'Photo and finish',
      'assign_zone_default_name_staff': '{name} — Work zone',
      'assign_zone_default_name_new': 'New branch (work zone)',
      'assign_zone_name_required': 'Please enter the work zone name',
      'assign_zone_saved_success':
          '✅ Work zone "{name}" ({radius}m) saved successfully!',
      'assign_zone_error': 'Error: {error}',
      'assign_zone_title': 'Mark work zone',
      'assign_zone_staff_label': 'Staff: {name}',
      'assign_zone_instruction':
          'Tap a spot on the map — a circular zone will be drawn around it',
      'assign_zone_name_field_label': 'Zone / branch name',
      'assign_zone_radius_label': 'Radius:',
      'assign_zone_radius_value': '{radius} m',
      'assign_zone_saving': 'Saving...',
      'assign_zone_save_button': 'Save and assign zone',
      'rahbar_call': 'Call',
      'rahbar_period_label': 'Period: {from} — {to}',
      'rahbar_attendance_percent': '{percent}% attendance',
      'rahbar_attendance_metrics_title': 'Attendance metrics',
      'rahbar_kpi_days_present_title': 'Days present',
      'rahbar_kpi_days_absent_title': 'Days absent',
      'rahbar_kpi_days_late_title': 'Days late',
      'rahbar_kpi_days_leave_title': 'On leave',
      'rahbar_kpi_hours_total_title': 'Total worked',
      'rahbar_kpi_delay_total_title': 'Total delay',
      'rahbar_hours_mins_short': '{hours}h {mins}m',
      'rahbar_minutes_plain': '{mins} min',
      'rahbar_search_staff_name': 'Search staff by name...',
      'rahbar_data_not_found': 'No data found',
      'rahbar_no_staff_data_period': 'No staff attendance data for this period',
      'rahbar_on_leave_short': 'On leave',
      'rahbar_main_office': 'Head Office',
      'rahbar_time_ago': '{time} ({min} min ago)',
      'rahbar_badge_at_work': 'At work',
      'rahbar_badge_left': 'Left',
      'rahbar_badge_outside': 'Outside',
      'rahbar_checkin_time_label': 'Check-in time',
      'rahbar_checkout_time_label': 'Check-out time',
      'rahbar_status_label': 'Status',
      'rahbar_assign_zone_button': 'Assign new work zone to staff',
      'rahbar_view_route_button': 'View route on in-app map',
      'rahbar_map_title': 'Staff Location',
      'rahbar_new_zone_button': 'New zone',
      'rahbar_live_badge': 'LIVE',
      'rahbar_total_count': 'Total: {count}',
      'rahbar_inside_count': 'At work: {count}',
      'rahbar_outside_count': 'Outside: {count}',
      'rahbar_route_label': 'Route: {name}',
      'rahbar_search_staff_plural': 'Search staff...',
      'offline_reconnected': 'Internet connection restored!',
      'offline_still_no_internet':
          'Still no internet. Please check your connection.',
      'offline_title': 'No internet connection',
      'offline_desc':
          'The Skor Xodimlar app needs internet to run, record attendance, '
          'and sync data.',
      'offline_tip_wifi': 'Check that Wi-Fi or mobile data is turned on',
      'offline_tip_balance':
          'Make sure you have data/balance available on your plan',
      'offline_tip_airplane': 'Check that Airplane mode is off',
      'offline_tip_vpn': 'If VPN is on, try turning it off temporarily',
      'offline_understood': 'Got it',
      'offline_checking': 'Checking...',
      'offline_recheck': 'Check again',
      'location_disclosure_title': 'Use of location data',
      'location_disclosure_statement':
          'The "Skor Xodimlar" app collects location (geolocation) data to '
          'record, in real time, whether staff are on-site during work hours '
          'and to maintain attendance monitoring. This data may be collected '
          'even when the app is closed or not in use (in the background).',
      'location_feature_time_title': 'Work-hours and attendance tracking',
      'location_feature_time_desc':
          'Arrival and departure times at the organization\'s site are '
          'calculated automatically.',
      'location_feature_privacy_title': 'Privacy and security',
      'location_feature_privacy_desc':
          'Location data is used only within the employer\'s system, is not '
          'shared with third parties, and is not used for advertising.',
      'location_accept': 'I understand and agree',
      'location_decline': 'Not now (Decline)',
      'bg_location_disclosure_title': 'Background Location Access',
      'bg_location_disclosure_statement':
          'The "Skor Xodimlar" app collects location data even when the app is '
          'closed or not in use (in the background) to automatically monitor '
          'working hours and verify attendance within the organization\'s premises.\n\n'
          'To enable this, please select "Allow all the time" in the next settings screen.',
      'bg_location_open_settings': 'Continue to Settings',
      'bg_location_cancel': 'Not now (Decline)',
      'no_internet_default_message':
          'Could not load the data. Check your connection and try again.',
      'no_internet_reload': 'Reload',
      'no_internet_tips_tooltip': 'Tips',
      'app_update_default_title': 'Update the app',
      'app_update_default_desc':
          'Please update the app to the latest version to use all features.',
      'app_update_button': 'Update',
      'app_update_later': 'Later',
      'offline_banner_restored_title': 'Internet connection restored',
      'offline_banner_offline_title': 'No internet connection',
      'offline_banner_restored_desc': 'System connection re-established',
      'offline_banner_offline_desc': 'Check your network connection',
      'selfie_position_face': 'Position your face inside the circle',
      'selfie_camera_permission_denied': 'Camera permission not granted',
      'selfie_camera_not_found': 'Camera not found',
      'selfie_camera_open_failed': 'Could not open the camera',
      'selfie_face_not_detected': 'Face not detected',
      'selfie_only_one_face': 'Only one face should be visible',
      'selfie_come_closer': 'Come closer',
      'selfie_move_back': 'Move back a bit',
      'selfie_hold_still': 'Hold still...',
      'selfie_blink_once': 'Blink once',
      'selfie_capturing': 'Capturing...',
      'selfie_capture_error': 'Error taking the photo',
      'selfie_permission_denied_desc':
          'Camera access was not granted.\nPlease allow it in settings.',
      'selfie_camera_unavailable': 'Camera unavailable',
      'selfie_open_settings': 'Open settings',
      'selfie_close_eyes': 'Close and open your eyes',
      'selfie_hold_in_circle': 'Hold your face inside the circle',

      // Error formatter (non-widget layers — blocs/repositories/datasources)
      'err_unknown': 'An unknown error occurred. Please try again.',
      'err_connection_timeout':
          'Connection to the server timed out. Check your internet and try '
          'again.',
      'err_receive_timeout':
          'The server did not respond. Please try again shortly.',
      'err_connection_error':
          'You\'re not connected to the internet, or the network is too '
          'slow. Check your connection.',
      'err_cancelled': 'Action cancelled.',
      'err_bad_certificate':
          'An error occurred establishing a secure connection.',
      'err_status_400': 'An invalid request was sent.',
      'err_status_401': 'Your session has expired. Please sign in again.',
      'err_status_403': 'You don\'t have permission to perform this action.',
      'err_status_404': 'The data or service was not found.',
      'err_status_405': 'Connection to the server was lost. Please try again.',
      'err_status_413':
          'The file or image being uploaded is too large. Please try again.',
      'err_status_419': 'Security key expired. Please try again.',
      'err_status_422': 'The submitted data was invalid.',
      'err_status_429': 'Too many requests. Please wait a moment.',
      'err_status_500':
          'A temporary server error occurred. Please try again shortly.',
      'err_status_5xx': 'The server is undergoing maintenance.',
      'err_status_unknown': 'An error occurred contacting the server ({code}).',
      'err_unknown_code': 'unknown',
      'err_image_too_large': 'The photo is too large. Please retake it.',
      'err_network_socket':
          'You\'re not connected to the internet, or the network is slow. '
          'Check your connection.',
      'err_timeout_generic':
          'The server took too long to respond. Please try again.',
      'err_server_crash':
          'A temporary server issue occurred. Please try again shortly.',
      'err_user_not_found': 'User not found. Please sign in again.',
      'err_too_many_requests':
          'Too many requests were sent. Please wait a moment.',
      'err_validation': 'There is an error in the submitted data.',
      'err_no_face':
          'Face not detected. Position your face on screen and retake the '
          'photo.',
      'err_format':
          'There was an issue with the server data. Please try again.',
      'err_unexpected': 'An unexpected error occurred. Please restart the app.',
      'err_html_page':
          'The server is undergoing maintenance. Please try again shortly.',
      'err_generic': 'An error occurred. Please try again.',
      'err_phone_not_registered': 'This number is not registered in the system',
      'err_phone_ambiguous_badge':
          'This number is linked to multiple staff members. Enter your '
          'system (badge) number.',
      'err_phone_ambiguous_blocked':
          'This number is linked to multiple staff members. Sign-in is '
          'temporarily blocked — contact your administrator.',
      'err_request_truncated':
          'There\'s an internet connection problem — the request didn\'t '
          'fully reach the server. Connect to Wi-Fi or toggle mobile data '
          'and try again.',
      'err_invalid_phone_format': 'Invalid phone number format',
      'err_server_generic': 'Server error. Please try again shortly',
      'err_no_internet': 'You\'re not connected to the internet',
      'err_could_not_connect': 'Could not connect to the server.',
      'face_verify_success': 'Success',
      'face_verify_no_match':
          'Your face didn\'t match. Please check yourself and try again.',
      'face_verify_ref_invalid':
          'Your reference photo is invalid. Please contact the admin.',
      'face_verify_face_not_visible':
          'Your face wasn\'t visible. Position your face inside the frame.',
      'face_verify_photo_missing':
          'No photo has been uploaded for you. Please contact the admin.',
      'face_verify_timeout':
          'The server didn\'t respond. Please try again shortly.',
      'face_verify_not_configured':
          'The face verification service isn\'t configured. Please contact '
          'the admin.',
      'face_verify_unavailable':
          'The service is temporarily unavailable. Please try again later.',
      'err_empty_image': 'The photo is empty. Please retake it.',
      'err_connection_lost':
          'Connection to the server was lost. Please try again.',
      'err_server_action_failed': 'A server error occurred',
      'err_attendance_failed': 'An error occurred while marking attendance',
      'err_profile_load_failed': 'Error loading profile data',
      'err_profile_load_could_not': 'Could not load profile data',
      'err_photo_upload_failed': 'An error occurred while uploading the photo',
      'err_photo_upload_could_not': 'Could not upload the photo',
      'profile_phone_updated': 'Phone number updated',
      'err_phone_duplicate':
          'This number is already assigned to another staff member',
      'err_phone_change_failed': 'Could not change the phone number',
      'err_phone_change_error': 'Error changing the phone number',
      'err_arizalar_load_failed': 'Could not load applications',
      'err_ariza_turlari_load_failed': 'Could not load application types',
      'err_ariza_submit_failed': 'Could not submit the application',
      'ariza_earliest_date_note': ' (Earliest date: {date})',
      'err_ariza_submit_error': 'Error submitting the application',
      'ariza_cancelled_default': 'Application cancelled',
      'err_ariza_cancel_failed': 'Could not cancel the application',
      'err_ariza_cancel_error': 'Error cancelling the application',
      'update_notes_default_1': 'New features and improvements',
      'update_notes_default_2': 'Improved app speed and stability',
      'notif_channel_attendance_name': 'Attendance reminders',
      'notif_channel_attendance_desc':
          'Special sound notifications for marking attendance',
      'notif_channel_review_name': 'Request results',
      'notif_channel_review_desc':
          'Whether a manual marking request was approved or rejected',
      'notif_attendance_reminder_title': 'Attendance reminder',
      'notif_attendance_reminder_body':
          'Dear staff member, please mark your attendance!',
      'notif_test_title': 'Attendance reminder (Test)',
      'notif_test_body':
          'Dear staff member, 10 minutes remain to mark attendance.',
      'gps_channel_name': 'Skor GPS',
      'gps_channel_desc': 'Work-time tracking active',
      'gps_notification_title': 'Skor — Attendance system',
      'status_kelgan': 'Present',
      'status_kelmagan': 'Absent',
      'status_kutilmoqda': 'Pending',
      'status_tasdiqlangan': 'Approved',
      'status_rad_etilgan': 'Rejected',
      'status_kechikkan': 'Late',
      'ariza_type_javob_sorash': 'Permission / Leave',
      'ariza_type_tatil': 'Vacation',
      'ariza_type_kasallik': 'Sick leave',
      'ariza_type_xizmat_safari': 'Business trip',
      'ariza_type_sababsiz': 'Unexcused',
      'ariza_type_boshqa': 'Other',
      'duration_hours_mins': '{hours}h {mins}m',
      'duration_hours': '{hours}h',
      'duration_mins': '{mins}m',
      'notif_default_title': 'Notification',

      // Profile
      'profile_title': 'Profile',
      'phone_number': 'Phone number',
      'organization': 'Organization',
      'position': 'Position',
      'department': 'Department',
      'shift': 'Shift',
      'work_days': 'Work days',
      'face_verify': 'Face verification (HikCentral)',
      'face_configured': 'Configured (Active)',
      'face_not_configured': 'Not configured',
      'app_version': 'App version',
      'app_language': 'App language',
      'select_language': 'Select language',
      'select_language_desc': 'Choose your preferred language',
      'logout': 'Log out',
      'logout_confirmation_title': 'Confirm log out',
      'logout_confirmation_desc':
          'Are you sure you want to log out of your account?',
      'camera_photo': 'Take photo with camera',
      'gallery_photo': 'Choose from gallery',
      'photo_uploading': 'Uploading photo...',
      'phone_updating': 'Updating phone number...',
      'profile_loading': 'Loading profile...',
      'photo_picker_error': 'Error selecting photo',
      'latest_version_installed': 'You have the latest version installed',
      'refresh': 'Refresh',
      'user': 'User',

      // Weekdays Full
      'weekday_mon': 'Monday',
      'weekday_tue': 'Tuesday',
      'weekday_wed': 'Wednesday',
      'weekday_thu': 'Thursday',
      'weekday_fri': 'Friday',
      'weekday_sat': 'Saturday',
      'weekday_sun': 'Sunday',

      // Weekdays Short
      'weekday_short_mon': 'Mon',
      'weekday_short_tue': 'Tue',
      'weekday_short_wed': 'Wed',
      'weekday_short_thu': 'Thu',
      'weekday_short_fri': 'Fri',
      'weekday_short_sat': 'Sat',
      'weekday_short_sun': 'Sun',

      // Weekdays Mini
      'weekday_mini_mon': 'Mo',
      'weekday_mini_tue': 'Tu',
      'weekday_mini_wed': 'We',
      'weekday_mini_thu': 'Th',
      'weekday_mini_fri': 'Fr',
      'weekday_mini_sat': 'Sa',
      'weekday_mini_sun': 'Su',

      // Common & Actions
      'cancel': 'Cancel',
      'save': 'Save',
      'close': 'Close',
      'confirm': 'Confirm',
      'retry': 'Retry',
      'error': 'Error',
      'success': 'Success',
      'today': 'Today',
      'everyday_7': 'Every day (7 days)',
      'days_format': '{count} days',
      'single_day_format': '{day} (1 day)',
    },
    'ky': {
      // Navigation
      'nav_home': 'Башкы',
      'nav_history': 'Тарых',
      'nav_applications': 'Арыздар',
      'nav_profile': 'Профиль',

      // Login
      'login_logout_reason_elsewhere':
          'Аккаунтуңузга башка түзмөктөн кирилди. Улантуу үчүн кайра кириңиз.',
      'login_session_expired':
          'Сессиянын мөөнөтү бүттү. Сураныч, кайра кириңиз.',
      'login_enter_phone': 'Телефон номериңизди киргизиңиз',
      'login_phone_length_error': 'Номер 9 орундуу болушу керек',
      'login_enter_credentials': 'Логин жана сырсөздү киргизиңиз',
      'login_person_code_title': 'Система номериңизди киргизиңиз',
      'login_person_code_hint': 'Мисалы: 31632',
      'login_person_code_note':
          'Бул номерди жетекчиңиз же администратор айтат.',
      'login_continue': 'Улантуу',
      'login_contact_us': 'Биз менен байланышуу',
      'login_contact_desc':
          'Тутумга кирүү боюнча жардам же маалымат алуу үчүн төмөнкү номерге чалыңыз:',
      'login_welcome': 'Кош келиңиз!',
      'login_select_type': 'Тутумга кирүү түрүн тандаңыз',
      'login_no_account': 'Аккаунтуңуз жокпу? ',
      'login_phone_label': 'Колдонуучу номери',
      'login_submit': 'Кирүү',
      'login_admin_login_label': 'Жетекчинин логини',
      'login_admin_login_hint': 'rahbar@tashkilot.uz',
      'login_password_label': 'Сырсөз',
      'login_admin_submit': 'Жетекчи катары кирүү',
      'login_role_staff': 'Кызматкер',
      'login_role_admin': 'Жетекчи',

      // Home
      'attendance_check_in_label': 'Келүү',
      'attendance_check_out_label': 'Кетүү',
      'home_greeting_named': 'Ассалому алейкум, {name}!',
      'home_greeting': 'Ассалому алейкум!',
      'home_today_date': 'Бүгүнкү дата: {date}',
      'home_today_attendance_time': 'Бүгүнкү катышуу убактысы: {time}',
      'home_currently_working': 'Учурда жумушта',
      'home_not_working': 'Учурда жумушта эмес',
      'home_delay_label': 'Кечигүү: {delay}',
      'home_pending_request':
          '{label} сурооңуз жетекчинин тастыктоосун күтүүдө',
      'home_sent_at': 'Жиберилди: {date}',
      'home_timeline_title': 'Катышуу убактысы',
      'home_events_count': '{count} аракет',
      'home_check_in_title': 'Жумушка келүү',
      'home_check_in_recorded': 'Келүү убактысы катталды',
      'home_check_in_not_recorded': 'Келүү убактысы азырынча белгиленген жок',
      'home_check_out_title': 'Жумуштан кетүү',
      'home_check_out_recorded': 'Кетүү убактысы катталды',
      'home_check_out_not_recorded': 'Кетүү убактысы азырынча белгиленген жок',

      // Check-in
      'checkin_user_not_found':
          'Колдонуучу табылган жок. Сураныч, кайра кириңиз.',
      'checkin_confirm_checkin_title': 'Келүүнү тастыктоо',
      'checkin_confirm_checkout_title': 'Кетүүнү тастыктоо',
      'checkin_incomplete_data':
          'Маалыматтар толук эмес. Кайра аракет кылыңыз.',
      'checkin_verifying_face': 'Жүзүңүз текшерилүүдө...',
      'checkin_verifying_location': 'Жайгашкан жери текшерилүүдө...',
      'checkin_marked_by_location':
          'Жайгашкан жери боюнча белгиленди (жүздү текшерүүсүз)',
      'checkin_saved_successfully': 'Ийгиликтүү сакталды!',
      'checkin_face_not_matched':
          'Жүзүңүз дал келген жок. Кайра аракет кылыңыз.',
      'checkin_face_invalid_ref':
          'Базадагы сүрөтүңүз жараксыз. Уюмдун жетекчисине кайрылыңыз.',
      'checkin_face_photo_missing':
          'Тутумда сүрөтүңүз жок. Жетекчиге кайрылыңыз.',
      'checkin_face_verify_error': 'Жүздү текшерүүдө ката кетти.',
      'checkin_too_far_km': 'Сиз жумуш ордунан {km} км алыссыз.',
      'checkin_get_closer_m': 'Жумуш ордуна жакындаңыз — {meters} метр калды.',
      'checkin_outside_zone_distance':
          'Уруксат берилген аймактан тышкарыдасыз.\nАралык: {distance}',
      'checkin_outside_zone': 'Уруксат берилген аймактан тышкарыдасыз.',
      'checkin_save_error': 'Катышууну сактоодо ката кетти.',
      'checkin_pending_review_sent':
          'Сурооңуз жетекчиге жиберилди, тастыкталышы күтүлүүдө.',
      'checkin_pending_review_id':
          'Суроо номери: {id}. Жетекчи тастыктагандан кийин катышуу катталат.',
      'checkin_pending_review_note':
          'Жетекчи тастыктагандан кийин катышуу катталат.',
      'checkin_already_recorded': 'Мурунтан катталган: {time}',
      'checkin_already_recorded_generic': 'Бул катышуу мурунтан катталган.',
      'checkin_recorded_success': 'Ийгиликтүү катталды: {time}',
      'generic_error_retry': 'Ката кетти. Кайра аракет кылыңыз.',
      'checkin_back_to_main': 'Башкы бетке кайтуу',
      'checkin_no_photo_title': 'Сизге сүрөт жүктөлгөн эмес',
      'checkin_no_photo_desc':
          'Жүз аркылуу текшерүү үчүн тутумда сүрөтүңүз болушу керек. Сураныч, '
          'жетекчиңизге кайрылыңыз.\n\n'
          'Азырынча жайгашкан жери боюнча белгилей аласыз — бул учурда '
          'катышуу жетекчи тастыктагандан кийин катталат.',
      'checkin_mark_by_location': 'Жайгашкан жери боюнча белгилөө',
      'checkin_engine_down': 'Жүздү текшерүү убактылуу иштебейт.',
      'checkin_engine_down_desc':
          'Жүздү текшерүүсүз, сиз жалгыз жайгашкан жери боюнча улантсаңыз '
          'болот.',
      'checkin_slide_to_checkin': 'Катталуу үчүн сүрүңүз',
      'checkin_slide_to_checkout': 'Кетүү үчүн сүрүңүз',
      'checkin_confirmed_in': 'Келдим',
      'checkin_confirmed_out': 'Кеттим',

      // Attendance card
      'attendance_details': 'Толук маалымат',
      'attendance_present': 'Келген',
      'attendance_absent': 'Келген эмес',
      'attendance_sessions_summary':
          '{sessions} жолу кирип-чыккан · {events} жазуу',
      'attendance_open_sessions': '{count} жабылбаган',
      'attendance_sessions_title': 'Сессиялар (кирүү-чыгуу жуптары):',
      'attendance_session_minutes': '{minutes} мүнөт',
      'attendance_session_open': 'Жабылбаган сессия',
      'attendance_events_title':
          'Бардык жазуулар (турникет/колдонмо аракеттери):',
      'attendance_event_in': 'Кирди',
      'attendance_event_out': 'Чыкты',

      // Select organization / Splash
      'select_org_title': 'Уюмду тандаңыз',
      'splash_tagline': 'Кызматкерлерди башкаруу тутуму',

      // Applications
      'no': 'Жок',
      'ariza_cancel_title': 'Арызды жокко чыгаруу',
      'ariza_cancel_confirm': '{name} ({date}) арызын жокко чыгарасызбы?',
      'ariza_cancel_yes': 'Ооба, жокко чыгаруу',
      'applications_title': 'Менин арыздарым',
      'ariza_tab_all': 'Баары',
      'ariza_tab_pending': 'Күтүлүүдө',
      'ariza_tab_approved': 'Тастыкталды',
      'ariza_tab_rejected': 'Четке кагылды',
      'ariza_new': 'Жаңы арыз',
      'ariza_empty_title': 'Бул категорияда арыз жок',
      'ariza_empty_desc': 'Тандалган категория боюнча арыз табылган жок.',
      'no_internet_title': 'Интернет байланышы жок',
      'error_occurred_title': 'Ката кетти',
      'ariza_form_date_range_info':
          'Арызды акыркы 30 күн ичиндеги жана келечектеги күндөргө гана '
          'жаза аласыз.',
      'ariza_form_missing_fields':
          'Сураныч, арыз түрүн жана жок дегенде башталыш күнүн тандаңыз',
      'ariza_form_invalid_date_range':
          'Аяктоо күнү башталыш күнүнөн мурда болушу мүмкүн эмес',
      'ariza_form_submitted_success': 'Арызыңыз ийгиликтүү жиберилди',
      'ariza_form_type_label': 'Арыз түрү',
      'ariza_form_type_hint': 'Арыз түрүн тандаңыз',
      'ariza_form_start_date_label': 'Башталыш күнү',
      'ariza_form_end_date_label': 'Аяктоо күнү',
      'ariza_form_pick_date': 'Күндү тандаңыз',
      'ariza_form_optional': 'Милдеттүү эмес',
      'ariza_form_duration': 'Узактыгы: {days} күн',
      'ariza_form_reason_label': 'Түшүндүрмө / Себеп (милдеттүү эмес)',
      'ariza_form_reason_hint': 'Арыздын себебин жазыңыз...',
      'ariza_form_submit': 'Арызды жөнөтүү',
      'ariza_sheet_title': 'Жаңы арыз жөнөтүү',
      'ariza_sheet_date_range_info':
          'Арыз акыркы 30 күн ичиндеги жана келечектеги күндөргө гана жазылат.',
      'ariza_sheet_reason_label': 'Себеп / Түшүндүрмө (милдеттүү эмес)',
      'ariza_sheet_reason_hint':
          'Иш сапарынын максатын же арыздын себебин жазыңыз...',
      'ariza_sheet_submit': 'Арызды жөнөтүү',
      'ariza_sheet_submitted_success':
          'Арызыңыз ийгиликтүү жиберилди. Тастыкталышын күтүңүз.',
      'ariza_card_days_count': '{days} күн',
      'ariza_card_comment': 'Түшүндүрмө: {text}',
      'ariza_card_review_note': 'Себеп / Түшүндүрмө: {text}',

      // Notifications
      'notif_just_now': 'Азыр эле',
      'notif_minutes_ago': '{minutes} мүнөт мурун',
      'notif_today_at': 'Бүгүн, {time}',
      'notif_yesterday_at': 'Кечээ, {time}',
      'notif_all_marked_read': 'Бардык билдирүүлөр окулду',
      'notif_clear_all_title': 'Баарын өчүрүү',
      'notif_clear_all_confirm': 'Бардык билдирүүлөрдү тазалагыңыз келеби?',
      'notif_clear': 'Тазалоо',
      'notif_go_to_attendance': 'Катышууга өтүү',
      'notif_delete': 'Өчүрүү',
      'notif_title': 'Билдирүүлөр',
      'notif_mark_all_read': 'Баарын окулду деп белгилөө',
      'notif_clear_all_menu': 'Баарын тазалоо',
      'notif_filter_all': 'Баары',
      'notif_filter_attendance': 'Катышуу',
      'notif_filter_system': 'Тутум',
      'notif_empty_title': 'Билдирүүлөр жок',
      'notif_empty_desc':
          'Катышуу эскертүүлөрү жана тутум билдирүүлөрү бул жерде көрүнөт.',
      'attendance_history_title': 'Катышуу тарыхы',
      'attendance_tab_week': 'Жума',
      'attendance_tab_month': 'Ай',
      'attendance_tab_year': 'Жыл',
      'attendance_history_empty_title': 'Бул мезгилде катышуу жазуусу жок',
      'attendance_history_empty_desc':
          'Тандалган мезгил үчүн кирүү-чыгуу жазуусу табылган жок.',

      // Rahbar dashboard
      'rahbar_logout_title': 'Жетекчи кабинетинен чыгуу',
      'rahbar_logout_confirm':
          'Тутумдан чыгып, кирүү бетине кайтууну каалайсызбы?',
      'rahbar_logout_yes': 'Ооба, чыгуу',
      'rahbar_dashboard_title': 'Жетекчи кабинети',
      'rahbar_logout_tooltip': 'Чыгуу',
      'rahbar_today_stats': 'Бүгүнкү көрсөткүчтөр',
      'rahbar_date_stats': '{date} көрсөткүчтөрү',
      'rahbar_no_data_notice': 'Бул күнгө катышуу жазуулары жок.',
      'rahbar_no_data_notice_with_last':
          'Бул күнгө катышуу жазуулары жок (акыркы жазуу: {date}).',
      'rahbar_kpi_late': 'Кечиккен',
      'rahbar_review_applications': 'Арыздарды кароо',
      'rahbar_pending_ariza_count': '{count} арыз тастыктоону күтүүдө',
      'rahbar_new_arizalar': 'Жаңы арыздар',
      'rahbar_view_all_count': 'Баары ({count}) →',
      'rahbar_staff_fallback': 'Кызматкер',
      'rahbar_ariza_fallback': 'Арыз',
      'rahbar_ariza_summary': '{turi} · {days} күн',
      'rahbar_late_section_title': 'Кечиккендер',
      'rahbar_no_late_in_branch': 'Бул филиалда кечиккендер жок',
      'rahbar_delay_minutes': '+{minutes} мүн',
      'rahbar_department_fallback': 'Бөлүм',
      'rahbar_departments_attendance': 'Бөлүмдөр боюнча катышуу',
      'rahbar_load_failed': 'Маалыматтарды жүктөп болбоду',
      'rahbar_delay_hours_mins': '{hours} саат {mins} мүн кечикти',
      'rahbar_delay_hours': '{hours} саат кечикти',
      'rahbar_delay_mins': '{mins} мүнөт кечикти',
      'rahbar_delay_raw': '{delay} кечикти',
      'rahbar_filter_kelganlar': 'Келгендер',
      'rahbar_filter_kelmaganlar': 'Келбегендер',
      'rahbar_kundalik_title': 'Күндөлүк катышуу',
      'rahbar_prev_day': 'Мурунку күн',
      'rahbar_next_day': 'Кийинки күн',
      'rahbar_search_hint': 'Аты, бөлүмү же кызматы...',
      'rahbar_search_no_staff': '"{query}" боюнча кызматкер табылган жок',
      'rahbar_filter_no_data': '{filter} боюнча маалымат жок',
      'rahbar_try_different_search': 'Издөө сөзүн өзгөртүп көрүңүз',
      'rahbar_no_staff_on_date':
          '{date} күнүндө бул категорияда кызматкерлер табылган жок',
      'rahbar_entry_label': 'Кирүү',
      'rahbar_exit_label': 'Чыгуу',
      'rahbar_at_work_short': 'Жумушта',
      'rahbar_hours_worked': '{hours} саат',
      'rahbar_currently_at_work_inside': 'Учурда жумуш ордунда (ичинде)',
      'rahbar_nav_home': 'Башкы бет',
      'rahbar_nav_reports': 'Отчёттор',
      'rahbar_nav_map': 'Карта',
      'rahbar_nav_payroll': 'Бухгалтерия',
      'rahbar_report_kundalik_title': 'Күндөлүк катышуу',
      'rahbar_report_kundalik_desc': 'Бир күн — ар бир кызматкер боюнча',
      'rahbar_report_xodimlar_title': 'Кызматкерлердин катышуусу',
      'rahbar_report_xodimlar_desc': 'Мезгил боюнча жыйынтык отчёт',
      'rahbar_report_kunlik_title': 'Күн сайынкы катышуу',
      'rahbar_report_kunlik_desc': 'Ар бир күн үчүн жалпы пайыз',
      'rahbar_report_qoldiruvchilar_title': 'Көп жок болгондор',
      'rahbar_report_qoldiruvchilar_desc': 'Эң көп келбегендер',
      'rahbar_report_filial_title': 'Филиал кызматкерлери',
      'rahbar_report_filial_desc': 'Филиал боюнча',
      'rahbar_no_data_in_range': 'Бул мезгилде маалымат жок',
      'rahbar_kunlik_summary':
          'Келгендер: {present}/{total}  ·  Кечиккендер: {late}  ·  Арыздуу: {ariza}',
      'rahbar_kunlik_legend':
          'Түс: 🟢 80% жана андан жогору   🟠 50–79%   🔴 50%дан төмөн',
      'rahbar_terminal_not_connected': 'Терминал азырынча туташкан эмес',
      'rahbar_no_data_this_date': 'Бул күнгө маалымат жок',
      'rahbar_no_attendance_data_generic':
          'Катышуу маалыматы жок же жазуу жиберилген эмес.',
      'rahbar_go_to_date': '{date} өтүү',
      'rahbar_no_absentees': 'Жок болгондор жок — баары жайында 👍',
      'rahbar_absent_days_count': '{absent} / {total} күн',
      'rahbar_payroll_title': 'Бухгалтерия / Айлыктар',
      'rahbar_payroll_empty_title': 'Айлык маалыматтары жок',
      'rahbar_payroll_empty_desc':
          'Бул ай үчүн кызматкерлердин айлык эсептери азырынча киргизилген жок',
      'rahbar_payroll_sum': '{amount} сум',
      'rahbar_payroll_days_present': 'Келген күндөр: {days} күн',
      'rahbar_payroll_hours_worked': 'Иштелген: {hours} саат',
      'rahbar_branches_not_found': 'Филиалдар табылган жок',
      'rahbar_branches_empty_desc': 'Азырынча бир да филиалдын маалыматы жок.',
      'rahbar_branch_fallback': 'Филиал',
      'rahbar_all_branches': 'Баары',
      'rahbar_arrived_count': '{present} / {total} келди',
      'rahbar_branch_no_staff': 'Бул филиалда кызматкерлер жок',
      'rahbar_ariza_approve_title': 'Арызды тастыктоо',
      'rahbar_ariza_reject_title': 'Арызды четке кагуу',
      'rahbar_ariza_confirm_approve':
          '{name} кызматкеринин "{turi}" арызын тастыктайсызбы?',
      'rahbar_ariza_confirm_reject':
          '{name} кызматкеринин "{turi}" арызын четке кагасызбы?',
      'rahbar_ariza_comment_hint':
          'Түшүндүрмө / себеп жазыңыз (милдеттүү эмес)...',
      'rahbar_approve': 'Тастыктоо',
      'rahbar_reject': 'Четке кагуу',
      'rahbar_arizalar_list_title': 'Арыздар тизмеси',
      'rahbar_no_arizalar_title': 'Келип түшкөн арыздар жок',
      'rahbar_no_arizalar_desc':
          'Кызматкерлерден тастыктоо үчүн жиберилген арыздар жок',
      'rahbar_ariza_type_days': 'Түрү: {turi} · {days} күн',
      'rahbar_ariza_date_range': 'Дата: {from} — {to}',
      'add_staff_fill_all_fields': 'Бардык талааларды толтуруңуз',
      'add_staff_title': 'Кызматкер / окуучу кошуу',
      'add_staff_success_desc':
          'Кызматкер: {name}\nЖаңы кызматкер ийгиликтүү сакталды.',
      'ok': 'OK',
      'add_staff_search': 'Издөө',
      'add_staff_step2_title': 'Кызмат маалыматтары',
      'add_staff_step3_title': 'Жеке маалыматтар',
      'add_staff_surname_label': 'Фамилия (мисалы: Эргашов / Эргашева)',
      'add_staff_surname_hint': 'Фамилияны киргизиңиз...',
      'add_staff_name_label': 'Аты',
      'add_staff_phone_label': 'Телефон',
      'add_staff_gender_label': 'Жынысы: ',
      'add_staff_male': 'Эркек',
      'add_staff_female': 'Аял',
      'add_staff_step4_title': 'Сүрөт жана аяктоо',
      'assign_zone_default_name_staff': '{name} — Жумуш аймагы',
      'assign_zone_default_name_new': 'Жаңы филиал (жумуш аймагы)',
      'assign_zone_name_required': 'Сураныч, жумуш аймагынын атын киргизиңиз',
      'assign_zone_saved_success':
          '✅ "{name}" жумуш аймагы ({radius}м) ийгиликтүү сакталды!',
      'assign_zone_error': 'Ката: {error}',
      'assign_zone_title': 'Жумуш аймагын белгилөө',
      'assign_zone_staff_label': 'Кызматкер: {name}',
      'assign_zone_instruction':
          'Картадан бир жерди басыңыз — тегерек аймак сызылат',
      'assign_zone_name_field_label': 'Аймак / филиал аты',
      'assign_zone_radius_label': 'Тегеректин радиусу:',
      'assign_zone_radius_value': '{radius} метр',
      'assign_zone_saving': 'Сакталууда...',
      'assign_zone_save_button': 'Аймакты сактоо жана бекитүү',
      'rahbar_call': 'Чалуу',
      'rahbar_period_label': 'Мезгил: {from} — {to}',
      'rahbar_attendance_percent': '{percent}% катышуу',
      'rahbar_attendance_metrics_title': 'Катышуу көрсөткүчтөрү',
      'rahbar_kpi_days_present_title': 'Келген күндөр',
      'rahbar_kpi_days_absent_title': 'Келбеген күндөр',
      'rahbar_kpi_days_late_title': 'Кечиккен күндөр',
      'rahbar_kpi_days_leave_title': 'Арыздуу / орундуу себеп',
      'rahbar_kpi_hours_total_title': 'Жалпы иштелген убакыт',
      'rahbar_kpi_delay_total_title': 'Жалпы кечигүү',
      'rahbar_hours_mins_short': '{hours} с {mins} мүн',
      'rahbar_minutes_plain': '{mins} мүнөт',
      'rahbar_search_staff_name': 'Кызматкердин атын издөө...',
      'rahbar_data_not_found': 'Маалымат табылган жок',
      'rahbar_no_staff_data_period':
          'Бул мезгил үчүн кызматкерлердин катышуу маалыматы жок',
      'rahbar_on_leave_short': 'Арыздуу',
      'rahbar_main_office': 'Башкы офис',
      'rahbar_time_ago': '{time} ({min} мүн мурун)',
      'rahbar_badge_at_work': 'Жумушта',
      'rahbar_badge_left': 'Кетти',
      'rahbar_badge_outside': 'Тышкарыда',
      'rahbar_checkin_time_label': 'Келүү убактысы',
      'rahbar_checkout_time_label': 'Кетүү убактысы',
      'rahbar_status_label': 'Абалы',
      'rahbar_assign_zone_button': 'Кызматкерге жаңы жумуш аймагын дайындоо',
      'rahbar_view_route_button': 'Ички картада маршрутту көрүү',
      'rahbar_map_title': 'Кызматкерлердин жайгашкан жери',
      'rahbar_new_zone_button': 'Жаңы аймак',
      'rahbar_live_badge': 'ЖОНДУ',
      'rahbar_total_count': 'Баары: {count}',
      'rahbar_inside_count': 'Жумушта: {count}',
      'rahbar_outside_count': 'Тышкарыда: {count}',
      'rahbar_route_label': 'Маршрут: {name}',
      'rahbar_search_staff_plural': 'Кызматкерлерди издөө...',
      'offline_reconnected': 'Интернет байланышы калыбына келди!',
      'offline_still_no_internet':
          'Дагы деле интернет жок. Сураныч, байланышты текшериңиз.',
      'offline_title': 'Интернет байланышы жок',
      'offline_desc':
          'Skor Xodimlar колдонмосу иштеши, катышууну белгилөө жана '
          'маалыматтарды шайкештирүү үчүн интернет талап кылынат.',
      'offline_tip_wifi': 'Wi-Fi же мобилдик интернет күйгүзүлгөнүн текшериңиз',
      'offline_tip_balance':
          'Тарифиңизде мегабайт же балансыңыз бар экенине ынаныңыз',
      'offline_tip_airplane': 'Учак режими өчүрүлгөнүн текшериңиз',
      'offline_tip_vpn': 'Эгер VPN күйүк болсо, аны убактылуу өчүрүп көрүңүз',
      'offline_understood': 'Түшүнүктүү',
      'offline_checking': 'Текшерилүүдө...',
      'offline_recheck': 'Кайра текшерүү',
      'location_disclosure_title': 'Жайгашкан жер маалыматтарын колдонуу',
      'location_disclosure_statement':
          '"Skor Xodimlar" колдонмосу кызматкерлердин жумуш убагында '
          'аймакта экенин реалдуу убакытта белгилөө жана катышууну көзөмөлдөө '
          'үчүн жайгашкан жер (геолокация) маалыматтарын чогултат. Бул '
          'маалыматтар колдонмо жабык же колдонулбаган учурда да '
          '(фондо / фондук режимде) чогултулушу мүмкүн.',
      'location_feature_time_title':
          'Жумуш убактысын жана катышууну көзөмөлдөө',
      'location_feature_time_desc':
          'Уюмдун аймагына келүү жана кетүү убактылары автоматтык эсептелет.',
      'location_feature_privacy_title': 'Купуялык жана коопсуздук',
      'location_feature_privacy_desc':
          'Жайгашкан жер маалыматтары иш берүүчүнүн тутумунда гана '
          'колдонулат, үчүнчү жактарга берилбейт жана жарнама үчүн '
          'колдонулбайт.',
      'location_accept': 'Түшүндүм жана макулмун',
      'location_decline': 'Азыр эмес (Баш тартуу)',
      'bg_location_disclosure_title': 'Фондук режимде жайгашкан жер',
      'bg_location_disclosure_statement':
          '"Skor Xodimlar" колдонмосу колдонмо жабык же колдонулбаган учурда да '
          '(фондо) жумуш убактысын автоматтык көзөмөлдөө жана кызматкердин '
          'иш ордунда экенин аныктоо үчүн жайгашкан жерди чогултат.\n\n'
          'Бул функция иштеши үчүн кийинки жөндөөлөр терезесинде '
          '"Ар дайым уруксат берүү" опциясын тандаңыз.',
      'bg_location_open_settings': 'Жөндөөлөргө өтүү',
      'bg_location_cancel': 'Азыр эмес (Баш тартуу)',
      'no_internet_default_message':
          'Маалыматтарды жүктөп болбоду. Тармакка байланышты текшерип, '
          'кайра аракет кылыңыз.',
      'no_internet_reload': 'Кайра жүктөө',
      'no_internet_tips_tooltip': 'Сунуштар',
      'app_update_default_title': 'Колдонмону жаңылаңыз',
      'app_update_default_desc':
          'Сураныч, бардык функцияларды колдонуу үчүн колдонмону эң акыркы '
          'версиясына жаңылаңыз.',
      'app_update_button': 'Жаңылоо',
      'app_update_later': 'Кийинчерээк',
      'offline_banner_restored_title': 'Интернет байланышы калыбына келди',
      'offline_banner_offline_title': 'Интернет байланышы жок',
      'offline_banner_restored_desc': 'Тутум байланышы кайра орнотулду',
      'offline_banner_offline_desc': 'Тармакка байланышты текшериңиз',
      'selfie_position_face': 'Жүзүңүздү тегерек ичине жайгаштырыңыз',
      'selfie_camera_permission_denied': 'Камерага уруксат берилген жок',
      'selfie_camera_not_found': 'Камера табылган жок',
      'selfie_camera_open_failed': 'Камераны ачып болбоду',
      'selfie_face_not_detected': 'Жүз аныкталган жок',
      'selfie_only_one_face': 'Бир гана жүз көрүнүшү керек',
      'selfie_come_closer': 'Жакыныраак келиңиз',
      'selfie_move_back': 'Бир аз алысыраак туруңуз',
      'selfie_hold_still': 'Кыймылдабай туруңуз...',
      'selfie_blink_once': 'Көзүңүздү бир жолу ирмеп ачыңыз',
      'selfie_capturing': 'Сүрөткө тартылууда...',
      'selfie_capture_error': 'Сүрөткө тартууда ката кетти',
      'selfie_permission_denied_desc':
          'Камераны колдонууга уруксат берилген жок.\nСураныч, тескөөлөрдөн '
          'уруксат бериңиз.',
      'selfie_camera_unavailable': 'Камера жеткиликсиз',
      'selfie_open_settings': 'Тескөөлөрдү ачуу',
      'selfie_close_eyes': 'Көзүңүздү жумуп ачыңыз',
      'selfie_hold_in_circle': 'Жүзүңүздү тегерек ичинде кармап туруңуз',

      // Error formatter (non-widget layers — blocs/repositories/datasources)
      'err_unknown': 'Белгисиз ката кетти. Кайра аракет кылыңыз.',
      'err_connection_timeout':
          'Серверге туташуу убактысы бүттү. Интернетти текшерип, кайра '
          'аракет кылыңыз.',
      'err_receive_timeout':
          'Сервер жооп берген жок. Бир аздан кийин аракет кылыңыз.',
      'err_connection_error':
          'Интернетке туташкан эмессиз же тармак өтө жай. Байланышты '
          'текшериңиз.',
      'err_cancelled': 'Аракет жокко чыгарылды.',
      'err_bad_certificate': 'Коопсуз туташууда ката кетти.',
      'err_status_400': 'Туура эмес суроо жиберилди.',
      'err_status_401': 'Сессиянын мөөнөтү бүттү. Сураныч, кайра кириңиз.',
      'err_status_403': 'Бул аракетти аткарууга уруксат жок.',
      'err_status_404': 'Маалымат же кызмат дареги табылган жок.',
      'err_status_405': 'Сервер менен байланыш үзүлдү. Кайра аракет кылыңыз.',
      'err_status_413':
          'Жүктөлүп жаткан файл же сүрөт өтө чоң. Кайра аракет кылыңыз.',
      'err_status_419': 'Коопсуздук ачкычы эскирген. Кайра аракет кылыңыз.',
      'err_status_422': 'Киргизилген маалыматтар туура эмес.',
      'err_status_429': 'Суроолордун саны көбөйүп кетти. Бир аз күтө туруңуз.',
      'err_status_500':
          'Серверде убактылуу ката кетти. Бир аздан кийин аракет кылыңыз.',
      'err_status_5xx': 'Серверде профилактика же оңдоо иштери жүрүп жатат.',
      'err_status_unknown': 'Сервер менен байланышта ката кетти ({code}).',
      'err_unknown_code': 'белгисиз',
      'err_image_too_large': 'Сүрөттүн көлөмү өтө чоң. Кайра сүрөткө тартыңыз.',
      'err_network_socket':
          'Интернетке туташкан эмессиз же тармак жай. Байланышты текшериңиз.',
      'err_timeout_generic':
          'Сервердин жооп берүү убактысы бүттү. Кайра аракет кылыңыз.',
      'err_server_crash':
          'Серверде убактылуу бузук кетти. Бир аздан кийин аракет кылыңыз.',
      'err_user_not_found': 'Колдонуучу табылган жок. Кайра кириңиз.',
      'err_too_many_requests':
          'Өтө көп суроо жиберилди. Сураныч, бир аз күтүңүз.',
      'err_validation': 'Киргизилген маалыматтарда ката бар.',
      'err_no_face':
          'Жүз аныкталган жок. Жүзүңүздү экранга туура коюп, кайра сүрөткө '
          'тартыңыз.',
      'err_format': 'Сервер маалыматтарында бузук. Кайра аракет кылыңыз.',
      'err_unexpected':
          'Күтүлбөгөн ката кетти. Сураныч, колдонмону кайра иштетиңиз.',
      'err_html_page':
          'Серверде техникалык иштер жүрүп жатат. Бир аздан кийин кайра '
          'аракет кылыңыз.',
      'err_generic': 'Ката кетти. Сураныч, кайра аракет кылыңыз.',
      'err_phone_not_registered': 'Бул номер тутумда каттелген эмес',
      'err_phone_ambiguous_badge':
          'Бул номер бир нече кызматкерге бекитилген. Система (бейдж) '
          'номериңизди киргизиңиз.',
      'err_phone_ambiguous_blocked':
          'Бул номер бир нече кызматкерге бекитилген. Кирүү убактылуу '
          'токтотулду — администраторго кайрылыңыз.',
      'err_request_truncated':
          'Интернет байланышында көйгөй бар — суроо серверге толук жеткен '
          'жок. Wi-Fi\'ге туташыңыз же мобилдик интернетти өчүрүп-күйгүзүп, '
          'кайра аракет кылыңыз.',
      'err_invalid_phone_format': 'Телефон номеринин форматы туура эмес',
      'err_server_generic': 'Серверде ката. Бир аздан кийин аракет кылыңыз',
      'err_no_internet': 'Интернетке туташкан эмессиз',
      'err_could_not_connect': 'Серверге туташып болбоду.',
      'face_verify_success': 'Ийгиликтүү',
      'face_verify_no_match':
          'Жүзүңүз дал келген жок. Өзүңүздү текшерип, кайра аракет '
          'кылыңыз.',
      'face_verify_ref_invalid':
          'Базадагы сүрөтүңүз жараксыз. Админге кайрылыңыз.',
      'face_verify_face_not_visible':
          'Жүзүңүз көрүнгөн жок. Жүзүңүздү рамка ичине жайгаштырыңыз.',
      'face_verify_photo_missing':
          'Сизге сүрөт жүктөлгөн эмес. Админге кайрылыңыз.',
      'face_verify_timeout':
          'Сервер жооп берген жок. Бир аздан кийин кайра аракет кылыңыз.',
      'face_verify_not_configured':
          'Жүздү текшерүү кызматы жөндөлгөн эмес. Админге кайрылыңыз.',
      'face_verify_unavailable':
          'Кызмат убактылуу иштебей жатат. Бир аздан кийин аракет кылыңыз.',
      'err_empty_image': 'Сүрөт бош. Кайра сүрөткө тартыңыз.',
      'err_connection_lost':
          'Сервер менен байланыш үзүлдү. Сураныч, кайра аракет кылыңыз.',
      'err_server_action_failed': 'Сервер катасы кетти',
      'err_attendance_failed': 'Катышууну белгилөөдө ката кетти',
      'err_profile_load_failed': 'Профиль маалыматтарын жүктөөдө ката',
      'err_profile_load_could_not': 'Профиль маалыматтарын жүктөп болбоду',
      'err_photo_upload_failed': 'Сүрөттү жүктөөдө ката кетти',
      'err_photo_upload_could_not': 'Сүрөттү жүктөп болбоду',
      'profile_phone_updated': 'Телефон номери жаңыртылды',
      'err_phone_duplicate': 'Бул номер башка кызматкерге бекитилген',
      'err_phone_change_failed': 'Телефон номерин алмаштырып болбоду',
      'err_phone_change_error': 'Телефон номерин алмаштырууда ката',
      'err_arizalar_load_failed': 'Арыздарды жүктөп болбоду',
      'err_ariza_turlari_load_failed': 'Арыз түрлөрүн жүктөп болбоду',
      'err_ariza_submit_failed': 'Арызды жөнөтүп болбоду',
      'ariza_earliest_date_note': ' (Эң эрте күн: {date})',
      'err_ariza_submit_error': 'Арызды жөнөтүүдө ката',
      'ariza_cancelled_default': 'Арыз жокко чыгарылды',
      'err_ariza_cancel_failed': 'Арызды жокко чыгарып болбоду',
      'err_ariza_cancel_error': 'Арызды жокко чыгарууда ката',
      'update_notes_default_1': 'Жаңы мүмкүнчүлүктөр жана жакшыртуулар',
      'update_notes_default_2':
          'Колдонмонун ылдамдыгы жана туруктуулугу жогорулатылды',
      'notif_channel_attendance_name': 'Катышуу эскертүүлөрү',
      'notif_channel_attendance_desc':
          'Катышууну белгилөө үчүн атайын үн менен билдирүүлөр',
      'notif_channel_review_name': 'Сурам натыйжалары',
      'notif_channel_review_desc':
          'Кол менен белгилөө суранычы кабыл алынганы же четке кагылганы '
          'жөнүндө',
      'notif_attendance_reminder_title': 'Катышуу эскертүүсү',
      'notif_attendance_reminder_body':
          'Урматтуу кызматкер, катышууну белгилеңиз!',
      'notif_test_title': 'Катышуу эскертүүсү (Сыноо)',
      'notif_test_body':
          'Урматтуу кызматкер, катышууну белгилөөгө 10 мүнөт калды.',
      'gps_channel_name': 'Skor GPS',
      'gps_channel_desc': 'Жумуш убактысын эсептөө активдүү',
      'gps_notification_title': 'Skor — Катышуу тутуму',
      'status_kelgan': 'Келди',
      'status_kelmagan': 'Келген жок',
      'status_kutilmoqda': 'Күтүлүүдө',
      'status_tasdiqlangan': 'Тастыкталды',
      'status_rad_etilgan': 'Четке кагылды',
      'status_kechikkan': 'Кечиккен',
      'ariza_type_javob_sorash': 'Сурануу',
      'ariza_type_tatil': 'Эмгек өргүү',
      'ariza_type_kasallik': 'Оору өргүүсү',
      'ariza_type_xizmat_safari': 'Иш сапары',
      'ariza_type_sababsiz': 'Себепсиз',
      'ariza_type_boshqa': 'Башка',
      'duration_hours_mins': '{hours} саат {mins} мүн',
      'duration_hours': '{hours} саат',
      'duration_mins': '{mins} мүн',
      'notif_default_title': 'Билдирүү',

      // Profile
      'profile_title': 'Профиль',
      'phone_number': 'Телефон номери',
      'organization': 'Уюм',
      'position': 'Кызмат',
      'department': 'Бөлүм',
      'shift': 'Смена',
      'work_days': 'Жумуш күндөрү',
      'face_verify': 'Жүздү таануу (HikCentral)',
      'face_configured': 'Ырасталган (Активдүү)',
      'face_not_configured': 'Ырасталган эмес',
      'app_version': 'Колдонмо версиясы',
      'app_language': 'Колдонмонун тили',
      'select_language': 'Тилди тандаңыз',
      'select_language_desc': 'Өзүңүзгө ыңгайлуу тилди тандаңыз',
      'logout': 'Системадан чыгуу',
      'logout_confirmation_title': 'Чыгууну ырастоо',
      'logout_confirmation_desc': 'Каттоо жазууңуздан чыгууну каалайсызбы?',
      'camera_photo': 'Камера менен сүрөткө тартуу',
      'gallery_photo': 'Галереядан тандоо',
      'photo_uploading': 'Сүрөт жүктөлүүдө...',
      'phone_updating': 'Телефон номери жаңыланууда...',
      'profile_loading': 'Профиль жүктөлүүдө...',
      'photo_picker_error': 'Сүрөт тандоодо ката кетти',
      'latest_version_installed': 'Сизде эң акыркы версия орнотулган',
      'refresh': 'Жаңылоо',
      'user': 'Колдонуучу',

      // Weekdays Full
      'weekday_mon': 'Дүйшөмбү',
      'weekday_tue': 'Шейшемби',
      'weekday_wed': 'Шаршемби',
      'weekday_thu': 'Бейшемби',
      'weekday_fri': 'Жума',
      'weekday_sat': 'Ишемби',
      'weekday_sun': 'Жекшемби',

      // Weekdays Short
      'weekday_short_mon': 'Дүй',
      'weekday_short_tue': 'Шей',
      'weekday_short_wed': 'Шар',
      'weekday_short_thu': 'Бей',
      'weekday_short_fri': 'Жум',
      'weekday_short_sat': 'Ишм',
      'weekday_short_sun': 'Жек',

      // Weekdays Mini
      'weekday_mini_mon': 'Дү',
      'weekday_mini_tue': 'Ше',
      'weekday_mini_wed': 'Ша',
      'weekday_mini_thu': 'Бе',
      'weekday_mini_fri': 'Жу',
      'weekday_mini_sat': 'Иш',
      'weekday_mini_sun': 'Же',

      // Common & Actions
      'cancel': 'Жокко чыгаруу',
      'save': 'Сактоо',
      'close': 'Жабуу',
      'confirm': 'Ырастоо',
      'retry': 'Кайра аракет кылуу',
      'error': 'Ката',
      'success': 'Ийгиликтүү',
      'today': 'Бүгүн',
      'everyday_7': 'Күн сайын (7 күндүк)',
      'days_format': '{count} күндүк',
      'single_day_format': '{day} (1 күн)',
    },
  };
}
