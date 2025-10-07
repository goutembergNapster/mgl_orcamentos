import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../services/storage_service.dart';
import '../widgets/theme.dart';
import 'clients_page.dart';
import 'home_page.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final store = StorageService();

  // --- LOGO / AVATAR ---
  Uint8List? _logoBytes;
  bool _loadingLogo = false;
  String _logoSize = 'medium';

  // --- WEBHOOK ---
  final _webhook = TextEditingController();

  // --- PROFISSIONAL ---
  final _formKey = GlobalKey<FormState>();
  final _profNome = TextEditingController();
  final _profTelefone = TextEditingController();
  final _profSegmento = TextEditingController();
  final _cep = TextEditingController();
  final _logradouro = TextEditingController();
  final _numero = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _uf = TextEditingController();
  bool _editingProfile = true;
  Profissional? _perfilAtual;

  // CEP (profissional) – igual à Home, mas com “latch” de erro
  final _cepFocus = FocusNode();
  Timer? _cepDebounce;
  bool _buscandoProfCep = false;

  // 🔒 quando der erro uma vez, não tenta de novo sozinho até o usuário
  // editar o campo CEP novamente.
  bool _cepLookupLatched = false;
  bool _cepUserEdited = false;

  // --- CAMPOS PERSONALIZADOS ---
  final _newFieldCtrl = TextEditingController();
  List<String> _customFields = [];

  ButtonStyle get _filledPrimaryStyle => FilledButton.styleFrom(
        backgroundColor: AppColors.navy900,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  void initState() {
    super.initState();
    _loadAll();

    // listeners do CEP (profissional)
    _cep.addListener(_debouncedCepListener);
    _cepFocus.addListener(() {
      if (!_cepFocus.hasFocus) _fetchProfCepIfReady();
    });
  }

  @override
  void dispose() {
    _webhook.dispose();
    _newFieldCtrl.dispose();
    _cepDebounce?.cancel();
    _cepFocus.dispose();
    for (final c in [
      _profNome,
      _profTelefone,
      _profSegmento,
      _cep,
      _logradouro,
      _numero,
      _bairro,
      _cidade,
      _uf
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      _logoBytes = await store.getLogoBytes();
    } catch (_) {}
    try {
      _customFields = await store.getCustomClientFields();
    } catch (_) {}
    try {
      _webhook.text = (await store.getWebhookUrl()) ?? '';
    } catch (_) {}

    try {
      final p = await store.getPerfilProfissional();
      _perfilAtual = p;
      if (p != null) {
        _editingProfile = false;
        _profNome.text = p.nome;
        _profTelefone.text = p.telefone;
        _profSegmento.text = p.segmento;
        _logradouro.text = p.logradouro;
        _numero.text = p.numero;
        _bairro.text = p.bairro;
        _cidade.text = p.cidade;
        _uf.text = p.uf;
        _cep.text = p.cep;
      } else {
        _editingProfile = true;
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  // ===== AppBar / ações =====
  String get _iniciais {
    final s = _profNome.text.trim();
    if (s.isEmpty) return 'MGL';
    final parts = s.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    final a = parts.isNotEmpty ? parts[0][0] : '';
    final b = parts.length > 1 ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  void _goClients() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ClientsPage()));
  }

  Future<void> _goNewFromHere() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HomePage(startNew: true)));
  }

  void _logout() async {
    await store.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ===== Logo =====
  int _logoMaxKB(String size) {
    switch (size) {
      case 'small':
        return 64;
      case 'large':
        return 512;
      case 'medium':
      default:
        return 256;
    }
  }

  Future<void> _pickLogo() async {
    setState(() => _loadingLogo = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (res != null &&
          res.files.isNotEmpty &&
          res.files.single.bytes != null) {
        final bytes = res.files.single.bytes!;
        final maxKB = _logoMaxKB(_logoSize);
        final sizeKB = (bytes.lengthInBytes / 1024).ceil();
        if (sizeKB > maxKB) {
          throw Exception(
              'Arquivo muito grande (${sizeKB}KB). Máx ($_logoSize): ${maxKB}KB');
        }
        await store.saveLogoBytes(bytes);
        setState(() => _logoBytes = bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo atualizada!')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao carregar logo: $e')));
    } finally {
      if (mounted) setState(() => _loadingLogo = false);
    }
  }

  // ===== Custom fields =====
  Future<void> _addCustomField() async {
    final name = _newFieldCtrl.text.trim();
    if (name.isEmpty) return;
    if (_customFields.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campo já existe.')));
      return;
    }
    setState(() {
      _customFields.add(name);
      _newFieldCtrl.clear();
    });
    await store.setCustomClientFields(_customFields);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Campo adicionado.')));
  }

  Future<void> _removeCustomField(String name) async {
    setState(() => _customFields.remove(name));
    await store.setCustomClientFields(_customFields);
  }

  Future<void> _moveField(int index, int delta) async {
    final n = index + delta;
    if (n < 0 || n >= _customFields.length) return;
    setState(() {
      final val = _customFields.removeAt(index);
      _customFields.insert(n, val);
    });
    await store.setCustomClientFields(_customFields);
  }

  // ===== Profile =====
  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final p = Profissional(
      nome: _profNome.text.trim(),
      telefone: _profTelefone.text.trim(),
      segmento: _profSegmento.text.trim(),
      logradouro: _logradouro.text.trim(),
      numero: _numero.text.trim(),
      bairro: _bairro.text.trim(),
      cidade: _cidade.text.trim(),
      uf: _uf.text.trim(),
      cep: _cep.text.trim(),
    );
    await store.savePerfilProfissional(p);
    await store.setWebhookUrl(_webhook.text.trim());
    _perfilAtual = p;
    setState(() {
      _editingProfile = false;
      // Ao salvar, “destrava” o latch de CEP (se usuário quiser buscar de novo)
      _cepLookupLatched = false;
      _cepUserEdited = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados do profissional salvos!')));
  }

  // === EXCLUIR PERFIL (persistente) ===
  Future<void> _deleteProfile() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir perfil do profissional?'),
        content: const Text('Essa ação removerá o cadastro salvo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await store.deletePerfilProfissional(); // remove do storage

      // Limpa UI local
      _perfilAtual = null;
      _profNome.clear();
      _profTelefone.clear();
      _profSegmento.clear();
      _logradouro.clear();
      _numero.clear();
      _bairro.clear();
      _cidade.clear();
      _uf.clear();
      _cep.clear();
      setState(() {
        _editingProfile = true;
        _cepLookupLatched = false;
        _cepUserEdited = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil removido.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao excluir: $e')));
    }
  }

  // ===== CEP (profissional) — com debounce e “latch” de erro =====
  void _debouncedCepListener() {
    // Só tenta se o usuário editou e não está “travado” por erro
    if (!_cepUserEdited || _cepLookupLatched) return;

    _cepDebounce?.cancel();
    _cepDebounce = Timer(const Duration(milliseconds: 350), _fetchProfCepIfReady);
  }

  Future<void> _fetchProfCepIfReady() async {
    if (_cepLookupLatched) return; // travado após erro
    final digits = _cep.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_buscandoProfCep || digits.length != 8) return;
    setState(() => _buscandoProfCep = true);
    try {
      final r = await http
          .get(Uri.parse('https://viacep.com.br/ws/$digits/json/'))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (r.statusCode != 200) {
        _latchCepError();
        return;
      }
      final j = jsonDecode(r.body);
      if (j is Map && j['erro'] == true) {
        _latchCepError();
        return;
      }
      // Preenche campos
      _logradouro.text = (j['logradouro'] ?? '').toString();
      _bairro.text = (j['bairro'] ?? '').toString();
      _cidade.text = (j['localidade'] ?? '').toString();
      _uf.text = (j['uf'] ?? '').toString().toUpperCase();
    } catch (_) {
      if (!mounted) return;
      _latchCepError();
    } finally {
      if (mounted) setState(() => _buscandoProfCep = false);
    }
  }

  void _latchCepError() {
    // Mostra o alerta uma única vez e trava novas buscas até o usuário editar o CEP
    _cepLookupLatched = true;
    _cepUserEdited = false; // precisa editar novamente para destravar
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Não foi possível carregar o CEP'),
        content: const Text(
            'Verifique o CEP informado.\nVocê pode preencher o endereço manualmente.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tema compacto — igual densidade da Home
    final compactInputs = Theme.of(context).inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        );

    final pageTheme = Theme.of(context).copyWith(
      inputDecorationTheme: compactInputs,
    );

    final surfaceAlt = Theme.of(context)
        .colorScheme
        .surfaceVariant
        .withOpacity(Theme.of(context).brightness == Brightness.dark ? .25 : .5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações',
            style: TextStyle(fontWeight: FontWeight.w600)),
        flexibleSpace: AppTheme.appBarGradientBackground(),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Clientes',
            onPressed: _goClients,
            icon: const Icon(Icons.group_outlined),
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          TextButton(
            onPressed: _goNewFromHere,
            child: const Text('+ Novo',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              tooltip: 'Perfil',
              offset: const Offset(0, kToolbarHeight),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'logout') _logout();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                        leading: Icon(Icons.logout), title: Text('Sair'))),
              ],
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.navy700,
                backgroundImage:
                    _logoBytes != null ? MemoryImage(_logoBytes!) : null,
                child: _logoBytes == null
                    ? Text(_iniciais,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12))
                    : null,
              ),
            ),
          ),
        ],
      ),

      // aplica o tema compacto nos campos
      body: Theme(
        data: pageTheme,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- LOGO + WEBHOOK ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12), // padding menor
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Logo',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _logoSize,
                            items: const [
                              DropdownMenuItem(
                                  value: 'small', child: Text('Pequeno')),
                              DropdownMenuItem(
                                  value: 'medium', child: Text('Médio')),
                              DropdownMenuItem(
                                  value: 'large', child: Text('Grande')),
                            ],
                            onChanged: (v) =>
                                setState(() => _logoSize = v ?? 'medium'),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.image_outlined),
                              labelText: 'Tamanho do Logo',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: _filledPrimaryStyle,
                          onPressed: _loadingLogo ? null : _pickLogo,
                          icon: const Icon(Icons.upload),
                          label: const Text('Carregar Logo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_logoBytes != null)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: surfaceAlt,
                        ),
                        padding: const EdgeInsets.all(8),
                        child:
                            SizedBox(height: 72, child: Image.memory(_logoBytes!)),
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _webhook,
                      decoration: const InputDecoration(
                        labelText: 'Webhook n8n (opcional)',
                        prefixIcon: Icon(Icons.link_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- CAMPOS PERSONALIZADOS ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Campos personalizados do Cliente',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newFieldCtrl,
                            decoration: const InputDecoration(
                              labelText:
                                  'Nome do campo (ex.: Placa, Modelo, Cor...)',
                              prefixIcon: Icon(Icons.edit_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: _filledPrimaryStyle,
                          onPressed: _addCustomField,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_customFields.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Nenhum campo extra cadastrado.',
                            style: TextStyle(color: Colors.white70)),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < _customFields.length; i++)
                            Card(
                              color: surfaceAlt,
                              child: ListTile(
                                dense: true,
                                title: Text(_customFields[i],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                trailing: Wrap(
                                  spacing: 0,
                                  children: [
                                    IconButton(
                                      tooltip: 'Mover para cima',
                                      onPressed: () => _moveField(i, -1),
                                      icon: const Icon(Icons.arrow_upward),
                                    ),
                                    IconButton(
                                      tooltip: 'Mover para baixo',
                                      onPressed: () => _moveField(i, 1),
                                      icon: const Icon(Icons.arrow_downward),
                                    ),
                                    IconButton(
                                      tooltip: 'Remover',
                                      onPressed: () =>
                                          _removeCustomField(_customFields[i]),
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- PERFIL PROFISSIONAL (view/editar) ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _editingProfile ? _profileForm() : _profileView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== VIEW ======
  Widget _profileView() {
    final p = _perfilAtual!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Perfil profissional',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _kv('Nome', p.nome),
        _kv('Telefone', p.telefone),
        if (p.segmento.trim().isNotEmpty) _kv('Segmento', p.segmento),
        const SizedBox(height: 6),
        _kv(
            'Endereço',
            [
              p.logradouro,
              if (p.numero.isNotEmpty) 'Nº ${p.numero}',
              if (p.bairro.isNotEmpty) p.bairro,
              if (p.cidade.isNotEmpty) p.cidade,
              if (p.uf.isNotEmpty) p.uf,
              if (p.cep.isNotEmpty) p.cep,
            ].where((s) => s.trim().isNotEmpty).join(' • ')),
        const SizedBox(height: 10),
        // Editar + Excluir
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              style: _filledPrimaryStyle,
              onPressed: () => setState(() {
                _editingProfile = true;
                // Ao entrar no modo de edição, o próximo onChanged destrava o latch
              }),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _deleteProfile,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Excluir'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  // ====== FORM (layout igual ao da Home) ======
  Widget _profileForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _grid([
            TextFormField(
              controller: _profNome,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _req,
            ),
            TextFormField(
              controller: _profTelefone,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: _req,
            ),
            TextFormField(
              controller: _profSegmento,
              decoration: const InputDecoration(
                labelText: 'Segmento',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // ORDEM INVERTIDA: Número vem ANTES de Logradouro
          _grid([
            // CEP (com loader no suffix e busca automática igual Home)
            Focus(
              focusNode: _cepFocus,
              child: TextFormField(
                controller: _cep,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  // usuário mexeu -> pode tentar novamente
                  _cepUserEdited = true;
                  _cepLookupLatched = false;
                },
                decoration: InputDecoration(
                  labelText: 'CEP',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: _buscandoProfCep
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
              controller: _numero,
              decoration: const InputDecoration(
                labelText: 'Número',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            TextFormField(
              controller: _logradouro,
              decoration: const InputDecoration(
                labelText: 'Logradouro',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            TextFormField(
              controller: _bairro,
              decoration: const InputDecoration(
                labelText: 'Bairro',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            TextFormField(
              controller: _cidade,
              decoration: const InputDecoration(
                labelText: 'Cidade',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            TextFormField(
              controller: _uf,
              decoration: const InputDecoration(
                labelText: 'UF',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: _filledPrimaryStyle,
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar'),
                ),
              ),
              const SizedBox(width: 8),
              if (_perfilAtual != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _editingProfile = false;
                        final p = _perfilAtual!;
                        _profNome.text = p.nome;
                        _profTelefone.text = p.telefone;
                        _profSegmento.text = p.segmento;
                        _logradouro.text = p.logradouro;
                        _numero.text = p.numero;
                        _bairro.text = p.bairro;
                        _cidade.text = p.cidade;
                        _uf.text = p.uf;
                        _cep.text = p.cep;
                        // cancelar: trava novamente até o próximo onChanged
                        _cepLookupLatched = false;
                        _cepUserEdited = false;
                      });
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // === Grade idêntica à Home (2 colunas > 700px; espaçamentos e razão) ===
  Widget _grid(List<Widget> children) {
    return LayoutBuilder(builder: (ctx, c) {
      final two = c.maxWidth > 700;
      return GridView.count(
        crossAxisCount: two ? 2 : 1,
        childAspectRatio: two ? 3.6 : 3.1, // igual à Home
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        mainAxisSpacing: 10, // igual à Home
        crossAxisSpacing: 10, // igual à Home
        children: children,
      );
    });
  }
}
