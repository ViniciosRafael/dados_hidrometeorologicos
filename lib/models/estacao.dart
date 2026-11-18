import '../config/estacoes_monitoradas.dart';
import '../util/formatacao.dart';

/// Lê `{"value": x}` dentro de [json] seguindo [caminho].
/// Devolve `null` se qualquer parte do caminho faltar ou vier `null`
/// (a API manda `null` tanto no objeto quanto no `value`).
dynamic _valor(Map<String, dynamic>? json, List<String> caminho) {
  dynamic atual = json;
  for (final chave in caminho) {
    if (atual is! Map) return null;
    atual = atual[chave];
  }
  if (atual is Map) return atual['value'];
  return atual;
}

double? _numero(Map<String, dynamic>? json, List<String> caminho) {
  final v = _valor(json, caminho);
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool? _booleano(Map<String, dynamic>? json, List<String> caminho) {
  final v = _valor(json, caminho);
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  return null;
}

/// Medida atual + médias de hoje e de ontem + tendência.
class Medida {
  const Medida({
    this.atual,
    this.mediaHoje,
    this.mediaOntem,
    this.maximaHoje,
    this.minimaHoje,
    this.tendencia,
    this.homologado = true,
  });

  final double? atual;
  final double? mediaHoje;
  final double? mediaOntem;
  final double? maximaHoje;
  final double? minimaHoje;

  /// Valor atual menos a média da última hora (positivo = subindo).
  final double? tendencia;

  /// `false` = sensor com dado não homologado.
  final bool homologado;

  factory Medida.fromJson(Map<String, dynamic>? j) => Medida(
        atual: _numero(j, ['atual']),
        mediaHoje: _numero(j, ['historico', 'diaatual', 'media']),
        mediaOntem: _numero(j, ['historico', 'diaanterior', 'media']),
        maximaHoje: _numero(j, ['historico', 'diaatual', 'maxima']),
        minimaHoje: _numero(j, ['historico', 'diaatual', 'minima']),
        tendencia: _numero(j, ['tendencia']),
        homologado:
            _booleano(j, ['homologacao', 'relacao', 'valido']) ?? true,
      );
}

class DadosRio {
  const DadosRio({
    this.nivel,
    this.tendencia,
    this.alarmeAtivo,
    this.alarmeStatus,
    this.homologado = true,
  });

  /// Cota do rio, em metros.
  final double? nivel;

  /// Variação do nível (m) em relação à média da última hora.
  final double? tendencia;

  final bool? alarmeAtivo;
  final int? alarmeStatus;
  final bool homologado;

  factory DadosRio.fromJson(Map<String, dynamic>? j) => DadosRio(
        nivel: _numero(j, ['rio_nivel']),
        tendencia: _numero(j, ['rio_nivel_tendencia']),
        alarmeAtivo: _booleano(j, ['rio_alarmes', 'inundacao', 'ativo']),
        alarmeStatus:
            _numero(j, ['rio_alarmes', 'inundacao', 'status'])?.toInt(),
        homologado:
            _booleano(j, ['homologacao', 'relacao', 'valido']) ?? true,
      );
}

class DadosChuva {
  const DadosChuva({
    this.min5,
    this.h1,
    this.h3,
    this.h6,
    this.h12,
    this.h24,
    this.h48,
    this.h168,
    this.homologado = true,
  });

  /// Acumulados em mm.
  final double? min5, h1, h3, h6, h12, h24, h48, h168;
  final bool homologado;

  factory DadosChuva.fromJson(Map<String, dynamic>? j) => DadosChuva(
        min5: _numero(j, ['acumulado', 'min005']),
        h1: _numero(j, ['acumulado', 'h001']),
        h3: _numero(j, ['acumulado', 'h003']),
        h6: _numero(j, ['acumulado', 'h006']),
        h12: _numero(j, ['acumulado', 'h012']),
        h24: _numero(j, ['acumulado', 'h024']),
        h48: _numero(j, ['acumulado', 'h048']),
        h168: _numero(j, ['acumulado', 'h168']),
        homologado:
            _booleano(j, ['homologacao', 'relacao', 'valido']) ?? true,
      );
}

class DadosVento {
  const DadosVento({
    this.direcao,
    this.velocidadeMedia,
    this.velocidadeMaxima,
    this.homologado = true,
  });

  /// Graus (0 = norte).
  final double? direcao;

  /// km/h.
  final double? velocidadeMedia;
  final double? velocidadeMaxima;
  final bool homologado;

  factory DadosVento.fromJson(Map<String, dynamic>? j) => DadosVento(
        direcao: _numero(j, ['direcao']),
        velocidadeMedia: _numero(j, ['velocidade_media']),
        velocidadeMaxima: _numero(j, ['velocidade_maxima']),
        homologado:
            _booleano(j, ['homologacao', 'relacao', 'valido']) ?? true,
      );
}

/// Quais sensores a estação possui (`filter.relacao`).
class Sensores {
  const Sensores({
    this.chuva = false,
    this.nivelRio = false,
    this.pressao = false,
    this.sensacaoTermica = false,
    this.umidade = false,
    this.vazao = false,
    this.vento = false,
  });

  final bool chuva, nivelRio, pressao, sensacaoTermica, umidade, vazao, vento;

  factory Sensores.fromJson(Map<String, dynamic>? j) {
    final r = j?['relacao'];
    bool b(String k) => r is Map && (r[k] == true || r[k] == 'true');
    return Sensores(
      chuva: b('tem_chuva_acumulada'),
      nivelRio: b('tem_nivel_do_rio'),
      pressao: b('tem_pressao_atmosferica'),
      sensacaoTermica: b('tem_sensacao_termica'),
      umidade: b('tem_umidade'),
      vazao: b('tem_vazao_do_rio'),
      vento: b('tem_vento'),
    );
  }
}

/// Uma estação da rede, como devolvida pela consulta `Tags_data`.
class Estacao {
  const Estacao({
    required this.codigo,
    required this.nome,
    required this.regiao,
    this.bacia,
    this.latitude,
    this.longitude,
    this.coordenadoria,
    this.ultimaLeitura,
    this.emManutencao = false,
    this.sensores = const Sensores(),
    this.rio = const DadosRio(),
    this.chuva = const DadosChuva(),
    this.temperatura = const Medida(),
    this.sensacaoTermica = const Medida(),
    this.umidade = const Medida(),
    this.pressao = const Medida(),
    this.radiacao = const Medida(),
    this.vento = const DadosVento(),
  });

  final String codigo;

  /// Nome/município (ex.: "Santa Cruz do Sul / Venâncio Aires").
  final String nome;

  /// Região do recorte do projeto (lista fixa em estacoes_monitoradas.dart).
  final Regiao? regiao;

  /// Bacia hidrográfica (sem o prefixo "RS - ").
  final String? bacia;
  final double? latitude;
  final double? longitude;

  /// Coordenadoria regional de Defesa Civil (CREPDEC).
  final String? coordenadoria;

  /// Início do bloco de 5 min da última leitura (UTC). `null` = sem leitura.
  final DateTime? ultimaLeitura;

  final bool emManutencao;
  final Sensores sensores;
  final DadosRio rio;
  final DadosChuva chuva;
  final Medida temperatura;
  final Medida sensacaoTermica;
  final Medida umidade;
  final Medida pressao;
  final Medida radiacao;
  final DadosVento vento;

  /// A API zera as medidas que não chegam em 20 minutos.
  static const Duration limiteAtraso = Duration(minutes: 20);

  bool get temCoordenadas => latitude != null && longitude != null;

  /// Sem leitura nenhuma (estação fora do ar).
  bool get semLeitura => ultimaLeitura == null;

  /// Última leitura mais antiga que 20 minutos.
  bool estaAtrasada([DateTime? agora]) {
    final t = ultimaLeitura;
    if (t == null) return true;
    return (agora ?? DateTime.now()).toUtc().difference(t) > limiteAtraso;
  }

  /// Algum sensor com dado não homologado.
  bool get temDadoNaoHomologado =>
      !rio.homologado ||
      !chuva.homologado ||
      !temperatura.homologado ||
      !umidade.homologado ||
      !pressao.homologado ||
      !vento.homologado;

  factory Estacao.fromJson(Map<String, dynamic> j) {
    final codigo = (j['codigo'] ?? '').toString();
    final nome = j['name'] is Map ? j['name'] as Map : const {};
    final posicao =
        j['position'] is Map ? Map<String, dynamic>.from(j['position']) : null;
    final dados =
        j['data'] is Map ? Map<String, dynamic>.from(j['data']) : null;
    Map<String, dynamic>? sub(String k) =>
        dados?[k] is Map ? Map<String, dynamic>.from(dados![k]) : null;

    final nomeGeral = (nome['general'] ?? '').toString().trim();
    final nomeLocal = (nome['local'] ?? '').toString().trim();
    final bacia = posicao?['bacia']?.toString().replaceFirst('RS - ', '');

    return Estacao(
      codigo: codigo,
      nome: [nomeGeral, nomeLocal]
          .where((s) => s.isNotEmpty && s != 'null')
          .join(' – ')
          .ifEmpty(codigo),
      regiao: estacoesMonitoradas[codigo],
      bacia: bacia,
      latitude: (posicao?['latitude'] as num?)?.toDouble(),
      longitude: (posicao?['longitude'] as num?)?.toDouble(),
      coordenadoria:
          _valor(posicao, ['filtros', 'outros', 'crepdec', 'nome'])?.toString(),
      ultimaLeitura: lerDataBrasilia(j['timestamp']?.toString()),
      emManutencao: _booleano(
              j['resource'] is Map
                  ? Map<String, dynamic>.from(j['resource'])
                  : null,
              ['estacao', 'estado', 'manutencao']) ??
          false,
      sensores: Sensores.fromJson(
          j['filter'] is Map ? Map<String, dynamic>.from(j['filter']) : null),
      rio: DadosRio.fromJson(sub('rio')),
      chuva: DadosChuva.fromJson(sub('chuva')),
      temperatura: Medida.fromJson(sub('temperatura')),
      sensacaoTermica: Medida.fromJson(sub('senstermica')),
      umidade: Medida.fromJson(sub('umidade')),
      pressao: Medida.fromJson(sub('pressaoatmos')),
      radiacao: Medida.fromJson(sub('radiacaosolar')),
      vento: DadosVento.fromJson(sub('vento')),
    );
  }
}

extension on String {
  String ifEmpty(String alternativa) => isEmpty ? alternativa : this;
}
