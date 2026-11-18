import '../domain/nivel.dart';

/// Aviso exibido dentro do app quando o nível geral de uma estação
/// favorita sobe para atenção ou acima (HM-07).
class Aviso {
  const Aviso({
    required this.codigo,
    required this.nomeEstacao,
    required this.nivel,
    required this.nivelAnterior,
    required this.motivo,
    required this.horario,
    this.lido = false,
    this.simulado = false,
  });

  final String codigo;
  final String nomeEstacao;
  final Nivel nivel;
  final Nivel? nivelAnterior;
  final String motivo;
  final DateTime horario;
  final bool lido;
  final bool simulado;

  Aviso marcarLido() => Aviso(
        codigo: codigo,
        nomeEstacao: nomeEstacao,
        nivel: nivel,
        nivelAnterior: nivelAnterior,
        motivo: motivo,
        horario: horario,
        lido: true,
        simulado: simulado,
      );

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'nome': nomeEstacao,
        'nivel': nivel.valor,
        'anterior': nivelAnterior?.valor,
        'motivo': motivo,
        'horario': horario.toUtc().toIso8601String(),
        'lido': lido,
        'simulado': simulado,
      };

  static Aviso? fromJson(Map<String, dynamic> j) {
    final nivel = Nivel.doValor(j['nivel'] as int?);
    final horario = DateTime.tryParse(j['horario']?.toString() ?? '');
    if (nivel == null || horario == null) return null;
    return Aviso(
      codigo: j['codigo']?.toString() ?? '',
      nomeEstacao: j['nome']?.toString() ?? '',
      nivel: nivel,
      nivelAnterior: Nivel.doValor(j['anterior'] as int?),
      motivo: j['motivo']?.toString() ?? '',
      horario: horario,
      lido: j['lido'] == true,
      simulado: j['simulado'] == true,
    );
  }
}
