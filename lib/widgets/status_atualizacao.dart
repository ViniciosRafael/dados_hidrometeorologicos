import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../state/monitoramento_controller.dart';
import '../util/formatacao.dart';

/// Faixa com a hora da última atualização, a próxima, e mensagens de erro
/// ou de dados atrasados (HM-09).
class StatusAtualizacao extends StatelessWidget {
  const StatusAtualizacao({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MonitoramentoScope.of(context);
    final tema = Theme.of(context);
    final erro = c.erro;
    final leitura = c.leituraMaisRecente;
    final proxima = c.proximaAtualizacao;

    final widgets = <Widget>[];

    if (erro != null) {
      widgets.add(_Faixa(
        icone: erro.tipo == TipoErroApi.semConexao
            ? Icons.wifi_off
            : Icons.cloud_off,
        cor: tema.colorScheme.errorContainer,
        corTexto: tema.colorScheme.onErrorContainer,
        texto: c.semDadosAinda
            ? '${erro.mensagem} Toque para tentar de novo.'
            : '${erro.mensagem} Mostrando os últimos dados recebidos '
                '(${formatarDataHoraCurta(c.ultimaConsulta!)}).',
        aoTocar: () => c.atualizar(manual: true),
      ));
    }

    if (leitura != null &&
        DateTime.now().difference(leitura) > const Duration(minutes: 20)) {
      widgets.add(_Faixa(
        icone: Icons.schedule,
        cor: tema.colorScheme.tertiaryContainer,
        corTexto: tema.colorScheme.onTertiaryContainer,
        texto: 'Dados atrasados: a medição mais recente é de '
            '${formatarDataHoraCurta(leitura)} '
            '(${formatarTempoDecorrido(leitura)}).',
      ));
    }

    widgets.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (c.carregando)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.update, size: 16, color: tema.hintColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              c.carregando
                  ? 'Atualizando…'
                  : leitura == null
                      ? 'Aguardando dados'
                      : 'Medição de ${formatarDataHoraCurta(leitura)}'
                          '${proxima != null ? ' · próxima por volta de ${formatarHora(proxima)}' : ''}',
              style: tema.textTheme.bodySmall,
            ),
          ),
          if (c.modoDemonstracao)
            Chip(
              label: const Text('Demonstração'),
              visualDensity: VisualDensity.compact,
              backgroundColor: tema.colorScheme.secondaryContainer,
            ),
        ],
      ),
    ));

    return Column(mainAxisSize: MainAxisSize.min, children: widgets);
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({
    required this.icone,
    required this.cor,
    required this.corTexto,
    required this.texto,
    this.aoTocar,
  });

  final IconData icone;
  final Color cor;
  final Color corTexto;
  final String texto;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) => Material(
        color: cor,
        child: InkWell(
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icone, color: corTexto, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(texto, style: TextStyle(color: corTexto)),
                ),
              ],
            ),
          ),
        ),
      );
}
