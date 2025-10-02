import 'package:flutter/material.dart';
import '../pages/settings_page.dart';
import '../pages/login_page.dart';
import 'theme.dart'; // <- para usar AppColors

/// AppBar dark no mesmo tom azul dos cards.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.title});
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _goSettings(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // mesma paleta do card (branco sobre azul-escuro)
    const bg = AppColors.navy800;
    const fg = Colors.white;

    return AppBar(
      backgroundColor: bg,
      surfaceTintColor: bg,
      elevation: 0,
      centerTitle: false,
      title: const Text(
        'MGL Orçamentos',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      iconTheme: const IconThemeData(color: fg),
      actionsIconTheme: const IconThemeData(color: fg),
      actions: [
        IconButton(
          tooltip: 'Clientes/Grupo',
          onPressed: () {}, // somente visual por enquanto
          icon: const Icon(Icons.group_outlined),
        ),
        IconButton(
          tooltip: 'Contatos',
          onPressed: () {},
          icon: const Icon(Icons.groups_2_outlined),
        ),
        IconButton(
          tooltip: 'Histórico',
          onPressed: () {},
          icon: const Icon(Icons.history),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais opções',
          icon: const Icon(Icons.more_vert, color: fg),
          offset: const Offset(0, kToolbarHeight),
          onSelected: (value) {
            if (value == 'settings') _goSettings(context);
            if (value == 'logout') _logout(context);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'settings', child: Text('Configurações')),
            PopupMenuItem(value: 'logout', child: Text('Sair')),
          ],
        ),
        IconButton(
          tooltip: 'Compartilhar',
          onPressed: () {},
          icon: const Icon(Icons.share_outlined),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
