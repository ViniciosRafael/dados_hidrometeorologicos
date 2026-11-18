import 'package:flutter/material.dart';

import '../domain/nivel.dart';

/// Etiqueta colorida com o rótulo de um nível.
class NivelBadge extends StatelessWidget {
  const NivelBadge({
    super.key,
    required this.resultado,
    this.icone,
    this.compacto = false,
  });

  final ResultadoNivel resultado;
  final IconData? icone;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final estilo = (compacto
            ? Theme.of(context).textTheme.labelSmall
            : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(color: resultado.corTexto, fontWeight: FontWeight.w600);
    return Semantics(
      label: '${resultado.rotulo}. ${resultado.motivo}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 6 : 10,
          vertical: compacto ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: resultado.cor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: compacto ? 12 : 14, color: resultado.corTexto),
              const SizedBox(width: 4),
            ],
            Text(resultado.rotulo, style: estilo),
          ],
        ),
      ),
    );
  }
}

/// Bolinha colorida (para mapas e legendas).
class NivelPonto extends StatelessWidget {
  const NivelPonto({super.key, required this.cor, this.tamanho = 12});

  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: cor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
}

/// Ícones usados para os três indicadores.
class IconesNivel {
  IconesNivel._();
  static const rio = Icons.water;
  static const chuva = Icons.umbrella;
  static const geral = Icons.warning_amber_rounded;
}
