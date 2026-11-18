import 'nivel.dart';

/// Nível geral da estação = o maior entre o nível do rio e o nível de chuva,
/// considerando só os que têm dado. Se nenhum tiver dado → "Sem dados"
/// (nunca "Normal").
///
/// É uma indicação de potencial risco, não uma previsão de enchente.
ResultadoNivel calcularNivelGeral({
  required ResultadoNivel rio,
  required ResultadoNivel chuva,
}) {
  final nRio = rio.nivel;
  final nChuva = chuva.nivel;

  if (nRio == null && nChuva == null) {
    return const ResultadoNivel(
      nivel: null,
      rotulo: 'Sem dados',
      motivo: 'Sem dados de rio e de chuva',
    );
  }

  final String origem;
  final Nivel nivel;
  if (nChuva == null || (nRio != null && nRio > nChuva)) {
    nivel = nRio!;
    origem = 'por nível do rio';
  } else if (nRio == null || nChuva > nRio) {
    nivel = nChuva;
    origem = 'por chuva: ${chuva.motivo}';
  } else {
    nivel = nRio;
    origem = nivel == Nivel.normal
        ? 'rio e chuva dentro da normalidade'
        : 'por nível do rio e por chuva';
  }

  return ResultadoNivel(nivel: nivel, rotulo: nivel.rotulo, motivo: origem);
}
