import 'dart:typed_data';
import 'package:flutter/material.dart';

/// ----------------------------------------------
/// Utils
/// ----------------------------------------------

/// Normaliza texto para buscas: minúsculas, sem acentos/símbolos.
String normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[áàãâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòõôö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '');
}

/// Retorna iniciais a partir do nome (até 2 letras).
String initialsFrom(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+'));
  final ini = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
  return ini.isEmpty ? 'M' : ini;
}

/// ----------------------------------------------
/// AppBar padrão com lupa, "+Novo" e avatar com menu
/// ----------------------------------------------
PreferredSizeWidget buildTopBar({
  required BuildContext context,
  required String title,
  VoidCallback? onSearch,
  VoidCallback? onNew,
  Uint8List? avatarBytes,
  String? avatarLabel,
  VoidCallback? onOpenSettings,
  VoidCallback? onLogout,
}) {
  Widget avatar() {
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      return CircleAvatar(backgroundImage: MemoryImage(avatarBytes));
    }
    return CircleAvatar(child: Text(initialsFrom(avatarLabel)));
  }

  return AppBar(
    title: Text(title),
    actions: [
      IconButton(
        tooltip: 'Buscar',
        icon: const Icon(Icons.search),
        onPressed: onSearch,
      ),
      if (onNew != null)
        FilledButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add),
          label: const Text('Novo'),
          style: const ButtonStyle(
            visualDensity: VisualDensity(horizontal: -2, vertical: -2),
          ),
        ),
      const SizedBox(width: 6),
      PopupMenuButton<String>(
        tooltip: 'Perfil e opções',
        offset: const Offset(0, kToolbarHeight),
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configurações'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout),
              title: Text('Sair'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        onSelected: (v) {
          if (v == 'settings') onOpenSettings?.call();
          if (v == 'logout') onLogout?.call();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: avatar(),
        ),
      ),
    ],
  );
}

/// ----------------------------------------------
/// Botão com gradiente azul (substitui seu antigo)
/// ----------------------------------------------
class PrimaryGradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double height;

  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = 10,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, color: Colors.white),
        if (icon != null) const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: padding,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
