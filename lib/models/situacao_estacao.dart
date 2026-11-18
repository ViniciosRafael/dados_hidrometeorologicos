import '../domain/nivel.dart';
import '../domain/nivel_chuva.dart';
import '../domain/nivel_geral.dart';
import '../domain/nivel_rio.dart';
import 'estacao.dart';

/// Os três indicadores de uma estação: rio (API), chuva (regra do documento)
/// e geral (o maior dos dois).
class SituacaoEstacao {
  const SituacaoEstacao({
    required this.rio,
    required this.chuva,
    required this.geral,
    this.mm24,
    this.mm48,
    this.mm72,
  });

  final ResultadoNivel rio;
  final ResultadoNivel chuva;
  final ResultadoNivel geral;
  final double? mm24;
  final double? mm48;
  final double? mm72;

  /// Calcula a situação de [estacao]. [mm72] vem do histórico (a API não
  /// tem o acumulado de 72 h pronto).
  ///
  /// Estação sem leitura (timestamp nulo) não tem chuva confiável: a API
  /// devolve os acumulados como 0 mesmo com a estação fora do ar.
  factory SituacaoEstacao.calcular(Estacao estacao, {double? mm72}) {
    final rio = calcularNivelRio(
      temSensorDeRio: estacao.sensores.nivelRio,
      alarmeAtivo: estacao.rio.alarmeAtivo,
      status: estacao.rio.alarmeStatus,
      nivelMetros: estacao.rio.nivel,
    );

    final chuvaConfiavel = estacao.sensores.chuva && !estacao.semLeitura;
    final mm24 = chuvaConfiavel ? estacao.chuva.h24 : null;
    final mm48 = chuvaConfiavel ? estacao.chuva.h48 : null;
    final mm72Usado = chuvaConfiavel ? mm72 : null;

    final chuva = estacao.sensores.chuva
        ? calcularNivelChuva(mm24: mm24, mm48: mm48, mm72: mm72Usado)
        : const ResultadoNivel(
            nivel: null,
            rotulo: 'Sem sensor',
            motivo: 'Estação sem pluviômetro',
          );

    return SituacaoEstacao(
      rio: rio,
      chuva: chuva,
      geral: calcularNivelGeral(rio: rio, chuva: chuva),
      mm24: mm24,
      mm48: mm48,
      mm72: mm72Usado,
    );
  }

  /// Usado pelo modo demonstração: força o nível de chuva em ALERTA.
  SituacaoEstacao simularAlerta() {
    const chuvaSimulada = ResultadoNivel(
      nivel: Nivel.alerta,
      rotulo: 'ALERTA',
      motivo: '56,0 mm em 24 h (limite 50 mm) — SIMULAÇÃO',
    );
    return SituacaoEstacao(
      rio: rio,
      chuva: chuvaSimulada,
      geral: calcularNivelGeral(rio: rio, chuva: chuvaSimulada),
      mm24: 56,
      mm48: mm48,
      mm72: mm72,
    );
  }
}
