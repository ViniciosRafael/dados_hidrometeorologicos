import 'package:flutter/material.dart';

import '../domain/nivel.dart';
import '../domain/nivel_chuva.dart';
import '../models/estacao.dart';
import '../models/situacao_estacao.dart';
import '../state/monitoramento_controller.dart';
import '../util/formatacao.dart';
import '../widgets/grafico_historico.dart';
import '../widgets/nivel_badge.dart';

/// Detalhe de uma estação: os três indicadores (HM-08), avisos de dados
/// (HM-09), medidas disponíveis (HM-03), chuva × limiares (HM-06) e o
/// gráfico histórico (HM-04).
class DetalheScreen extends StatelessWidget {
  const DetalheScreen({super.key, required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context) {
    final c = MonitoramentoScope.of(context);
    final e = c.estacao(codigo);
    final s = c.situacao(codigo);

    if (e == null) {
      return Scaffold(
        appBar: AppBar(title: Text(codigo)),
        body: const Center(child: Text('Estação sem dados no momento.')),
      );
    }
    final favorita = c.ehFavorita(codigo);

    return Scaffold(
      appBar: AppBar(
        title: Text(e.nome, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: favorita ? 'Remover das favoritas' : 'Adicionar às favoritas',
            icon: Icon(favorita ? Icons.star : Icons.star_border),
            color: favorita ? Colors.amber.shade700 : null,
            onPressed: () => c.alternarFavorita(codigo),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => c.atualizar(manual: true),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _Cabecalho(estacao: e),
            const SizedBox(height: 8),
            ..._avisosDeDados(context, e),
            if (s != null) ...[
              _Indicadores(situacao: s),
              const SizedBox(height: 12),
              if (e.sensores.chuva) _ChuvaLimiares(situacao: s),
            ],
            const SizedBox(height: 12),
            _Medidas(estacao: e),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Histórico',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    GraficoHistorico(estacao: e, api: c.api),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Indicação de potencial risco, não é previsão de enchente e não '
              'substitui os comunicados da Defesa Civil. Fonte: Rede '
              'Hidrometeorológica da Defesa Civil RS.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _avisosDeDados(BuildContext context, Estacao e) {
    final tema = Theme.of(context);
    final avisos = <(IconData, String)>[
      if (e.semLeitura)
        (Icons.signal_wifi_off, 'Estação sem leitura recente.')
      else if (e.estaAtrasada())
        (
          Icons.schedule,
          'Dados atrasados: última medição ${formatarTempoDecorrido(e.ultimaLeitura!)}.'
        ),
      if (e.emManutencao)
        (Icons.build_circle_outlined, 'Estação em manutenção.'),
      if (e.temDadoNaoHomologado)
        (
          Icons.report_gmailerrorred,
          'Há sensor com dado não homologado (pode conter erro).'
        ),
    ];
    return [
      for (final (icone, texto) in avisos)
        Card(
          color: tema.colorScheme.errorContainer,
          child: ListTile(
            dense: true,
            leading: Icon(icone, color: tema.colorScheme.onErrorContainer),
            title: Text(texto,
                style: TextStyle(color: tema.colorScheme.onErrorContainer)),
          ),
        ),
    ];
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.estacao});

  final Estacao estacao;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final e = estacao;
    final leitura = e.ultimaLeitura;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.nome, style: tema.textTheme.headlineSmall),
        Text(
          [
            e.regiao?.rotulo,
            if (e.bacia != null) 'Bacia ${e.bacia}',
            e.codigo,
          ].whereType<String>().join(' · '),
          style: tema.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.update, size: 16, color: tema.hintColor),
            const SizedBox(width: 4),
            Text(
              leitura == null
                  ? 'Sem leitura'
                  : 'Medição de ${formatarDataHora(leitura)} '
                      '(${formatarTempoDecorrido(leitura)})',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.situacao});

  final SituacaoEstacao situacao;

  @override
  Widget build(BuildContext context) {
    Widget linha(String titulo, IconData icone, ResultadoNivel r,
            {bool destaque = false}) =>
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: r.cor.withValues(alpha: destaque ? 1 : 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: r.cor, width: 1.5),
          ),
          child: ListTile(
            leading: Icon(icone,
                color: destaque ? r.corTexto : r.cor, size: destaque ? 32 : 26),
            title: Text(
              '$titulo: ${r.rotulo}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: destaque ? r.corTexto : null,
              ),
            ),
            subtitle: Text(
              r.motivo,
              style: TextStyle(color: destaque ? r.corTexto : null),
            ),
          ),
        );

    return Column(
      children: [
        linha('Nível geral', IconesNivel.geral, situacao.geral,
            destaque: true),
        linha('Rio', IconesNivel.rio, situacao.rio),
        linha('Chuva', IconesNivel.chuva, situacao.chuva),
      ],
    );
  }
}

/// Acumulados de 24/48/72 h comparados aos limiares (HM-06).
class _ChuvaLimiares extends StatelessWidget {
  const _ChuvaLimiares({required this.situacao});

  final SituacaoEstacao situacao;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final valores = {24: situacao.mm24, 48: situacao.mm48, 72: situacao.mm72};

    Widget celula(String texto, {Color? cor, bool negrito = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cor,
              fontWeight: negrito ? FontWeight.bold : null,
            ),
          ),
        );

    Color? corDoValor(int janela, double? v) {
      if (v == null) return null;
      Color? cor;
      for (final entrada in limiaresChuva.entries) {
        if (v >= entrada.value.paraJanela(janela)) cor = entrada.key.cor;
      }
      return cor;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chuva acumulada × limiares',
                style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.symmetric(
                inside: BorderSide(color: tema.dividerColor),
              ),
              children: [
                TableRow(children: [
                  celula('Janela', negrito: true),
                  celula('Medido', negrito: true),
                  for (final n in limiaresChuva.keys)
                    celula(rotulosChuva[n]!, cor: n.cor, negrito: true),
                ]),
                for (final janela in [24, 48, 72])
                  TableRow(children: [
                    celula('$janela h'),
                    celula(
                      valores[janela] == null
                          ? '—'
                          : '${formatarNumero(valores[janela]!, 1)} mm',
                      cor: corDoValor(janela, valores[janela]),
                      negrito: true,
                    ),
                    for (final l in limiaresChuva.values)
                      celula('≥ ${formatarNumero(l.paraJanela(janela), 0)}'),
                  ]),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Regra do documento de requisitos: vale o maior nível atingido '
              'em qualquer janela. O acumulado de 72 h é somado a partir do '
              'histórico da estação.',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Todas as medidas que a estação realmente tem (HM-03).
class _Medidas extends StatelessWidget {
  const _Medidas({required this.estacao});

  final Estacao estacao;

  @override
  Widget build(BuildContext context) {
    final e = estacao;
    final itens = <_ItemMedida>[
      if (e.sensores.nivelRio) ...[
        _ItemMedida(Icons.water, 'Nível do rio', e.rio.nivel, 'm', 2,
            tendencia: e.rio.tendencia),
      ],
      if (e.sensores.chuva) ...[
        _ItemMedida(Icons.grain, 'Chuva 1 h', e.chuva.h1, 'mm', 1),
        _ItemMedida(Icons.grain, 'Chuva 6 h', e.chuva.h6, 'mm', 1),
        _ItemMedida(Icons.grain, 'Chuva 7 dias', e.chuva.h168, 'mm', 1),
      ],
      _ItemMedida(Icons.thermostat, 'Temperatura', e.temperatura.atual, '°C', 1,
          tendencia: e.temperatura.tendencia,
          extra: e.temperatura.minimaHoje != null &&
                  e.temperatura.maximaHoje != null
              ? 'Hoje: mín ${formatarNumero(e.temperatura.minimaHoje!, 1)} · '
                  'máx ${formatarNumero(e.temperatura.maximaHoje!, 1)} °C'
              : null),
      if (e.sensores.sensacaoTermica)
        _ItemMedida(Icons.device_thermostat, 'Sensação térmica',
            e.sensacaoTermica.atual, '°C', 1),
      if (e.sensores.umidade)
        _ItemMedida(Icons.water_drop_outlined, 'Umidade relativa',
            e.umidade.atual, '%', 0),
      if (e.sensores.pressao)
        _ItemMedida(Icons.speed, 'Pressão atmosférica', e.pressao.atual,
            'hPa', 1,
            tendencia: e.pressao.tendencia),
      if (e.sensores.vento) ...[
        _ItemMedida(Icons.air, 'Vento médio', e.vento.velocidadeMedia, 'km/h',
            1,
            extra: e.vento.direcao == null
                ? null
                : 'Direção ${direcaoCardeal(e.vento.direcao!)} '
                    '(${formatarNumero(e.vento.direcao!, 0)}°)'),
        _ItemMedida(Icons.air, 'Rajada (máx.)', e.vento.velocidadeMaxima,
            'km/h', 1),
      ],
      if (e.radiacao.atual != null)
        _ItemMedida(Icons.wb_sunny_outlined, 'Radiação solar', e.radiacao.atual,
            'W/m²', 0),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Medidas atuais',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final item in itens) item,
          ],
        ),
      ),
    );
  }
}

class _ItemMedida extends StatelessWidget {
  const _ItemMedida(
    this.icone,
    this.rotulo,
    this.valor,
    this.unidade,
    this.casas, {
    this.tendencia,
    this.extra,
  });

  final IconData icone;
  final String rotulo;
  final double? valor;
  final String unidade;
  final int casas;
  final double? tendencia;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final t = tendencia;
    IconData? seta;
    if (t != null && t.abs() >= 0.005) {
      seta = t > 0 ? Icons.arrow_upward : Icons.arrow_downward;
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone),
      title: Text(rotulo),
      subtitle: extra == null ? null : Text(extra!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (seta != null)
            Tooltip(
              message: 'Tendência em relação à média da última hora',
              child: Icon(seta, size: 16),
            ),
          Text(
            valor == null
                ? 'sem dado'
                : '${formatarNumero(valor!, casas)} $unidade',
            style: tema.textTheme.titleMedium?.copyWith(
              color: valor == null ? tema.hintColor : null,
            ),
          ),
        ],
      ),
    );
  }
}
