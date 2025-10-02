import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:orcamento_app/pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Paleta — a mesma do seu gradiente
  static const Color kPrimary = Color(0xFF1E40AF); // azul principal
  static const Color kPrimaryAlt = Color(0xFF2563EB); // azul secundário

  @override
  Widget build(BuildContext context) {
    // ⚠️ Material 2 para manter o visual antigo dos campos
    final base = ThemeData.light().copyWith(useMaterial3: false);

    final theme = base.copyWith(
      primaryColor: kPrimary,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: kPrimary,
        onPrimary: Colors.white,
        secondary: kPrimaryAlt,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black87,
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: kPrimary,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: kPrimary,
        selectionColor: Color(0x332563EB),
        selectionHandleColor: kPrimary,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        // Material 2 style (bordas visíveis e label clássico)
        isDense: false,
        filled: false,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(width: 1, color: Color(0xFFBDBDBD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(width: 1.4, color: kPrimary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(width: 1, color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(width: 1.4, color: Colors.redAccent),
        ),
        labelStyle: TextStyle(fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          side: const BorderSide(color: kPrimary),
          foregroundColor: kPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kPrimary),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 1.5,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>(
          (s) => s.contains(MaterialState.selected) ? kPrimary : Colors.grey,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>(
          (s) => s.contains(MaterialState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: MaterialStateProperty.resolveWith<Color>(
          (s) => s.contains(MaterialState.selected) ? kPrimary : Colors.grey.shade400,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>(
          (s) => s.contains(MaterialState.selected) ? kPrimary : Colors.grey,
        ),
      ),
      iconTheme: const IconThemeData(color: kPrimary),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MGL Orçamentos',
      theme: theme,
      home: const LoginPage(),
    );
  }
}
