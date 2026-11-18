import '../util/formatacao.dart';

/// Um bloco da série histórica (consulta `Historic`).
///
/// Exemplo da API:
/// {"ts": "2026-10-14T09:00:00.000", "codigo": "DCRS-00001",
///  "rio_nivel": 27.24, "rio_variacao": 0, "chuva_mm": 0, "chuva_total": 0,
///  "chuva_taxa_med": 0, "chuva_taxa_max": 0, "temp_media": 22.4, ...}
class LeituraHistorica {
  const LeituraHistorica({
    required this.horario,
    this.nivelRio,
    this.variacaoRio,
    this.chuvaMm,
    this.chuvaTaxaMedia,
    this.chuvaTaxaMaxima,
    this.temperatura,
    this.sensacaoTermica,
    this.umidade,
    this.pressao,
    this.ventoMedio,
    this.ventoMaximo,
    this.ventoDirecao,
    this.radiacao,
  });

  /// Início do bloco (UTC).
  final DateTime horario;

  /// m
  final double? nivelRio;
  final double? variacaoRio;

  /// Chuva dentro do bloco (mm). Somar os blocos dá o acumulado do período.
  /// (Não usar `chuva_total`: ele não é somável.)
  final double? chuvaMm;

  /// mm/h
  final double? chuvaTaxaMedia;
  final double? chuvaTaxaMaxima;

  /// °C
  final double? temperatura;
  final double? sensacaoTermica;

  /// %
  final double? umidade;

  /// hPa
  final double? pressao;

  /// km/h
  final double? ventoMedio;
  final double? ventoMaximo;

  /// graus
  final double? ventoDirecao;

  /// W/m²
  final double? radiacao;

  static double? _n(dynamic v) => v is num ? v.toDouble() : null;

  /// Devolve `null` se o bloco não tiver horário válido.
  static LeituraHistorica? fromJson(Map<String, dynamic> j) {
    final horario = lerDataBrasilia(j['ts']?.toString());
    if (horario == null) return null;
    return LeituraHistorica(
      horario: horario,
      nivelRio: _n(j['rio_nivel']),
      variacaoRio: _n(j['rio_variacao']),
      chuvaMm: _n(j['chuva_mm']),
      chuvaTaxaMedia: _n(j['chuva_taxa_med']),
      chuvaTaxaMaxima: _n(j['chuva_taxa_max']),
      temperatura: _n(j['temp_media']),
      sensacaoTermica: _n(j['sens_termica']),
      umidade: _n(j['umid_rel']),
      pressao: _n(j['pres_atmos']),
      ventoMedio: _n(j['vento_vel_med']),
      ventoMaximo: _n(j['vento_vel_max']),
      ventoDirecao: _n(j['vento_dir']),
      radiacao: _n(j['radiacao']),
    );
  }
}

/// Soma a chuva dos blocos. `null` se nenhum bloco tiver dado de chuva.
double? somarChuva(Iterable<LeituraHistorica> leituras) {
  double soma = 0;
  var algum = false;
  for (final l in leituras) {
    final c = l.chuvaMm;
    if (c != null) {
      soma += c;
      algum = true;
    }
  }
  return algum ? soma : null;
}
