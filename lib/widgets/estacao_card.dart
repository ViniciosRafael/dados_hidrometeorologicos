import 'package:flutter/material.dart';

import '../models/estacao.dart';
import '../models/situacao_estacao.dart';
import '../screens/detalhe_screen.dart';
import '../state/monitoramento_controller.dart';
import '../util/formatacao.dart';
import 'nivel_badge.dart';

/// Cartão de uma estação: nível geral em destaque, rio e chuva ao lado,
/// medidas principais e horário da última leitura.
class EstacaoCard extends StatelessWidget {
  const EstacaoCard({super.key, required this.estacao});

  final Estacao estacao;

  @override
  Widget build(BuildContext context) {
    final controller = MonitoramentoScope.of(context);
    final situacao = controller.situacao(estacao.codigo);
    final favorita = controller.ehFavorita(estacao.codigo);
    final tema = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetalheScreen(codigo: estacao.codigo),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: situacao?.geral.cor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estacao.nome,
                        style: tema.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${estacao.regiao?.rotulo ?? ''} · ${estacao.codigo}',
                        style: tema.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (situacao != null) _Indicadores(situacao: situacao),
                      const SizedBox(height: 6),
                      _ResumoMedidas(estacao: estacao, situacao: situacao),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: favorita
                    ? 'Remover das favoritas'
                    : 'Adicionar às favoritas',
                icon: Icon(favorita ? Icons.star : Icons.star_border),
                color: favorita ? Colors.amber.shade700 : null,
                onPressed: () => controller.alternarFavorita(estacao.codigo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.situacao});

  final SituacaoEstacao situacao;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          NivelBadge(resultado: situacao.geral, icone: IconesNivel.geral),
          NivelBadge(
            resultado: situacao.rio,
            icone: IconesNivel.rio,
            compacto: true,
          ),
          NivelBadge(
            resultado: situacao.chuva,
            icone: IconesNivel.chuva,
            compacto: true,
          ),
        ],
      );
}

class _ResumoMedidas extends StatelessWidget {
  const _ResumoMedidas({required this.estacao, required this.situacao});

  final Estacao estacao;
  final SituacaoEstacao? situacao;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final partes = <String>[
      if (estacao.rio.nivel != null)
        'Rio ${formatarNumero(estacao.rio.nivel!, 2)} m',
      if (situacao?.mm24 != null)
        'Chuva 24 h ${formatarNumero(situacao!.mm24!, 1)} mm',
    ];
    final leitura = estacao.ultimaLeitura;
    final atrasada = estacao.estaAtrasada();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (partes.isNotEmpty)
          Text(partes.join(' · '), style: tema.textTheme.bodyMedium),
        Row(
          children: [
            Icon(
              atrasada ? Icons.schedule_outlined : Icons.update,
              size: 14,
              color: atrasada ? tema.colorScheme.error : tema.hintColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                leitura == null
                    ? 'Sem leitura recente'
                    : 'Medição ${formatarDataHoraCurta(leitura)}'
                        '${atrasada ? ' · atrasada' : ''}',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: atrasada ? tema.colorScheme.error : null,
                ),
              ),
            ),
            if (estacao.emManutencao) ...[
              const SizedBox(width: 6),
              Icon(Icons.build_circle_outlined,
                  size: 14, color: tema.colorScheme.error),
              Text(' manutenção',
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.error)),
            ],
          ],
        ),
      ],
    );
  }
}
