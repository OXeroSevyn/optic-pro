import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style to dark creator mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B1012),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const OpticProApp());
}

class OpticProApp extends StatelessWidget {
  const OpticProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Optic Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1012),
        colorScheme: const ColorScheme.dark(
          primary: Color(
            0xFF74E0D0,
          ), // Material 3 Expressive Radiant Chartreuse/Gold
          onPrimary: Color(0xFF07201D),
          primaryContainer: Color(0xFF16423D),
          onPrimaryContainer: Color(0xFFCCFFF8),
          secondary: Color(0xFF74E0D0), // Expressive Cyan Accent
          onSecondary: Colors.black,
          surface: Color(0xFF101719),
          onSurface: Colors.white,
          surfaceContainer: Color(0xFF172022),
          surfaceContainerHigh: Color(0xFF202B2D),
          surfaceContainerHighest: Color(0xFF2B393B),
          error: Color(0xFFFF453A),
          onError: Colors.white,
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: const Color(0xFF1B1E24),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF11191B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1012),
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: const CameraScreen(),
    );
  }
}
