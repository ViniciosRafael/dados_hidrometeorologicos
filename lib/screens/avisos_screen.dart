import 'package:flutter/material.dart';

import '../models/aviso.dart';
import '../state/monitoramento_controller.dart';
import '../util/formatacao.dart';
import 'detalhe_screen.dart';

/// Avisos dentro do app para estações favoritas (HM-07).
///
/// A notificação push deixou de ser obrigatória: os avisos aparecem aqui,
/// no banner da tela inicial e no contador do sino.
class AvisosScreen extends StatelessWidget {
  const AvisosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MonitoramentoScope.of(context);
    final tema = Theme.of(context);
    final avisos = c.avisos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          if (avisos.isNotEmpty)
            IconButton(
              tooltip: 'Limpar avisos',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmarLimpeza(context, c),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Você recebe um aviso quando o nível geral de uma estação '
              'favorita sobe para atenção ou acima. A verificação acontece a '
              'cada atualização (cerca de 5 minutos) com o app aberto, e '
              'também ao abrir o app.',
              style: tema.textTheme.bodyMedium,
            ),
          ),
          if (c.favoritas.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Você ainda não tem favoritas. Toque na estrela de uma '
                'estação para acompanhá-la.',
              ),
            ),
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SwitchListTile(
              title: const Text('Modo demonstração'),
              subtitle: Text(
                'Simula chuva em ALERTA na estação '
                '${c.estacao(c.codigoDemonstracao)?.nome ?? c.codigoDemonstracao} '
                'para testar os avisos mesmo sem chuva real.',
              ),
              value: c.modoDemonstracao,
              onChanged: c.definirModoDemonstracao,
            ),
          ),
          const Divider(),
          if (avisos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Nenhum aviso por enquanto.')),
            )
          else
            for (final a in avisos) _ItemAviso(aviso: a),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Os avisos são indicativos e não oficiais. Não são previsão '
              'garantida de enchente e não substituem os comunicados da '
              'Defesa Civil (telefone 199).',
              style: tema.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarLimpeza(
      BuildContext context, MonitoramentoController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar avisos?'),
        content: const Text('A lista de avisos será apagada deste aparelho.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (ok == true) await c.limparAvisos();
  }
}

class _ItemAviso extends StatelessWidget {
  const _ItemAviso({required this.aviso});

  final Aviso aviso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final a = aviso;
    final de = a.nivelAnterior == null ? '' : '${a.nivelAnterior!.rotulo} → ';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: a.nivel.cor,
        child: Icon(Icons.warning_amber_rounded, color: a.nivel.corTexto),
      ),
      title: Text(
        '${a.nomeEstacao}: $de${a.nivel.rotulo}',
        style: TextStyle(
          fontWeight: a.lido ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        '${a.motivo}\n${formatarDataHora(a.horario)}'
        '${a.simulado ? ' · simulação' : ''}',
      ),
      isThreeLine: true,
      trailing: a.lido
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: tema.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetalheScreen(codigo: a.codigo)),
      ),
    );
  }
}
