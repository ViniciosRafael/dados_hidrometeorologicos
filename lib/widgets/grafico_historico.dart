import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../domain/nivel.dart';
import '../domain/nivel_chuva.dart';
import '../models/estacao.dart';
import '../models/leitura_historica.dart';
import '../services/api_service.dart';
import '../util/formatacao.dart';

/// Períodos oferecidos no gráfico e o agrupamento usado em cada um.
enum PeriodoGrafico {
  h24('24 h', Duration(hours: 24), IntervaloHistorico.min10),
  h72('72 h', Duration(hours: 72), IntervaloHistorico.hora1),
  d7('7 dias', Duration(days: 7), IntervaloHistorico.hora3),
  d30('30 dias', Duration(days: 30), IntervaloHistorico.hora6),
  d90('90 dias', Duration(days: 89), IntervaloHistorico.hora12);

  const PeriodoGrafico(this.rotulo, this.duracao, this.intervalo);
  final String rotulo;
  final Duration duracao;
  final IntervaloHistorico intervalo;

  /// Janela (h) da regra de chuva que corresponde ao período, se houver.
  int? get janelaChuva => switch (this) {
        PeriodoGrafico.h24 => 24,
        PeriodoGrafico.h72 => 72,
        _ => null,
      };
}

/// Variáveis que podem ser vistas no gráfico.
enum VariavelGrafico {
  nivelRio('Nível do rio', 'm', 2, Color(0xFF1565C0)),
  chuva('Chuva acumulada', 'mm', 1, Color(0xFF00838F)),
  temperatura('Temperatura', '°C', 1, Color(0xFFD84315)),
  umidade('Umidade', '%', 0, Color(0xFF6A1B9A)),
  vento('Vento (média)', 'km/h', 1, Color(0xFF455A64));

  const VariavelGrafico(this.rotulo, this.unidade, this.casas, this.cor);
  final String rotulo;
  final String unidade;
  final int casas;
  final Color cor;

  static List<VariavelGrafico> disponiveis(Estacao e) => [
        if (e.sensores.nivelRio) nivelRio,
        if (e.sensores.chuva) chuva,
        temperatura,
        if (e.sensores.umidade) umidade,
        if (e.sensores.vento) vento,
      ];
}

/// Gráfico da série histórica de uma estação (HM-04), com as linhas de
/// limiar de chuva quando o período corresponde a uma janela da regra
/// (HM-06).
class GraficoHistorico extends StatefulWidget {
  const GraficoHistorico({super.key, required this.estacao, required this.api});

  final Estacao estacao;
  final ApiService api;

  @override
  State<GraficoHistorico> createState() => _GraficoHistoricoState();
}

class _GraficoHistoricoState extends State<GraficoHistorico> {
  late List<VariavelGrafico> _variaveis;
  late VariavelGrafico _variavel;
  PeriodoGrafico _periodo = PeriodoGrafico.h24;

  final Map<PeriodoGrafico, List<LeituraHistorica>> _cache = {};
  bool _carregando = false;
  String? _erro;
  DateTime? _inicio;

  @override
  void initState() {
    super.initState();
    _variaveis = VariavelGrafico.disponiveis(widget.estacao);
    _variavel = _variaveis.first;
    _carregar();
  }

  Future<void> _carregar({bool forcar = false}) async {
    if (!forcar && _cache.containsKey(_periodo)) return;
    final periodo = _periodo;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final fim = DateTime.now();
    final inicio = fim.subtract(periodo.duracao);
    try {
      final leituras = await widget.api.buscarHistorico(
        codigo: widget.estacao.codigo,
        inicio: inicio,
        fim: fim,
        intervalo: periodo.intervalo,
      );
      if (!mounted) return;
      setState(() {
        _cache[periodo] = leituras;
        _inicio = inicio;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  double? _valor(LeituraHistorica l) => switch (_variavel) {
        VariavelGrafico.nivelRio => l.nivelRio,
        VariavelGrafico.chuva => l.chuvaMm,
        VariavelGrafico.temperatura => l.temperatura,
        VariavelGrafico.umidade => l.umidade,
        VariavelGrafico.vento => l.ventoMedio,
      };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final v in _variaveis)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(v.rotulo),
                    selected: v == _variavel,
                    onSelected: (_) => setState(() => _variavel = v),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<PeriodoGrafico>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final p in PeriodoGrafico.values)
              ButtonSegment(value: p, label: Text(p.rotulo)),
          ],
          selected: {_periodo},
          onSelectionChanged: (s) {
            setState(() => _periodo = s.first);
            _carregar();
          },
        ),
        const SizedBox(height: 12),
        SizedBox(height: 260, child: _conteudo(tema)),
        const SizedBox(height: 4),
        Text(
          'Unidade: ${_variavel.unidade} · agrupamento de '
          '${_descricaoIntervalo(_periodo.intervalo)} · horário de Brasília'
          '${_variavel == VariavelGrafico.chuva ? ' · soma da chuva desde o início do período' : ''}',
          style: tema.textTheme.bodySmall,
        ),
        if (_variavel == VariavelGrafico.chuva && _periodo.janelaChuva == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'As linhas de limiar aparecem nos períodos de 24 h e 72 h, '
              'que correspondem às janelas da regra de chuva.',
              style: tema.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  String _descricaoIntervalo(IntervaloHistorico i) {
    final m = i.duracao.inMinutes;
    return m < 60 ? '$m min' : '${i.duracao.inHours} h';
  }

  Widget _conteudo(ThemeData tema) {
    if (_carregando && !_cache.containsKey(_periodo)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null && !_cache.containsKey(_periodo)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => _carregar(forcar: true),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    final leituras = _cache[_periodo] ?? const [];
    final inicio = _inicio ?? DateTime.now().subtract(_periodo.duracao);

    // x = horas desde o início do período.
    double x(DateTime t) => t.difference(inicio).inMinutes / 60.0;

    final spots = <FlSpot>[];
    double acumulado = 0;
    for (final l in leituras) {
      final v = _valor(l);
      if (_variavel == VariavelGrafico.chuva) {
        if (v != null) acumulado += v;
        spots.add(FlSpot(x(l.horario), acumulado));
      } else {
        spots.add(v == null ? FlSpot.nullSpot : FlSpot(x(l.horario), v));
      }
    }
    final validos = spots.where((s) => !s.isNull()).toList();
    if (validos.isEmpty) {
      return const Center(child: Text('Sem dados para este período.'));
    }

    // Linhas de limiar de chuva (HM-06).
    final linhas = <HorizontalLine>[];
    final janela = _periodo.janelaChuva;
    if (_variavel == VariavelGrafico.chuva && janela != null) {
      for (final entrada in limiaresChuva.entries) {
        final valor = entrada.value.paraJanela(janela);
        linhas.add(HorizontalLine(
          y: valor,
          color: entrada.key.cor,
          strokeWidth: 1.5,
          dashArray: const [6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            style: TextStyle(
              color: entrada.key.cor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            labelResolver: (_) =>
                '${rotulosChuva[entrada.key]} ${formatarNumero(valor, 0)} mm',
          ),
        ));
      }
    }

    var minY = validos.map((s) => s.y).reduce(math.min);
    var maxY = validos.map((s) => s.y).reduce(math.max);
    if (linhas.isNotEmpty) {
      maxY = math.max(maxY, linhas.map((l) => l.y).reduce(math.max) * 1.05);
      minY = 0;
    }
    if (_variavel == VariavelGrafico.chuva) minY = 0;
    if (maxY - minY < 0.1) {
      maxY += 0.5;
      minY -= _variavel == VariavelGrafico.chuva ? 0 : 0.5;
    }
    final margem = (maxY - minY) * 0.08;
    final maxX = _periodo.duracao.inMinutes / 60.0;
    final curto = _periodo.duracao <= const Duration(hours: 72);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY - (minY == 0 ? 0 : margem),
        maxY: maxY + margem,
        clipData: const FlClipData.all(),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(horizontalLines: linhas),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: _variavel.cor,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: _variavel.cor.withValues(alpha: 0.12),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            axisNameWidget: Text(_variavel.unidade,
                style: tema.textTheme.labelSmall),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (valor, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatarNumero(valor, _variavel.casas > 1 ? 1 : 0),
                  style: tema.textTheme.labelSmall,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxX / 4,
              getTitlesWidget: (valor, meta) {
                final t = inicio.add(Duration(minutes: (valor * 60).round()));
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    curto
                        ? formatarHora(t)
                        : formatarDataHoraCurta(t).split(' ').first,
                    style: tema.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tema.colorScheme.inverseSurface,
            getTooltipItems: (tocados) => [
              for (final s in tocados)
                LineTooltipItem(
                  '${formatarNumero(s.y, _variavel.casas)} ${_variavel.unidade}\n'
                  '${formatarDataHoraCurta(inicio.add(Duration(minutes: (s.x * 60).round())))}',
                  TextStyle(color: tema.colorScheme.onInverseSurface),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legenda das cores dos níveis.
class LegendaNiveis extends StatelessWidget {
  const LegendaNiveis({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final n in Nivel.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: n.cor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(n.rotulo, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: corSemNivel, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text('Sem dados', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      );
}
