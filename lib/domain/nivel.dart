import 'package:flutter/material.dart';

/// Escala comum de 0 a 3 usada para comparar o nível do rio (vindo da API)
/// com o nível de chuva (regra do documento de requisitos) e para calcular o
/// nível geral. As cores são as usadas pela Defesa Civil RS no mapa.
enum Nivel {
  normal(0, 'Normal', Color(0xFF69A82F)),
  atencao(1, 'Atenção', Color(0xFFFABA00)),
  alerta(2, 'Alerta', Color(0xFFE67819)),
  critico(3, 'Crítico', Color(0xFFE20228));

  const Nivel(this.valor, this.rotulo, this.cor);

  final int valor;
  final String rotulo;
  final Color cor;

  static Nivel? doValor(int? valor) {
    if (valor == null) return null;
    for (final n in Nivel.values) {
      if (n.valor == valor) return n;
    }
    return null;
  }

  bool operator >=(Nivel outro) => valor >= outro.valor;
  bool operator >(Nivel outro) => valor > outro.valor;

  /// Cor do texto que fica legível sobre [cor].
  Color get corTexto => this == Nivel.atencao ? Colors.black87 : Colors.white;
}

/// Cor usada quando não há nível (sem dados, sem limiar, sem leitura).
const Color corSemNivel = Color(0xFF9E9E9E);

/// Resultado de uma regra de nível: o nível (ou `null` quando não há dado
/// suficiente), o rótulo a exibir e o motivo em texto.
class ResultadoNivel {
  const ResultadoNivel({
    required this.nivel,
    required this.rotulo,
    required this.motivo,
  });

  /// `null` = sem dados / sem limiar / sem leitura.
  final Nivel? nivel;

  /// Rótulo exibido (ex.: "Alerta Inundação", "EMERGÊNCIA", "Sem dados").
  final String rotulo;

  /// Explicação curta (ex.: "56,0 mm em 24 h (limite 50 mm)").
  final String motivo;

  bool get temDado => nivel != null;

  Color get cor => nivel?.cor ?? corSemNivel;

  Color get corTexto => nivel?.corTexto ?? Colors.white;

  @override
  String toString() => 'ResultadoNivel($rotulo, $motivo)';
}
