// lib/pages/clients_page.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:orcamento_app/services/storage_service.dart';
import 'package:orcamento_app/models.dart';

// Prefixos para evitar conflito/ambiguidade de símbolos
import 'home_page.dart' as home;
import 'settings_page.dart';
import 'login_page.dart';
import 'budgets_page.dart' as budgets;

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final store = StorageService();
  final _q = TextEditingController();

  List<Cliente> _all = [];
  List<Cliente> _filtered = [];

  // paginação (10 em 10)
  int _visible = 10;

  // header (avatar/iniciais iguais à Home)
  Uint8List? _logoBytes;
  String _profNome = '';

  // debounce da busca (como em Orçamentos)
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHeader();
    _load();
    _q.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _loadHeader() async {
    final logo = await store.getLogoBytes();
    final prof = await store.getPerfilProfissional();
    setState(() {
      _logoBytes = logo;
      _profNome = prof?.nome ?? '';
    });
  }

  String get _iniciaisPerfil {
    final s = _profNome.trim();
    if (s.isEmpty) return 'MGL';
    final parts = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final a = parts.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  Future<void> _load() async {
    final list = await store.getClientes();
    setState(() {
      _all = list;
      _filtered = List.from(list);
      _visible = 10; // reseta a paginação ao recarregar
    });

    // se já tem texto, reaplica (mantém comportamento enquanto digita)
    if (_q.text.trim().isNotEmpty) {
      _apply();
    }
  }

  // === Helpers de normalização (iguais ao raciocínio da tela de Orçamentos) ===
  String _norm(String s) => s.trim().toLowerCase();
  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');
  String _alnum(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _apply);
  }

  void _apply() {
    final raw = _q.text;
    final q = _norm(raw);
    final qDigits = _digits(raw);
    final qAlnum = _alnum(raw);

    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_all);
      } else {
        _filtered = _all.where((c) {
          final nome = _norm(c.nome);
          final telDigits = _digits(c.telefone);
          final placaAlnum = _alnum(c.placa ?? '');

          final matchNome = nome.contains(q);
          final matchTel = qDigits.isNotEmpty && telDigits.contains(qDigits);
          final matchPlaca = qAlnum.isNotEmpty && placaAlnum.contains(qAlnum);

          return matchNome || matchTel || matchPlaca;
        }).toList();
      }
      _visible = 10;
    });
  }

  // === AppBar ações ===
  Future<void> _abrirNovoOrcamento() async {
    // vai para a Home já abrindo o formulário
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => home.HomePage(startNew: true)),
    );
    // ao voltar, recarrega lista para incluir o cliente do orçamento gerado
    await _load();
  }

  void _goSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    await _loadHeader();
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // edição simples do cliente (sheet)
  Future<void> _editCliente(Cliente original) async {
    final nome = TextEditingController(text: original.nome);
    final tel  = TextEditingController(text: original.telefone);
    final placa = TextEditingController(text: original.placa ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Editar Cliente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tel,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: placa,
                  decoration: const InputDecoration(
                    labelText: 'Placa (opcional)',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.check),
                        label: const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok == true) {
      // atualiza no storage reaproveitando remove + save
      final novo = Cliente(
        nome: nome.text.trim(),
        telefone: tel.text.trim(),
        placa: placa.text.trim().isEmpty ? null : placa.text.trim(),
      );
      await store.removeCliente(original);
      await store.saveCliente(novo);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente atualizado.')),
      );
    }
  }

  void _loadMore() {
    setState(() {
      _visible = (_visible + 10).clamp(0, _filtered.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    final total = _filtered.length;
    final showing = total <= _visible ? total : _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        // mesmo gradiente da Home
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C1220), Color(0xFF17273F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Clientes',
            onPressed: () {}, // apenas visual para manter paridade com a Home
            icon: const Icon(Icons.group_outlined),
            color: onPrimary,
          ),
          TextButton(
            onPressed: _abrirNovoOrcamento,
            child: const Text(
              '+ Novo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              tooltip: 'Perfil',
              offset: const Offset(0, kToolbarHeight),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'settings') _goSettings();
                if (v == 'logout') _logout();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Configurações'),
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Sair'),
                  ),
                ),
              ],
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF223354),
                backgroundImage: _logoBytes != null ? MemoryImage(_logoBytes!) : null,
                child: _logoBytes == null
                    ? Text(
                        _iniciaisPerfil,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // BUSCA — fundo claro + texto escuro (visível)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _q,
              onChanged: (_) => _onQueryChanged(), // debounce como em Orçamentos
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.search, color: Colors.black54),
                hintText: 'Buscar por nome, telefone ou placa...',
                hintStyle: TextStyle(color: Colors.black45),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF64748B)),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _filtered.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 140),
                        Center(child: Text('Nenhum cliente.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: showing + (showing < total ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        // último item é o "Carregar mais"
                        if (i == showing && showing < total) {
                          final rest = (total - showing);
                          final next = rest >= 10 ? 10 : rest;
                          return Center(
                            child: OutlinedButton.icon(
                              onPressed: _loadMore,
                              icon: const Icon(Icons.expand_more),
                              label: Text('Carregar mais (+$next)'),
                            ),
                          );
                        }

                        final c = _filtered[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(
                              c.nome,
                              // texto escuro (visível)
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${c.telefone}${(c.placa != null && c.placa!.isNotEmpty) ? " • ${c.placa}" : ""}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  tooltip: 'Orçamentos deste cliente',
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => budgets.BudgetsPage(filterCliente: c),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.receipt_long_outlined, color: Colors.black54),
                                ),
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed: () => _editCliente(c),
                                  icon: const Icon(Icons.edit_outlined, color: Colors.black54),
                                ),
                                IconButton(
                                  tooltip: 'Excluir',
                                  onPressed: () async {
                                    await store.removeCliente(c);
                                    await _load();
                                  },
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                ),
                              ],
                            ),
                            // tocar no cliente abre a página de orçamentos do cliente
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => budgets.BudgetsPage(filterCliente: c),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
