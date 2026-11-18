import 'package:flutter/material.dart';

import '../domain/nivel.dart';
import '../models/estacao.dart';
import '../state/monitoramento_controller.dart';
import '../widgets/estacao_card.dart';
import '../widgets/grafico_historico.dart';
import '../widgets/status_atualizacao.dart';

/// Tela inicial (HM-01): resumo das estações por nível, avisos das
/// favoritas, favoritas e estações em atenção ou acima.
class InicioScreen extends StatelessWidget {
  const InicioScreen({
    super.key,
    required this.aoVerTodas,
    required this.aoVerAvisos,
  });

  final VoidCallback aoVerTodas;
  final VoidCallback aoVerAvisos;

  @override
  Widget build(BuildContext context) {
    final c = MonitoramentoScope.of(context);
    final tema = Theme.of(context);

    final favoritas =
        c.estacoes.where((e) => c.ehFavorita(e.codigo)).toList();
    final emAtencao = c.estacoes
        .where((e) =>
            !c.ehFavorita(e.codigo) &&
            (c.situacao(e.codigo)?.geral.nivel?.valor ?? -1) >=
                Nivel.atencao.valor)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hidro Vales'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: c.carregando ? null : () => c.atualizar(manual: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => c.atualizar(manual: true),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const StatusAtualizacao(),
            if (c.favoritasEmAtencao.isNotEmpty)
              _BannerAvisos(
                estacoes: c.favoritasEmAtencao,
                aoTocar: aoVerAvisos,
              ),
            if (c.semDadosAinda && c.carregando)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (c.estacoes.isNotEmpty) ...[
              _Resumo(contagem: c.contagemPorNivel, total: c.estacoes.length),
              _Secao(
                titulo: 'Favoritas',
                vazio: 'Toque na estrela de uma estação para acompanhá-la '
                    'aqui e receber avisos dentro do app.',
                estacoes: favoritas,
              ),
              _Secao(
                titulo: 'Outras estações em atenção ou acima',
                vazio: 'Nenhuma outra estação em atenção, alerta ou '
                    'situação crítica.',
                estacoes: emAtencao,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: aoVerTodas,
                  icon: const Icon(Icons.list),
                  label: Text('Ver as ${c.estacoes.length} estações'),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                'Indicação não oficial. Não substitui os comunicados da '
                'Defesa Civil.',
                style: tema.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerAvisos extends StatelessWidget {
  const _BannerAvisos({required this.estacoes, required this.aoTocar});

  final List<Estacao> estacoes;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = MonitoramentoScope.of(context);
    Nivel maior = Nivel.atencao;
    for (final e in estacoes) {
      final n = c.situacao(e.codigo)?.geral.nivel;
      if (n != null && n > maior) maior = n;
    }
    final nomes = estacoes.map((e) => e.nome).join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: maior.cor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: maior.corTexto, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estacoes.length == 1
                            ? 'Favorita em ${maior.rotulo.toLowerCase()}'
                            : '${estacoes.length} favoritas em atenção ou acima',
                        style: TextStyle(
                          color: maior.corTexto,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(nomes, style: TextStyle(color: maior.corTexto)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: maior.corTexto),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.contagem, required this.total});

  final Map<Nivel?, int> contagem;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget caixa(String rotulo, int qtd, Color cor, Color corTexto) =>
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: qtd > 0 ? cor : cor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text('$qtd',
                    style: tema.textTheme.headlineSmall?.copyWith(
                        color: qtd > 0 ? corTexto : tema.hintColor,
                        fontWeight: FontWeight.bold)),
                Text(rotulo,
                    style: tema.textTheme.labelSmall?.copyWith(
                        color: qtd > 0 ? corTexto : tema.hintColor)),
              ],
            ),
          ),
        );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Situação das $total estações',
                style: tema.textTheme.titleMedium),
            Text('Vale do Rio Pardo e Vale do Taquari · nível geral',
                style: tema.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final n in Nivel.values)
                  caixa(n.rotulo, contagem[n] ?? 0, n.cor, n.corTexto),
                caixa('Sem dados', contagem[null] ?? 0, corSemNivel,
                    Colors.white),
              ],
            ),
            const SizedBox(height: 6),
            const LegendaNiveis(),
          ],
        ),
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({
    required this.titulo,
    required this.vazio,
    required this.estacoes,
  });

  final String titulo;
  final String vazio;
  final List<Estacao> estacoes;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(titulo, style: tema.textTheme.titleMedium),
          ),
          if (estacoes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(vazio, style: tema.textTheme.bodyMedium),
            )
          else
            for (final e in estacoes) EstacaoCard(estacao: e),
        ],
      ),
    );
  }
}
