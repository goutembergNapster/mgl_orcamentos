import 'package:flutter/material.dart';
import '../models.dart';
import '../services/storage_service.dart';
import 'home_page.dart';

class OrcamentosPage extends StatefulWidget {
  const OrcamentosPage({super.key});

  @override
  State<OrcamentosPage> createState() => _OrcamentosPageState();
}

class _OrcamentosPageState extends State<OrcamentosPage> {
  final store = StorageService();
  bool _loading = true;
  List<Orcamento> _list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await store.getOrcamentos();
      items.sort((a, b) => b.data.compareTo(a.data));
      setState(() {
        _list = items;
      });
    } catch (_) {
      setState(() => _list = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remover(Orcamento o) async {
    // não temos método remove direto no storage, então regrava sem o item:
    final all = await store.getOrcamentos();
    all.removeWhere((x) => x.id == o.id);
    // reusa saveOrcamento para sobrescrever conjunto:
    // como não há API pública para setar a lista inteira, salvamos 1 a 1:
    // (mantém compat com seu StorageService atual)
    for (final it in all) {
      await store.saveOrcamento(it);
    }
    await _load();
  }

  Future<void> _editarComoNovo(Orcamento o) async {
    // Compatível com HomePage SEM parâmetro `template`.
    // Enviamos o 'o' via argumentos da rota; se o seu HomePage consumir,
    // ele pré-preenche. Se não consumir, segue normal sem quebrar a compilação.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HomePage(),
        settings: RouteSettings(arguments: o),
      ),
    );
    await _load();
  }

  String _fmtData(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orçamentos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('Nenhum orçamento encontrado.'))
              : ListView.separated(
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final o = _list[i];
                    return ListTile(
                      title: Text(
                        o.cliente.nome,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Data: ${_fmtData(o.data)}  •  Total: ${o.total.toStringAsFixed(2)}',
                      ),
                      onTap: () => _editarComoNovo(o),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar como novo',
                            icon: const Icon(Icons.copy_all_outlined),
                            onPressed: () => _editarComoNovo(o),
                          ),
                          IconButton(
                            tooltip: 'Excluir',
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Excluir orçamento'),
                                  content: const Text(
                                      'Tem certeza que deseja excluir este orçamento?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) await _remover(o);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
