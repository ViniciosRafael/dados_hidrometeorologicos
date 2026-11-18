import 'package:flutter/material.dart';

import '../config/estacoes_monitoradas.dart';
import '../domain/nivel.dart';
import '../domain/nivel_chuva.dart';
import '../state/monitoramento_controller.dart';

/// Fontes de dados, limites dos indicadores e caráter não oficial dos
/// alertas (HM-10).
class SobreScreen extends StatelessWidget {
  const SobreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = MonitoramentoScope.of(context);

    Widget titulo(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
          child: Text(t, style: tema.textTheme.titleMedium),
        );
    Widget paragrafo(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t, style: tema.textTheme.bodyMedium),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Sobre os dados')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            color: tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: tema.colorScheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Este aplicativo é acadêmico e NÃO é oficial. Os níveis '
                      'mostrados são indicações de potencial risco, não '
                      'previsões garantidas de enchente, e não substituem os '
                      'alertas e comunicados da Defesa Civil. Em emergência, '
                      'ligue 199 (Defesa Civil) ou 193 (Bombeiros).',
                      style:
                          TextStyle(color: tema.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          titulo('Fonte dos dados'),
          paragrafo(
            'Rede Hidrometeorológica da Defesa Civil do Rio Grande do Sul, '
            'pela API pública de dados hidrometeorológicos. Os dados são '
            'atualizados em blocos de 5 minutos, em horário de Brasília. Uma '
            'medida aparece como "sem dado" quando a estação não a enviou nos '
            'últimos 20 minutos. O histórico disponível é de até 3 meses.',
          ),
          paragrafo(
            'O app acompanha ${estacoesMonitoradas.length} estações das '
            'regiões Vale do Rio Pardo e Vale do Taquari.',
          ),
          titulo('Nível do rio'),
          paragrafo(
            'Vem pronto da Defesa Civil, que compara a cota medida com as '
            'cotas de atenção, alerta e inundação de cada estação. Os valores '
            'dessas cotas não são publicados pela API; por isso o app mostra '
            'apenas a situação (Normalidade, Atenção, Alerta, Inundação). '
            'Estações sem limiar cadastrado aparecem como "Sem limiar".',
          ),
          titulo('Nível de chuva'),
          paragrafo(
            'Calculado pelo app com a regra do documento de requisitos do '
            'projeto. Vale o maior nível atingido em qualquer janela:',
          ),
          _TabelaChuva(),
          paragrafo(
            'Os acumulados de 24 h e 48 h vêm da API. O de 72 h é a soma da '
            'chuva hora a hora do histórico da estação. Se uma estação ficou '
            'fora do ar parte do período, o acumulado pode estar abaixo do '
            'real.',
          ),
          titulo('Nível geral'),
          paragrafo(
            'É o maior entre o nível do rio e o nível de chuva, considerando '
            'apenas os que têm dado. Sem dado de rio e de chuva, a estação '
            'aparece como "Sem dados", nunca como normal. As cores seguem as '
            'usadas pela Defesa Civil:',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final n in Nivel.values)
                Chip(
                  label: Text(n.rotulo, style: TextStyle(color: n.corTexto)),
                  backgroundColor: n.cor,
                ),
              const Chip(
                label: Text('Sem dados', style: TextStyle(color: Colors.white)),
                backgroundColor: corSemNivel,
              ),
            ],
          ),
          titulo('Limites dos indicadores'),
          paragrafo('• Estações em manutenção ou com sensor não homologado '
              'podem ter dados incorretos (o app sinaliza na tela da estação).'),
          paragrafo('• A chuva medida num ponto não representa toda a bacia, '
              'e a cheia de um rio depende também da chuva rio acima.'),
          paragrafo('• Os avisos só são verificados com o app aberto.'),
          titulo('Estações acompanhadas'),
          for (final regiao in Regiao.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(regiao.rotulo, style: tema.textTheme.labelLarge),
            ),
            for (final entrada in estacoesMonitoradas.entries
                .where((e) => e.value == regiao))
              Text(
                '${entrada.key} · '
                '${c.estacao(entrada.key)?.nome ?? municipiosDasEstacoes[entrada.key]?.join(' / ') ?? ''}',
                style: tema.textTheme.bodySmall,
              ),
          ],
          titulo('Projeto'),
          paragrafo(
            'Trabalho da disciplina de Dispositivos Móveis — Opção 3: '
            'aplicativo de monitoramento hidrometeorológico e risco de '
            'enchentes. Mapa: © colaboradores do OpenStreetMap.',
          ),
        ],
      ),
    );
  }
}

class _TabelaChuva extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget celula(String t, {bool negrito = false, Color? fundo, Color? cor}) =>
        Container(
          color: fundo,
          padding: const EdgeInsets.all(6),
          child: Text(
            t,
            style: TextStyle(
              fontWeight: negrito ? FontWeight.bold : null,
              color: cor,
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Table(
        border: TableBorder.all(color: tema.dividerColor),
        columnWidths: const {0: IntrinsicColumnWidth()},
        children: [
          TableRow(children: [
            celula('Nível', negrito: true),
            celula('Condição (qualquer uma)', negrito: true),
          ]),
          TableRow(children: [
            celula('NORMAL', fundo: Nivel.normal.cor, cor: Nivel.normal.corTexto),
            celula('Nenhuma condição atingida'),
          ]),
          for (final e in limiaresChuva.entries)
            TableRow(children: [
              celula(rotulosChuva[e.key]!,
                  fundo: e.key.cor, cor: e.key.corTexto, negrito: true),
              celula('24 h ≥ ${e.value.mm24.toInt()} mm  ou  '
                  '48 h ≥ ${e.value.mm48.toInt()} mm  ou  '
                  '72 h ≥ ${e.value.mm72.toInt()} mm'),
            ]),
        ],
      ),
    );
  }
}
