import 'package:flutter/material.dart';

/// Paleta do tema azul-escuro (visual antigo)
class AppColors {
  // Fundo geral
  static const Color navy900 = Color(0xFF0C1220); // fundo da tela
  static const Color navy800 = Color(0xFF17273F); // cards/containers
  static const Color navy700 = Color(0xFF223354);
  static const Color navy600 = Color(0xFF2B3F66);

  // Ações primárias (botões/destaques)
  static const Color blueA = Color(0xFF1C7CFF);
  static const Color blueB = Color(0xFF2EC6FF);

  // Texto
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFBFC9DA);

  // Bordas/linhas
  static const Color stroke = Color(0xFF2C3A53);

  // Estados
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class AppTheme {
  static ThemeData get darkBlue {
    final base = ThemeData.dark(useMaterial3: true);

    final colorScheme = ColorScheme.dark(
      primary: AppColors.blueA,
      primaryContainer: AppColors.navy700,
      onPrimary: Colors.white,
      secondary: AppColors.blueB,
      onSecondary: Colors.white,
      surface: AppColors.navy800,
      onSurface: AppColors.textPrimary,
      background: AppColors.navy900,
      onBackground: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.stroke,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.navy900,
      canvasColor: AppColors.navy900,
      cardColor: AppColors.navy800,
      dividerColor: AppColors.stroke,

      // 👇 ÚNICA MUDANÇA: AppBar agora usa o mesmo azul do card
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.navy800,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            bodySmall:
                base.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            bodyMedium:
                base.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.disabled)) {
              return AppColors.navy700;
            }
            return AppColors.blueA;
          }),
          foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          shape: MaterialStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              MaterialStateProperty.all<Color>(AppColors.navy700),
          foregroundColor:
              MaterialStateProperty.all<Color>(Colors.white),
          shape: MaterialStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: MaterialStateProperty.all<BorderSide>(
            const BorderSide(color: AppColors.stroke),
          ),
          foregroundColor:
              MaterialStateProperty.all<Color>(Colors.white),
          shape: MaterialStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // Campos de texto
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navy800,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.stroke),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.stroke),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.blueA, width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.error),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Cards
      cardTheme: CardTheme(
        color: AppColors.navy800,
        surfaceTintColor: AppColors.navy800,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),

      // ListTile (itens de orçamento)
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
        tileColor: AppColors.navy800,
      ),

      // SnackBar
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.navy700,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),

      // Checkbox / Switch
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.all<Color>(AppColors.blueA),
        side: const BorderSide(color: AppColors.stroke),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor:
            MaterialStateProperty.resolveWith<Color?>((states) {
          return states.contains(MaterialState.selected)
              ? AppColors.blueA
              : AppColors.navy600;
        }),
        trackColor:
            MaterialStateProperty.resolveWith<Color?>((states) {
          return states.contains(MaterialState.selected)
              ? AppColors.blueA.withOpacity(.35)
              : AppColors.navy700;
        }),
      ),

      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  /// Se quiser usar um degradê manual numa AppBar:
  static Widget appBarGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy900, AppColors.navy800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
