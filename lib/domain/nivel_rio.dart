import '../util/formatacao.dart';
import 'nivel.dart';

/// Converte o alarme de inundação da API (`data.rio.rio_alarmes.inundacao`)
/// para a escala comum.
///
/// Tabela do guia da API:
/// | ativo | status | Situação                     |
/// |-------|--------|------------------------------|
/// | true  | 0      | Normalidade                  |
/// | true  | 1      | Atenção Inundação            |
/// | true  | 2      | Alerta Inundação             |
/// | true  | 3      | Inundação                    |
/// | true  | null   | Sem leitura de nível recente |
/// | false | 0      | Estação sem limiar cadastrado|
ResultadoNivel calcularNivelRio({
  required bool temSensorDeRio,
  required bool? alarmeAtivo,
  required int? status,
  required double? nivelMetros,
}) {
  if (!temSensorDeRio) {
    return const ResultadoNivel(
      nivel: null,
      rotulo: 'Sem sensor',
      motivo: 'Estação sem sensor de nível do rio',
    );
  }
  if (alarmeAtivo == false) {
    return ResultadoNivel(
      nivel: null,
      rotulo: 'Sem limiar',
      motivo: 'Estação sem limiar de inundação cadastrado'
          '${nivelMetros != null ? ' · nível ${formatarNumero(nivelMetros, 2)} m' : ''}',
    );
  }
  final nivel = Nivel.doValor(status);
  if (alarmeAtivo == null || nivel == null) {
    return const ResultadoNivel(
      nivel: null,
      rotulo: 'Sem leitura',
      motivo: 'Sem leitura de nível recente',
    );
  }
  const rotulos = {
    Nivel.normal: 'Normalidade',
    Nivel.atencao: 'Atenção Inundação',
    Nivel.alerta: 'Alerta Inundação',
    Nivel.critico: 'Inundação',
  };
  final textoNivel =
      nivelMetros != null ? 'Nível ${formatarNumero(nivelMetros, 2)} m · ' : '';
  return ResultadoNivel(
    nivel: nivel,
    rotulo: rotulos[nivel]!,
    motivo: '${textoNivel}situação informada pela Defesa Civil',
  );
}
