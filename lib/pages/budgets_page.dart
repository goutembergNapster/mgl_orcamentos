// lib/pages/budgets_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart'; // <- para PdfPageFormat

import 'package:orcamento_app/models.dart';
import 'package:orcamento_app/services/storage_service.dart';
import 'package:orcamento_app/services/pdf_service.dart';

// Se você quiser abrir a Home a partir daqui, importe com alias
import 'home_page.dart' as home;

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key, this.filterCliente});

  /// Quando vier da página de clientes, podemos filtrar pelos orçamentos daquele cliente
  final Cliente? filterCliente;

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  final store = StorageService();
  final _q = TextEditingController();

  List<Orcamento> _all = [];
  List<Orcamento> _filtered = [];

  // paginação simples (10 em 10, igual Clientes)
  int _visible = 10;

  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _load();
    _q.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dados = await store.getOrcamentos();
    final logo = await store.getLogoBytes();

    // ordena por data desc
    dados.sort((a, b) => b.data.compareTo(a.data));

    // filtra por cliente, se veio da ClientsPage
    List<Orcamento> base = dados;
    final f = widget.filterCliente;
    if (f != null) {
      final fTel = f.telefone.replaceAll(RegExp(r'\D'), '');
      base = dados.where((o) {
        final oTel = o.cliente.telefone.replaceAll(RegExp(r'\D'), '');
        return oTel == fTel;
      }).toList();
    }

    setState(() {
      _logoBytes = logo;
      _all = base;
      _filtered = List.from(base);
      _visible = 10;
    });
  }

  void _applyFilter() {
    final s = _q.text.trim().toLowerCase();
    setState(() {
      if (s.isEmpty) {
        _filtered = List.from(_all);
      } else {
        _filtered = _all.where((o) {
          final id = o.id.toLowerCase();
          final nome = o.cliente.nome.toLowerCase();
          final telDigits = o.cliente.telefone.replaceAll(RegExp(r'\D'), '');
          final inId = id.contains(s);
          final inNome = nome.contains(s);
          final inTel = telDigits.contains(s.replaceAll(RegExp(r'\D'), ''));
          return inId || inNome || inTel;
        }).toList();
      }
      _visible = 10;
    });
  }

  void _loadMore() {
    setState(() {
      _visible = (_visible + 10).clamp(0, _filtered.length);
    });
  }

  Future<void> _delete(Orcamento o) async {
    await store.deleteOrcamentoById(o.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Orçamento excluído.')));
  }

  Future<void> _reprint(Orcamento o) async {
    try {
      final bytes = await gerarPdfBytes(o, logoBytes: _logoBytes);
      await Printing.sharePdf(bytes: bytes, filename: 'orcamento_${o.id}.pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF reimpresso: orcamento_${o.id}.pdf')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao reimprimir: $e')),
      );
    }
  }

  Future<void> _edit(Orcamento o) async {
    // Agora abrimos a Home já com o orçamento carregado
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => home.HomePage(orcToEdit: o)),
    );
    await _load();
  }

  // ===== NOVO: Pré-visualização com compartilhar/imprimir (lupa) =====
  void _preview(Orcamento o) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text('Orçamento #${o.id}'),
            // mesmo gradiente usado aqui na BudgetsPage
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
          ),
          body: PdfPreview(
            build: (PdfPageFormat format) async {
              return gerarPdfBytes(o, logoBytes: _logoBytes);
            },
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            pdfFileName: 'orcamento_${o.id}.pdf',
            initialPageFormat: PdfPageFormat.a4,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final total = _filtered.length;
    final showing = total <= _visible ? total : _visible;
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamentos'),
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
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            color: onPrimary,
          ),
        ],
      ),
      body: Column(
        children: [
          // busca clara, texto escuro (igual ClientsPage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _q,
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.search, color: Colors.black54),
                hintText: 'Buscar por ID, cliente ou telefone...',
                hintStyle: TextStyle(color: Colors.black45),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF64748B)),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        Center(child: Text('Nenhum orçamento.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: showing + (showing < total ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
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

                        final o = _filtered[i];
                        final totalItens = o.itens.fold<double>(
                          0,
                          (sum, it) => sum + (it.subtotal),
                        );
                        final totalFinal =
                            totalItens - (o.desconto) + (o.acrescimos);

                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(
                              'Orçamento ${o.id}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${o.cliente.nome} • ${o.cliente.telefone} • ${dateFmt.format(o.data)}\nTotal: ${currency.format(totalFinal)}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                // NOVO: visualizar (lupa) com preview/compartilhar
                                IconButton(
                                  tooltip: 'Visualizar',
                                  onPressed: () => _preview(o),
                                  icon: const Icon(Icons.search,
                                      color: Colors.black54),
                                ),
                                IconButton(
                                  tooltip: 'Reimprimir (PDF)',
                                  onPressed: () => _reprint(o),
                                  icon: const Icon(Icons.picture_as_pdf,
                                      color: Colors.black54),
                                ),
                                IconButton(
                                  tooltip: 'Editar (abre Home)',
                                  onPressed: () => _edit(o),
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.black54),
                                ),
                                IconButton(
                                  tooltip: 'Excluir',
                                  onPressed: () => _delete(o),
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                ),
                              ],
                            ),
                            // (opcional) tocar no card também abre preview:
                            // onTap: () => _preview(o),
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
