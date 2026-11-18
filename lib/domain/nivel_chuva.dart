import '../util/formatacao.dart';
import 'nivel.dart';

/// Limiares de chuva acumulada (mm) do documento de requisitos
/// ("Requisitos_Tres_Opcoes_Apps_Android.pdf", p. 4, seção API de integração).
///
/// | Nível      | Condição (qualquer uma verdadeira)          |
/// |------------|---------------------------------------------|
/// | NORMAL     | nenhuma condição atingida                   |
/// | ATENÇÃO    | mm24 >= 30 ou mm48 >= 50  ou mm72 >= 60     |
/// | ALERTA     | mm24 >= 50 ou mm48 >= 70  ou mm72 >= 90     |
/// | EMERGÊNCIA | mm24 >= 80 ou mm48 >= 100 ou mm72 >= 120    |
///
/// O sistema retorna o maior nível atingido.
class LimiaresChuva {
  const LimiaresChuva(this.mm24, this.mm48, this.mm72);
  final double mm24;
  final double mm48;
  final double mm72;

  /// Valor do limiar para a janela de [horas] (24, 48 ou 72).
  double paraJanela(int horas) => switch (horas) {
        24 => mm24,
        48 => mm48,
        72 => mm72,
        _ => throw ArgumentError('Janela inválida: $horas h'),
      };
}

const Map<Nivel, LimiaresChuva> limiaresChuva = {
  Nivel.atencao: LimiaresChuva(30, 50, 60),
  Nivel.alerta: LimiaresChuva(50, 70, 90),
  Nivel.critico: LimiaresChuva(80, 100, 120),
};

/// Rótulos usados pelo documento para os níveis de chuva.
const Map<Nivel, String> rotulosChuva = {
  Nivel.normal: 'NORMAL',
  Nivel.atencao: 'ATENÇÃO',
  Nivel.alerta: 'ALERTA',
  Nivel.critico: 'EMERGÊNCIA',
};

/// Calcula o nível de chuva a partir dos acumulados de 24, 48 e 72 horas.
///
/// Valores `null` (sem dado) são ignorados, nunca tratados como zero.
/// Se os três forem `null`, o resultado é "Sem dados".
ResultadoNivel calcularNivelChuva({
  required double? mm24,
  required double? mm48,
  required double? mm72,
}) {
  final janelas = <int, double?>{24: mm24, 48: mm48, 72: mm72};
  if (janelas.values.every((v) => v == null)) {
    return const ResultadoNivel(
      nivel: null,
      rotulo: 'Sem dados',
      motivo: 'Sem dados de chuva',
    );
  }

  // Do maior para o menor: o primeiro nível atingido é o maior.
  for (final nivel in [Nivel.critico, Nivel.alerta, Nivel.atencao]) {
    final limiar = limiaresChuva[nivel]!;
    for (final entrada in janelas.entries) {
      final valor = entrada.value;
      if (valor == null) continue;
      final limite = limiar.paraJanela(entrada.key);
      if (valor >= limite) {
        return ResultadoNivel(
          nivel: nivel,
          rotulo: rotulosChuva[nivel]!,
          motivo: '${formatarNumero(valor, 1)} mm em ${entrada.key} h '
              '(limite ${formatarNumero(limite, 0)} mm)',
        );
      }
    }
  }

  final partes = janelas.entries
      .where((e) => e.value != null)
      .map((e) => '${e.key} h: ${formatarNumero(e.value!, 1)} mm')
      .join(' · ');
  final falta72 = mm72 == null ? ' (72 h indisponível)' : '';
  return ResultadoNivel(
    nivel: Nivel.normal,
    rotulo: rotulosChuva[Nivel.normal]!,
    motivo: '$partes$falta72',
  );
}
