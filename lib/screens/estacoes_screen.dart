import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/estacoes_monitoradas.dart';
import '../domain/nivel.dart';
import '../models/estacao.dart';
import '../state/monitoramento_controller.dart';
import '../widgets/estacao_card.dart';
import '../widgets/grafico_historico.dart';
import '../widgets/nivel_badge.dart';
import '../widgets/status_atualizacao.dart';
import 'detalhe_screen.dart';

/// Tipo de estação para o filtro (HM-05). Na API todas são "HidroMeteo";
/// o tipo é definido pelos sensores que a estação tem.
enum TipoFiltro {
  todas('Todos os tipos'),
  fluviometrica('Com nível do rio'),
  pluviometrica('Com chuva'),
  meteorologica('Com vento/umidade');

  const TipoFiltro(this.rotulo);
  final String rotulo;

  bool aceita(Estacao e) => switch (this) {
        TipoFiltro.todas => true,
        TipoFiltro.fluviometrica => e.sensores.nivelRio,
        TipoFiltro.pluviometrica => e.sensores.chuva,
        TipoFiltro.meteorologica => e.sensores.vento || e.sensores.umidade,
      };
}

/// Lista e mapa das estações (HM-02) com busca e filtros (HM-05).
class EstacoesScreen extends StatefulWidget {
  const EstacoesScreen({super.key});

  @override
  State<EstacoesScreen> createState() => _EstacoesScreenState();
}

class _EstacoesScreenState extends State<EstacoesScreen> {
  final _busca = TextEditingController();
  Regiao? _regiao;
  String? _municipio;
  TipoFiltro _tipo = TipoFiltro.todas;
  bool _soFavoritas = false;
  bool _soEmAtencao = false;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  static List<String> _municipiosDe(Estacao e) =>
      municipiosDasEstacoes[e.codigo] ?? [e.nome];

  List<Estacao> _filtrar(MonitoramentoController c) {
    final termo = _normalizar(_busca.text);
    return c.estacoes.where((e) {
      if (_regiao != null && e.regiao != _regiao) return false;
      if (_municipio != null && !_municipiosDe(e).contains(_municipio)) {
        return false;
      }
      if (!_tipo.aceita(e)) return false;
      if (_soFavoritas && !c.ehFavorita(e.codigo)) return false;
      if (_soEmAtencao &&
          (c.situacao(e.codigo)?.geral.nivel?.valor ?? -1) <
              Nivel.atencao.valor) {
        return false;
      }
      if (termo.isNotEmpty &&
          !_normalizar('${e.nome} ${e.codigo} ${e.bacia ?? ''} '
                  '${_municipiosDe(e).join(' ')}')
              .contains(termo)) {
        return false;
      }
      return true;
    }).toList();
  }

  static String _normalizar(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? para[i] : ch);
    }
    return b.toString().toLowerCase().trim();
  }

  bool get _temFiltro =>
      _regiao != null ||
      _municipio != null ||
      _tipo != TipoFiltro.todas ||
      _soFavoritas ||
      _soEmAtencao;

  void _limparFiltros() => setState(() {
        _regiao = null;
        _municipio = null;
        _tipo = TipoFiltro.todas;
        _soFavoritas = false;
        _soEmAtencao = false;
      });

  @override
  Widget build(BuildContext context) {
    final c = MonitoramentoScope.of(context);
    final lista = _filtrar(c);
    final municipios = {
      for (final e in c.estacoes)
        if (_regiao == null || e.regiao == _regiao) ..._municipiosDe(e),
    }.toList()
      ..sort();
    if (_municipio != null && !municipios.contains(_municipio)) {
      _municipio = null;
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estações'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'Lista'),
              Tab(icon: Icon(Icons.map_outlined), text: 'Mapa'),
            ],
          ),
        ),
        body: Column(
          children: [
            const StatusAtualizacao(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: TextField(
                controller: _busca,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar estação, município ou código',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busca.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_busca.clear),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _MenuFiltro<Regiao?>(
                    rotulo: _regiao?.rotulo ?? 'Todas as regiões',
                    ativo: _regiao != null,
                    opcoes: {
                      null: 'Todas as regiões',
                      for (final r in Regiao.values) r: r.rotulo,
                    },
                    aoEscolher: (r) => setState(() => _regiao = r),
                  ),
                  _MenuFiltro<String?>(
                    rotulo: _municipio ?? 'Município',
                    ativo: _municipio != null,
                    opcoes: {
                      null: 'Todos os municípios',
                      for (final m in municipios) m: m,
                    },
                    aoEscolher: (m) => setState(() => _municipio = m),
                  ),
                  _MenuFiltro<TipoFiltro>(
                    rotulo: _tipo.rotulo,
                    ativo: _tipo != TipoFiltro.todas,
                    opcoes: {for (final t in TipoFiltro.values) t: t.rotulo},
                    aoEscolher: (t) => setState(() => _tipo = t),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('Favoritas'),
                      avatar: const Icon(Icons.star, size: 16),
                      selected: _soFavoritas,
                      onSelected: (v) => setState(() => _soFavoritas = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('Atenção ou acima'),
                      selected: _soEmAtencao,
                      onSelected: (v) => setState(() => _soEmAtencao = v),
                    ),
                  ),
                  if (_temFiltro)
                    TextButton(
                      onPressed: _limparFiltros,
                      child: const Text('Limpar'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Lista(estacoes: lista, carregando: c.semDadosAinda),
                  _Mapa(estacoes: lista),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuFiltro<T> extends StatelessWidget {
  const _MenuFiltro({
    required this.rotulo,
    required this.ativo,
    required this.opcoes,
    required this.aoEscolher,
  });

  final String rotulo;
  final bool ativo;
  final Map<T, String> opcoes;
  final ValueChanged<T> aoEscolher;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        // Usa o índice como valor: o PopupMenuButton ignora itens de valor
        // null, e "Todas as regiões"/"Todos os municípios" usam null.
        child: PopupMenuButton<int>(
          tooltip: 'Filtrar',
          onSelected: (i) => aoEscolher(opcoes.keys.elementAt(i)),
          itemBuilder: (_) => [
            for (var i = 0; i < opcoes.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Text(opcoes.values.elementAt(i)),
              ),
          ],
          child: Chip(
            label: Text(rotulo),
            avatar: const Icon(Icons.arrow_drop_down, size: 18),
            backgroundColor:
                ativo ? Theme.of(context).colorScheme.secondaryContainer : null,
          ),
        ),
      );
}

class _Lista extends StatelessWidget {
  const _Lista({required this.estacoes, required this.carregando});

  final List<Estacao> estacoes;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final c = MonitoramentoScope.of(context);
    if (carregando && c.carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (estacoes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhuma estação com esses filtros.',
              textAlign: TextAlign.center),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => c.atualizar(manual: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        itemCount: estacoes.length + 1,
        itemBuilder: (context, i) => i == 0
            ? Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Text(
                  '${estacoes.length} estação(ões) · ordenadas pelo nível geral',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            : EstacaoCard(estacao: estacoes[i - 1]),
      ),
    );
  }
}

class _Mapa extends StatelessWidget {
  const _Mapa({required this.estacoes});

  final List<Estacao> estacoes;

  /// Centro aproximado entre os dois vales.
  static final _centro = LatLng(-29.35, -52.15);

  @override
  Widget build(BuildContext context) {
    final c = MonitoramentoScope.of(context);
    final comCoordenadas = estacoes.where((e) => e.temCoordenadas).toList();

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _centro,
            initialZoom: 8.3,
            minZoom: 6,
            maxZoom: 16,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.dados_hidrometeorologicos',
            ),
            MarkerLayer(
              markers: [
                for (final e in comCoordenadas)
                  Marker(
                    point: LatLng(e.latitude!, e.longitude!),
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => _mostrarResumo(context, e),
                      child: Tooltip(
                        message: e.nome,
                        child: _Marcador(
                          cor: c.situacao(e.codigo)?.geral.cor ?? corSemNivel,
                          favorita: c.ehFavorita(e.codigo),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© colaboradores do OpenStreetMap'),
              ],
            ),
          ],
        ),
        Positioned(
          left: 8,
          right: 8,
          top: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cor = nível geral',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  const LegendaNiveis(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarResumo(BuildContext context, Estacao e) {
    final c = MonitoramentoScope.read(context);
    final s = c.situacao(e.codigo);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.nome, style: Theme.of(ctx).textTheme.titleLarge),
            Text('${e.regiao?.rotulo ?? ''} · ${e.codigo}'),
            const SizedBox(height: 12),
            if (s != null)
              Wrap(spacing: 6, runSpacing: 6, children: [
                NivelBadge(resultado: s.geral, icone: IconesNivel.geral),
                NivelBadge(resultado: s.rio, icone: IconesNivel.rio),
                NivelBadge(resultado: s.chuva, icone: IconesNivel.chuva),
              ]),
            if (s != null) ...[
              const SizedBox(height: 8),
              Text('Geral: ${s.geral.motivo}'),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DetalheScreen(codigo: e.codigo),
                ));
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver detalhes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.cor, required this.favorita});

  final Color cor;
  final bool favorita;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.location_on,
              size: 36,
              color: cor,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black45)]),
          if (favorita)
            const Positioned(
              top: 6,
              child: Icon(Icons.star, size: 12, color: Colors.white),
            ),
        ],
      );
}
