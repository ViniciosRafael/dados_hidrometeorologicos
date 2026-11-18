import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/estacao.dart';
import '../models/leitura_historica.dart';
import '../util/formatacao.dart';

enum TipoErroApi {
  semConexao,
  tempoEsgotado,
  limiteDeRequisicoes,
  consultaRecusada,
  acessoNegado,
  dadosInvalidos,
  servidor,
}

/// Erro de comunicação com a API, com mensagem pronta para o usuário.
class ApiException implements Exception {
  const ApiException(this.tipo, this.mensagem, {this.detalhe});

  final TipoErroApi tipo;
  final String mensagem;
  final String? detalhe;

  @override
  String toString() =>
      'ApiException($tipo): $mensagem${detalhe != null ? ' — $detalhe' : ''}';
}

class RespostaEstacoes {
  const RespostaEstacoes({required this.estacoes, this.proximaAtualizacao});

  /// Todas as estações devolvidas pela API (o filtro do recorte é feito
  /// depois, no controlador).
  final List<Estacao> estacoes;

  /// Quando vale a pena consultar de novo (UTC).
  final DateTime? proximaAtualizacao;
}

/// Acesso à API GraphQL da Defesa Civil RS.
///
/// A API é pública (sem login/JWT) e só aceita as duas consultas de
/// [ApiConfig]. Limite: 120 requisições por minuto por IP.
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> _post(
    String query, [
    Map<String, dynamic>? variaveis,
  ]) async {
    final http.Response resposta;
    try {
      resposta = await _client
          .post(
            Uri.parse(ApiConfig.endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'query': query,
              'variables': ?variaveis,
            }),
          )
          .timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw const ApiException(
        TipoErroApi.tempoEsgotado,
        'O serviço da Defesa Civil demorou demais para responder.',
      );
    } on SocketException catch (e) {
      throw ApiException(
        TipoErroApi.semConexao,
        'Sem conexão com a internet.',
        detalhe: e.message,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        TipoErroApi.semConexao,
        'Não foi possível conectar ao serviço da Defesa Civil.',
        detalhe: e.message,
      );
    }

    Map<String, dynamic>? corpo;
    try {
      final decodificado = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (decodificado is Map<String, dynamic>) corpo = decodificado;
    } on FormatException {
      corpo = null;
    }

    final erros = corpo?['errors'];
    if (erros is List && erros.isNotEmpty) {
      throw _erroGraphQL(erros.first);
    }
    if (resposta.statusCode == 429 ||
        resposta.body.contains('Too Many Requests')) {
      throw _limite;
    }
    if (resposta.statusCode != 200 || corpo == null) {
      throw ApiException(
        TipoErroApi.servidor,
        'Serviço da Defesa Civil indisponível no momento.',
        detalhe: 'HTTP ${resposta.statusCode}',
      );
    }
    final dados = corpo['data'];
    if (dados is! Map<String, dynamic>) {
      throw const ApiException(
        TipoErroApi.dadosInvalidos,
        'A resposta do serviço veio sem dados.',
      );
    }
    return dados;
  }

  static const _limite = ApiException(
    TipoErroApi.limiteDeRequisicoes,
    'Muitas consultas em pouco tempo. Aguarde um minuto.',
  );

  ApiException _erroGraphQL(dynamic erro) {
    final mensagem = erro is Map ? erro['message']?.toString() ?? '' : '$erro';
    final codigo = erro is Map && erro['extensions'] is Map
        ? (erro['extensions'] as Map)['code']?.toString()
        : null;
    if (mensagem.contains('Too Many Requests') ||
        mensagem.contains('Throttler')) {
      return _limite;
    }
    switch (codigo) {
      case 'QUERY_NOT_ALLOWED':
        return ApiException(
          TipoErroApi.consultaRecusada,
          'A consulta foi recusada pelo serviço.',
          detalhe: mensagem,
        );
      case 'FORBIDDEN':
        return ApiException(
          TipoErroApi.acessoNegado,
          'Acesso negado pelo serviço.',
          detalhe: mensagem,
        );
      case 'BAD_REQUEST':
        return ApiException(
          TipoErroApi.dadosInvalidos,
          'Período inválido para o histórico.',
          detalhe: mensagem,
        );
    }
    return ApiException(
      TipoErroApi.servidor,
      'O serviço da Defesa Civil devolveu um erro.',
      detalhe: mensagem,
    );
  }

  /// Consulta `Tags_data`: situação atual de todas as estações.
  Future<RespostaEstacoes> buscarEstacoes() async {
    final dados = await _post(ApiConfig.queryTagsData);
    final tags = dados['tags_data'];
    if (tags is! Map) {
      throw const ApiException(
        TipoErroApi.dadosInvalidos,
        'Resposta inesperada do serviço.',
      );
    }
    final lista = tags['qualle_meteorologia'];
    final estacoes = <Estacao>[
      if (lista is List)
        for (final item in lista)
          if (item is Map) Estacao.fromJson(Map<String, dynamic>.from(item)),
    ];
    final proxima = tags['proximaAtualizacaoEm']?.toString();
    return RespostaEstacoes(
      estacoes: estacoes,
      proximaAtualizacao:
          proxima == null ? null : DateTime.tryParse(proxima)?.toUtc(),
    );
  }

  /// Consulta `Historic`: série de uma estação entre [inicio] e [fim]
  /// (no máximo 3 meses atrás), agrupada em [intervalo].
  Future<List<LeituraHistorica>> buscarHistorico({
    required String codigo,
    required DateTime inicio,
    required DateTime fim,
    IntervaloHistorico intervalo = IntervaloHistorico.hora1,
  }) async {
    // A API recusa início além de 3 meses; deixa uma folga de 1 hora.
    final limite = DateTime.now()
        .subtract(ApiConfig.historicoMaximo)
        .add(const Duration(hours: 1));
    final inicioValido = inicio.isBefore(limite) ? limite : inicio;

    final dados = await _post(ApiConfig.queryHistoric, {
      'stationCode': codigo,
      'startDate': formatarDataParaApi(inicioValido),
      'endDate': formatarDataParaApi(fim),
      'interval': intervalo.valorApi,
    });

    dynamic historico = dados['historic'];
    // O campo é um escalar JSON; por garantia aceita também texto.
    if (historico is String) historico = jsonDecode(historico);
    final itens = historico is Map ? historico['items'] : null;
    if (itens is! List) return const [];
    return [
      for (final item in itens)
        if (item is Map)
          ?LeituraHistorica.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  /// Chuva acumulada nas últimas [horas] horas, somando os blocos de 1 hora
  /// da consulta `Historic`. Usada para o mm72, que a API não entrega pronto.
  ///
  /// Conferido em 17/11/2026: a soma de 48 h com HOUR_1 bateu com o `h048`
  /// da `Tags_data`. (Não usar HOUR_12: os blocos são fixos em 00h/12h e
  /// deixam de fora as últimas horas.)
  Future<double?> chuvaAcumulada(String codigo, {int horas = 72}) async {
    final agora = DateTime.now();
    final leituras = await buscarHistorico(
      codigo: codigo,
      inicio: agora.subtract(Duration(hours: horas)),
      fim: agora,
      intervalo: IntervaloHistorico.hora1,
    );
    return somarChuva(leituras);
  }

  void fechar() => _client.close();
}
