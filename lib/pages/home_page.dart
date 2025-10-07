import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:printing/printing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models.dart';
import '../services/n8n_client.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';

import '../widgets/theme.dart';

// telas para navegação a partir do AppBar
import 'settings_page.dart';
import 'login_page.dart';
import 'clients_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.startNew = false,
    this.orcToEdit, // orçamento opcional para carregar
  });

  final bool startNew;
  final Orcamento? orcToEdit;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();

  // ===== Profissional (AGORA só carregado do Storage) =====
  Profissional? _perfil; // perfil salvo em Configurações
  bool _perfilSalvo = false;

  // ===== Cliente =====
  final _cliNome = TextEditingController();
  final _cliTelefone = TextEditingController();

  // Cliente: doc + endereço
  final _cliCpfCnpj = TextEditingController();
  final _cliCep = TextEditingController();
  final _cliLogradouro = TextEditingController();
  final _cliNumero = TextEditingController();
  final _cliBairro = TextEditingController();
  final _cliCidade = TextEditingController();
  final _cliUf = TextEditingController();
  final _cliCepFocus = FocusNode();

  // Campos personalizados do Cliente (nome -> controller)
  final Map<String, TextEditingController> _cliCustom = {};

  // Itens / totais
  final List<ItemOrcamento> _itens = [];
  final _obs = TextEditingController();
  final _desconto = TextEditingController();
  final _acrescimos = TextEditingController();

  // Flags de edição
  String? _editingOrcId;

  // Masks (cliente)
  final _maskTelefone = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _maskCep = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _maskCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _maskCnpj = MaskTextInputFormatter(
    mask: '##.###.###/####-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  MaskTextInputFormatter get _maskCpfCnpjFormatter {
    final digits = _cliCpfCnpj.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 11 ? _maskCnpj : _maskCpf;
  }

  Uint8List? _logoBytes;
  final dynamic store = StorageService();

  // CEP debounce (cliente)
  Timer? _cliCepDebounce;
  bool _buscandoCliCep = false;

  // exibição
  bool _mostrarFormulario = false; // só aparece após “+ Novo Orçamento”

  // --- estilo: botões na cor do card de boas-vindas
  ButtonStyle get _filledPrimaryStyle => FilledButton.styleFrom(
        backgroundColor: AppColors.navy900,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );
  ButtonStyle get _smallFilledPrimaryStyle => FilledButton.styleFrom(
        backgroundColor: AppColors.navy900,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  void initState() {
    super.initState();
    _loadProfileAndLogo();
    _loadCustomClientFields();

    _cliCep.addListener(_debouncedCliCepListener);
    _cliCepFocus.addListener(() {
      if (!_cliCepFocus.hasFocus) _fetchCliCepIfReady();
    });
  }

  @override
  void dispose() {
    _cliCepDebounce?.cancel();
    _cliCepFocus.dispose();
    for (final c in [
      _cliNome,
      _cliTelefone,
      _cliCpfCnpj,
      _cliCep,
      _cliLogradouro,
      _cliNumero,
      _cliBairro,
      _cliCidade,
      _cliUf,
      _obs,
      _desconto,
      _acrescimos
    ]) {
      c.dispose();
    }
    _cliCustom.values.forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadProfileAndLogo() async {
    final logo = await store.getLogoBytes();
    final perfil = await store.getPerfilProfissional();
    setState(() {
      _logoBytes = logo;
      _perfil = perfil;
      _perfilSalvo = perfil != null;
    });

    // === ABERTURA DO FORMULÁRIO ===
    // 1) Se veio orçamento para edição, abre e carrega os dados
    if (widget.orcToEdit != null && _perfilSalvo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _carregarOrcamento(widget.orcToEdit!);
      });
      return;
    }

    // 2) Se veio com startNew=true e já tem perfil salvo, abre o formulário
    if (widget.startNew && _perfilSalvo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _novoOrcamento());
    } else if (widget.startNew && !_perfilSalvo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWarnSnack(
          'Complete o cadastro do profissional em Configurações.',
          actionLabel: 'Configurar',
          onAction: _goSettings,
        );
      });
    }
  }

  Future<void> _loadCustomClientFields() async {
    final List<String> names = <String>[];

    try {
      final cfg = await (store as dynamic).getCustomFieldConfigs();
      if (cfg is List) {
        for (final e in cfg) {
          final name = (e is Map ? (e['name'] ?? '') : '').toString().trim();
          if (name.isNotEmpty) names.add(name);
        }
      }
    } catch (_) {}

    if (names.isEmpty) {
      try {
        final legacy = await store.getCustomClientFields();
        if (legacy is List<String>) {
          names.addAll(legacy);
        } else if (legacy is List) {
          names.addAll(legacy.map((e) => '$e'));
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _cliCustom.clear();
      for (final n in names) {
        _cliCustom[n] = TextEditingController();
      }
    });
  }

  // CEP Cliente
  void _debouncedCliCepListener() {
    _cliCepDebounce?.cancel();
    _cliCepDebounce =
        Timer(const Duration(milliseconds: 350), _fetchCliCepIfReady);
  }

  Future<void> _fetchCliCepIfReady() async {
    final digits = _cliCep.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_buscandoCliCep || digits.length != 8) return;
    setState(() => _buscandoCliCep = true);
    try {
      final r = await http
          .get(Uri.parse('https://viacep.com.br/ws/$digits/json/'))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (r.statusCode != 200) return;
      final j = jsonDecode(r.body);
      if (j is Map && j['erro'] == true) return;
      _cliLogradouro.text = (j['logradouro'] ?? '').toString();
      _cliBairro.text = (j['bairro'] ?? '').toString();
      _cliCidade.text = (j['localidade'] ?? '').toString();
      _cliUf.text = (j['uf'] ?? '').toString().toUpperCase();
    } finally {
      if (mounted) setState(() => _buscandoCliCep = false);
    }
  }

  // iniciais pro avatar
  String get _iniciaisPerfil {
    final s = (_perfil?.nome ?? '').trim();
    if (s.isEmpty) return 'MGL';
    final parts = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final a = parts.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  // Header card
  Widget _brandHeader() {
    return Card(
      color: AppColors.navy900,
      surfaceTintColor: AppColors.navy900,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.headset_mic_outlined, size: 72, color: Colors.white),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Colors.green),
                SizedBox(width: 6),
                Text('(31) 98508-2425', style: TextStyle(color: Colors.white)),
                SizedBox(width: 16),
                FaIcon(FontAwesomeIcons.instagram, size: 18, color: Colors.pink),
                SizedBox(width: 6),
                Text('@mglautomacao', style: TextStyle(color: Colors.white)),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Bem-vindo a MGL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text('Orçamentos personalizados',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  void _novoOrcamento() {
    if (!_perfilSalvo) {
      _showWarnSnack(
        'Complete o cadastro do profissional em Configurações.',
        actionLabel: 'Configurar',
        onAction: _goSettings,
      );
      return;
    }
    setState(() {
      _editingOrcId = null;
      _mostrarFormulario = true;
      _limparCliente(); // começa limpo
      _itens.clear();
      _desconto.clear();
      _acrescimos.clear();
      _obs.clear();
    });
    _showInfoSnack('Novo orçamento iniciado.');
  }

  // Carregar orçamento existente para edição
  void _carregarOrcamento(Orcamento o) {
    setState(() {
      _editingOrcId = o.id;
      _mostrarFormulario = true;

      // Cliente básico
      _cliNome.text = o.cliente.nome;
      _cliTelefone.text = o.cliente.telefone;

      // Documento/Endereço (se existirem no modelo)
      _cliCpfCnpj.text = (o.cliente.cpfCnpj ?? '').toString();
      _cliCep.text = (o.cliente.cep ?? '').toString();
      _cliLogradouro.text = (o.cliente.logradouro ?? '').toString();
      _cliNumero.text = (o.cliente.numero ?? '').toString();
      _cliBairro.text = (o.cliente.bairro ?? '').toString();
      _cliCidade.text = (o.cliente.cidade ?? '').toString();
      _cliUf.text = (o.cliente.uf ?? '').toString();

      // Itens
      _itens
        ..clear()
        ..addAll(o.itens.map((e) => ItemOrcamento(
              descricao: e.descricao,
              quantidade: e.quantidade,
              unidade: e.unidade,
              valorUnit: e.valorUnit,
            )));

      // Totais e observações
      _desconto.text = o.desconto == 0 ? '' : o.desconto.toString();
      _acrescimos.text = o.acrescimos == 0 ? '' : o.acrescimos.toString();
      _obs.text = o.observacoes ?? '';
    });

    _showInfoSnack('Orçamento ${o.id} carregado para edição.');
  }

  void _cancelarOrcamento() {
    setState(() {
      _editingOrcId = null;
      _mostrarFormulario = false;
      _limparCliente();
      _itens.clear();
      _desconto.clear();
      _acrescimos.clear();
      _obs.clear();
    });
    _showInfoSnack('Orçamento cancelado.');
  }

  // navegação AppBar
  Future<void> _goSettings() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsPage()));
    await _loadProfileAndLogo();
    await _loadCustomClientFields(); // caso tenha alterado campos
  }

  void _logout() async {
    await store.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _goClients() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClientsPage()),
    );
  }

  // SnackBars
  void _showWarnSnack(String msg, {String? actionLabel, VoidCallback? onAction}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF7F1D1D),
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        action: (actionLabel != null)
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction ?? () {},
                textColor: Colors.white,
              )
            : null,
      ),
    );
  }

  void _showInfoSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy700,
        content: Text(
          msg,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MGL Orçamentos',
            style: TextStyle(fontWeight: FontWeight.w600)),
        flexibleSpace: AppTheme.appBarGradientBackground(),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Clientes',
            onPressed: _goClients,
            icon: const Icon(Icons.group_outlined),
            color: onPrimary,
          ),
          // Mantém sempre clicável para exibir alerta quando faltar perfil
          TextButton(
            onPressed: () {
              if (_perfilSalvo) {
                _novoOrcamento();
              } else {
                _showWarnSnack(
                  'Complete o cadastro do profissional em Configurações.',
                  actionLabel: 'Configurar',
                  onAction: _goSettings,
                );
              }
            },
            child: const Text(
              '+ Novo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              tooltip: 'Perfil',
              offset: const Offset(0, kToolbarHeight),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
                backgroundColor: AppColors.navy700,
                backgroundImage:
                    _logoBytes != null ? MemoryImage(_logoBytes!) : null,
                child: _logoBytes == null
                    ? Text(_iniciaisPerfil,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12))
                    : null,
              ),
            ),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _brandHeader(),
          const SizedBox(height: 12),

          // ações de topo
          if (!_mostrarFormulario) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: _filledPrimaryStyle,
                onPressed: () {
                  if (_perfilSalvo) {
                    _novoOrcamento();
                  } else {
                    _showWarnSnack(
                      'Complete o cadastro do profissional em Configurações.',
                      actionLabel: 'Configurar',
                      onAction: _goSettings,
                    );
                  }
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  '+ Novo Orçamento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelarOrcamento,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: _filledPrimaryStyle,
                    onPressed: _novoOrcamento, // reiniciar rápido
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      '+ Novo',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          if (_mostrarFormulario) _formulario(),
        ],
      ),
    );
  }

  // ---------- FORM ----------
  Widget _formulario() {
    final List<Widget> docAddrAndCustom = [
      TextFormField(
        controller: _cliCpfCnpj,
        inputFormatters: [_maskCpfCnpjFormatter],
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'CPF ou CNPJ',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
        onChanged: (_) => setState(() {}),
      ),
      Focus(
        focusNode: _cliCepFocus,
        child: TextFormField(
          controller: _cliCep,
          inputFormatters: [_maskCep],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'CEP (Cliente)',
            prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
            suffixIcon: _buscandoCliCep
                ? const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
        ),
      ),
      TextFormField(
        controller: _cliNumero,
        decoration: const InputDecoration(
            labelText: 'Número (Cliente)', prefixIcon: Icon(Icons.numbers)),
      ),
      TextFormField(
        controller: _cliLogradouro,
        decoration: const InputDecoration(
            labelText: 'Logradouro (Cliente)',
            prefixIcon: Icon(Icons.map_outlined)),
      ),
      TextFormField(
        controller: _cliBairro,
        decoration: const InputDecoration(
            labelText: 'Bairro (Cliente)',
            prefixIcon: Icon(Icons.location_city_outlined)),
      ),
      TextFormField(
        controller: _cliCidade,
        decoration: const InputDecoration(
            labelText: 'Cidade (Cliente)',
            prefixIcon: Icon(Icons.location_on_outlined)),
      ),
      TextFormField(
        controller: _cliUf,
        decoration: const InputDecoration(
            labelText: 'UF (Cliente)', prefixIcon: Icon(Icons.flag_outlined)),
      ),
    ];

    if (_cliCustom.isNotEmpty) {
      for (final entry in _cliCustom.entries) {
        docAddrAndCustom.add(
          TextFormField(
            controller: entry.value,
            decoration: InputDecoration(
              labelText: entry.key,
              prefixIcon: const Icon(Icons.edit_note),
            ),
          ),
        );
      }
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          _section('Cliente'),
          _grid([
            TextFormField(
              controller: _cliNome,
              decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_pin_circle_outlined)),
              validator: _req,
            ),
            TextFormField(
              controller: _cliTelefone,
              inputFormatters: [_maskTelefone],
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Telefone',
                  prefixIcon:
                      Icon(Icons.phone_bluetooth_speaker_outlined)),
              validator: _req,
            ),
          ]),
          const SizedBox(height: 12),

          _section('Documento e Endereço do Cliente'),
          _grid(docAddrAndCustom),

          const SizedBox(height: 16),
          _section('Itens do Orçamento'),
          if (_itens.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nenhum item adicionado.',
                  style: TextStyle(color: Color(0xFF9AA3AF)),
                ),
              ),
            ),
          ..._itens.asMap().entries.map((e) => _itemTile(e.key, e.value)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addItemSheet,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Item'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _desconto,
                decoration: const InputDecoration(
                  labelText: 'Desconto (R\$)',
                  prefixIcon: Icon(Icons.money_off_csred_outlined),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: _acrescimos,
            decoration: const InputDecoration(
              labelText: 'Acréscimos (R\$)',
              prefixIcon: Icon(Icons.attach_money_outlined),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              if (v.contains('.')) {
                final novo = v.replaceAll('.', ',');
                _acrescimos.value = TextEditingValue(
                  text: novo,
                  selection: TextSelection.collapsed(offset: novo.length),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _obs,
            decoration: const InputDecoration(labelText: 'Observações'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _gerarPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Gerar PDF'),
              ),
            ),
            const SizedBox(width: 12),
            if (_editingOrcId != null)
              Expanded(
                child: FilledButton.icon(
                  style: _smallFilledPrimaryStyle,
                  onPressed: _salvarAlteracoes,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar alterações'),
                ),
              )
            else
              Opacity(
                opacity: 0.45,
                child: FilledButton.icon(
                  style: _smallFilledPrimaryStyle,
                  onPressed: null, // sempre desabilitado
                  icon: const Icon(Icons.send),
                  label: const Text('Envio Auto'),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          const _VersionBadge(),
        ],
      ),
    );
  }

  Widget _section(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            t,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      );

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth > 700;
      return GridView.count(
        crossAxisCount: two ? 2 : 1,
        childAspectRatio: two ? 3.6 : 3.1,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: children,
      );
    });
  }

  Widget _itemTile(int index, ItemOrcamento it) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    return Card(
      child: ListTile(
        title: const Text('Item', style: TextStyle(color: Colors.white)),
        subtitle: Text(
          'Desc: ${it.descricao} • Qtd: ${it.quantidade} ${it.unidade ?? ''} • '
          'V. Unit: ${currency.format(it.valorUnit)} • '
          'Subtotal: ${currency.format(it.subtotal)}',
          style:
              const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
        ),
        // ✅ tocar no card também abre a edição do item
        onTap: () => _editItemSheet(index, it),
        trailing: Wrap(spacing: 8, children: [
          IconButton(
              onPressed: () => _editItemSheet(index, it),
              icon: const Icon(Icons.edit, color: Colors.white70)),
          IconButton(
              onPressed: () => setState(() => _itens.removeAt(index)),
              icon: const Icon(Icons.delete, color: Colors.redAccent)),
        ]),
      ),
    );
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

  // ----- ITENS -----
  Future<void> _addItemSheet() async {
    final desc = TextEditingController();
    final qtd = TextEditingController();
    final un = TextEditingController();
    final vUnit = TextEditingController();

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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Novo Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                  controller: desc,
                  decoration:
                      const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: qtd,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Quantidade'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: un,
                        decoration: const InputDecoration(
                            labelText: 'Unidade (opcional)'))),
              ]),
              const SizedBox(height: 8),
              TextField(
                  controller: vUnit,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Valor Unitário (R\$)')),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: _smallFilledPrimaryStyle,
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ]),
          ),
        );
      },
    );

    if (ok == true) {
      setState(() {
        _itens.add(ItemOrcamento(
          descricao: desc.text.trim(),
          quantidade: double.tryParse(qtd.text.replaceAll(',', '.')) ?? 0,
          unidade: un.text.trim().isEmpty ? null : un.text.trim(),
          valorUnit: double.tryParse(vUnit.text.replaceAll(',', '.')) ?? 0,
        ));
      });
    }
  }

  Future<void> _editItemSheet(int index, ItemOrcamento it) async {
    final desc = TextEditingController(text: it.descricao);
    final qtd = TextEditingController(text: it.quantidade.toString());
    final un = TextEditingController(text: it.unidade ?? '');
    final vUnit = TextEditingController(text: it.valorUnit.toString());

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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Editar Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                  controller: desc,
                  decoration:
                      const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: qtd,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Quantidade'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: un,
                        decoration: const InputDecoration(
                            labelText: 'Unidade (opcional)'))),
              ]),
              const SizedBox(height: 8),
              TextField(
                  controller: vUnit,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Valor Unitário (R\$)')),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: _smallFilledPrimaryStyle,
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check),
                label: const Text('Salvar'),
              ),
            ]),
          ),
        );
      },
    );

    if (ok == true) {
      setState(() {
        _itens[index] = ItemOrcamento(
          descricao: desc.text.trim(),
          quantidade:
              double.tryParse(qtd.text.replaceAll(',', '.')) ?? it.quantidade,
          unidade: un.text.trim().isEmpty ? null : un.text.trim(),
          valorUnit:
              double.tryParse(vUnit.text.replaceAll(',', '.')) ?? it.valorUnit,
        );
      });
    }
  }

  // ----- PDF -----
  Future<void> _gerarPdf() async {
    if (_perfil == null) {
      _showWarnSnack(
        'Complete o cadastro do profissional em Configurações.',
        actionLabel: 'Configurar',
        onAction: _goSettings,
      );
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _itens.isEmpty) {
      _showWarnSnack('Preencha os campos e adicione ao menos 1 item.');
      return;
    }

    try {
      final id = _editingOrcId ?? await store.nextOrcId();

      final extras = _cliCustom.entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => '${e.key}: ${e.value.text.trim()}')
          .toList();
      final extraObs =
          extras.isEmpty ? '' : '\n\nCampos extras: ${extras.join(' • ')}';

      final orcBase = _buildOrcamentoWithId(id);
      final obs = _obs.text.trim();
      final orc = Orcamento(
        id: orcBase.id,
        profissional: orcBase.profissional,
        cliente: orcBase.cliente,
        data: orcBase.data,
        itens: orcBase.itens,
        desconto: orcBase.desconto,
        acrescimos: orcBase.acrescimos,
        observacoes:
            (obs + extraObs).trim().isEmpty ? null : (obs + extraObs).trim(),
      );

      // ✅ se estiver editando, remove a versão antiga antes de salvar
      if (_editingOrcId != null) {
        await store.deleteOrcamentoById(_editingOrcId!);
      }
      await store.saveOrcamento(orc);
      await store.saveCliente(orc.cliente);

      final bytes = await gerarPdfBytes(orc, logoBytes: _logoBytes);
      await Printing.sharePdf(bytes: bytes, filename: 'orcamento_${orc.id}.pdf');

      if (!mounted) return;
      _showInfoSnack('PDF gerado: orcamento_${orc.id}.pdf');

      // volta pra home inicial limpa
      setState(() {
        _editingOrcId = null;
        _mostrarFormulario = false;
        _limparCliente();
        _itens.clear();
        _desconto.clear();
        _acrescimos.clear();
        _obs.clear();
      });
    } catch (e) {
      if (!mounted) return;
      _showWarnSnack('Falha ao gerar PDF: $e');
    }
  }

  // ----- SALVAR ALTERAÇÕES (sem gerar PDF) -----
  Future<void> _salvarAlteracoes() async {
    if (_perfil == null) {
      _showWarnSnack(
        'Complete o cadastro do profissional em Configurações.',
        actionLabel: 'Configurar',
        onAction: _goSettings,
      );
      return;
    }
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _itens.isEmpty) {
      _showWarnSnack('Preencha os campos e adicione ao menos 1 item.');
      return;
    }

    try {
      final id = _editingOrcId ?? await store.nextOrcId();

      final extras = _cliCustom.entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => '${e.key}: ${e.value.text.trim()}')
          .toList();
      final extraObs =
          extras.isEmpty ? '' : '\n\nCampos extras: ${extras.join(' • ')}';

      final base = _buildOrcamentoWithId(id);
      final obs = _obs.text.trim();
      final orc = Orcamento(
        id: base.id,
        profissional: base.profissional,
        cliente: base.cliente,
        data: base.data,
        itens: base.itens,
        desconto: base.desconto,
        acrescimos: base.acrescimos,
        observacoes:
            (obs + extraObs).trim().isEmpty ? null : (obs + extraObs).trim(),
      );

      // ✅ se estiver editando, remove a versão antiga antes de salvar
      if (_editingOrcId != null) {
        await store.deleteOrcamentoById(_editingOrcId!);
      }
      await store.saveOrcamento(orc);
      await store.saveCliente(orc.cliente);

      if (!mounted) return;
      _showInfoSnack('Alterações salvas.');

      // volta pra home inicial limpa
      setState(() {
        _editingOrcId = null;
        _mostrarFormulario = false;
        _limparCliente();
        _itens.clear();
        _desconto.clear();
        _acrescimos.clear();
        _obs.clear();
      });
    } catch (e) {
      if (!mounted) return;
      _showWarnSnack('Falha ao salvar alterações: $e');
    }
  }

  void _limparCliente() {
    _cliNome.clear();
    _cliTelefone.clear();
    _cliCpfCnpj.clear();
    _cliCep.clear();
    _cliLogradouro.clear();
    _cliNumero.clear();
    _cliBairro.clear();
    _cliCidade.clear();
    _cliUf.clear();
    for (final c in _cliCustom.values) c.clear();
  }

  // Constrói o orçamento usando o perfil salvo
  Orcamento _buildOrcamentoWithId(String id) {
    final profissional = _perfil ??
        Profissional(
          nome: '',
          telefone: '',
          segmento: '',
          logradouro: '',
          numero: '',
          bairro: '',
          cidade: '',
          uf: '',
          cep: '',
        );

    final desconto = double.tryParse(_desconto.text.replaceAll(',', '.')) ?? 0;
    final acresc =
        double.tryParse(_acrescimos.text.replaceAll(',', '.')) ?? 0;

    // Obs.: mantive o mesmo modelo/atributos que você já usa hoje.
    final cliente = Cliente(
      nome: _cliNome.text.trim(),
      telefone: _cliTelefone.text.trim(),
      placa: null,
      // se o seu modelo tiver esses campos, eles serão preservados;
      // caso não tenha, são ignorados pelo constructor.
      cpfCnpj: _cliCpfCnpj.text.trim().isEmpty ? null : _cliCpfCnpj.text.trim(),
      cep: _cliCep.text.trim().isEmpty ? null : _cliCep.text.trim(),
      logradouro: _cliLogradouro.text.trim().isEmpty ? null : _cliLogradouro.text.trim(),
      numero: _cliNumero.text.trim().isEmpty ? null : _cliNumero.text.trim(),
      bairro: _cliBairro.text.trim().isEmpty ? null : _cliBairro.text.trim(),
      cidade: _cliCidade.text.trim().isEmpty ? null : _cliCidade.text.trim(),
      uf: _cliUf.text.trim().isEmpty ? null : _cliUf.text.trim(),
    );

    return Orcamento(
      id: id,
      profissional: profissional,
      cliente: cliente,
      data: DateTime.now(),
      itens: List.from(_itens),
      desconto: desconto,
      acrescimos: acresc,
      observacoes: _obs.text.trim().isEmpty ? null : _obs.text.trim(),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  Future<String> _label() async {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version}+${info.buildNumber}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Opacity(
          opacity: 0.6,
          child: FutureBuilder<String>(
            future: _label(),
            builder: (_, snap) {
              final text = snap.data ?? '...';
              return Text(
                text,
                style: Theme.of(context).textTheme.labelSmall,
              );
            },
          ),
        ),
      ),
    );
  }
}
