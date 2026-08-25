import 'app_locale_service.dart';

/// Shared labels used by the shell and settings screens.
class AppStrings {
  static String get appName => tr('صورلي', 'Sawrly');
  static String get home => tr('الرئيسية', 'Home');
  static String get search => tr('بحث', 'Search');
  static String get categories => tr('الأقسام', 'Categories');
  static String get bookings => tr('حجوزاتي', 'My bookings');
  static String get profile => tr('البروفايل', 'Profile');
  static String get settings => tr('الإعدادات', 'Settings');
  static String get profileSection => tr('الملف الشخصي', 'Profile');
  static String get account => tr('الحساب', 'Account');
  static String get notifications => tr('الإشعارات', 'Notifications');
  static String get subscription =>
      tr('خطط الاشتراك والدفع', 'Subscription & payments');
  static String get subscriptionSubtitle =>
      tr('اختر خطة المبدع وادفع عبر البوابة', 'Choose a creator plan and pay securely');
  static String get wallet => tr('المحفظة', 'Wallet');
  static String get walletSubtitle =>
      tr('الرصيد والأرباح وسجل المدفوعات', 'Balance, earnings and payment history');
  static String get privacy => tr('الخصوصية والأمان', 'Privacy & security');
  static String get privacySubtitle =>
      tr('تعديل بيانات الاتصال والتحقق من الهوية', 'Update contact details and verify identity');
  static String get language => tr('اللغة', 'Language');
  static String get arabic => 'العربية';
  static String get english => 'English';
  static String get soon => tr('قريباً', 'Coming soon');
  static String get editProfile => tr('تعديل الملف الشخصي', 'Edit profile');
  static String get editProfileSubtitle =>
      tr('الاسم، الصورة، النبذة، الخدمة، إلخ', 'Name, photo, bio, service, etc.');
  static String get creatorAccount => tr('حساب منشئ', 'Creator account');
  static String get clientAccount => tr('حساب عميل', 'Client account');
  static String get logout => tr('تسجيل الخروج', 'Log out');
  static String get logoutQuestion =>
      tr('هل أنت متأكد أنك تريد تسجيل الخروج؟', 'Are you sure you want to log out?');
  static String get cancel => tr('إلغاء', 'Cancel');
  static String get exit => tr('خروج', 'Log out');
}
