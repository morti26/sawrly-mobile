import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/navigation/main_navigation.dart';
// import 'features/auth/login_screen.dart';

class FotgrafApp extends StatelessWidget {
  const FotgrafApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صورلي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', ''),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
      ],
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        fontFamily: 'Tajawal',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A3EED), // Purple accent
          brightness: Brightness.dark,
          surface: const Color(0xFF222530), // Cards/panels background
        ),
        scaffoldBackgroundColor: const Color(0xFF161921),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161921),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: child!,
        );
      },
      // Authentication-gated destinations are handled inside MainNavigation.
      home: const MainNavigation(),
    );
  }
}
