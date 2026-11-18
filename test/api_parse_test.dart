import 'dart:convert';

import 'package:dados_hidrometeorologicos/config/estacoes_monitoradas.dart';
import 'package:dados_hidrometeorologicos/domain/nivel.dart';
import 'package:dados_hidrometeorologicos/models/estacao.dart';
import 'package:dados_hidrometeorologicos/models/leitura_historica.dart';
import 'package:dados_hidrometeorologicos/models/situacao_estacao.dart';
import 'package:dados_hidrometeorologicos/util/formatacao.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resposta real da Tags_data para DCRS-00108 (17/11/2026), resumida.
const _santaCruz = r'''
{"codigo":"DCRS-00108","name":{"prefix":"DCRS-00108","general":"Santa Cruz do Sul","local":""},
 "show":"true","timestamp":"2026-11-17T22:25:00.000",
 "position":{"bacia":"RS - Rio Pardo","latitude":-29.645999908447266,"longitude":-52.462799072265625,
  "regiao":"Centro Oriental Rio-grandense","altitude":null,
  "filtros":{"outros":{"crepdec":{"nome":{"value":"LAJEADO"},"codigo":{"value":8}}}}},
 "data":{
  "rio":{"rio_alarmes":{"inundacao":{"ativo":{"value":true},"status":{"value":0}}},
   "rio_nome":null,"rio_nivel":{"value":32.54},"rio_nivel_tendencia":{"value":0},
   "rio_area_drenagem":null,"homologacao":{"relacao":{"valido":{"value":true}}}},
  "chuva":{"acumulado":{"min005":{"value":0},"h001":{"value":0},"h003":{"value":0},"h006":{"value":0},
   "h012":{"value":2.4},"h024":{"value":2.4},"h048":{"value":2.4},"h168":{"value":3.4}},
   "homologacao":{"relacao":{"valido":{"value":true}}}},
  "temperatura":{"atual":{"value":21.17},"historico":{"diaanterior":{"media":{"value":25.11}},
   "diaatual":{"media":{"value":23.81},"maxima":{"value":31.27},"minima":{"value":19.3}}},
   "tendencia":{"value":-0.23},"homologacao":{"relacao":{"valido":{"value":true}}}},
  "umidade":{"atual":{"value":93.51},"homologacao":{"relacao":{"valido":{"value":true}}}},
  "vento":{"direcao":{"value":35.8},"velocidade_maxima":{"value":4.5},"velocidade_media":{"value":0.71},
   "homologacao":{"relacao":{"valido":{"value":true}}}}},
 "type":"HidroMeteo",
 "filter":{"relacao":{"tem_chuva_acumulada":true,"tem_nivel_do_rio":true,"tem_pressao_atmosferica":true,
  "tem_sensacao_termica":true,"tem_umidade":true,"tem_vazao_do_rio":false,"tem_vento":true}},
 "resource":{"estacao":{"estado":{"manutencao":{"value":false}}}}}
''';

/// Estação fora do ar (DCRS-00011 em 17/11/2026): timestamp nulo e
/// acumulados de chuva zerados.
const _foraDoAr = r'''
{"codigo":"DCRS-00011","name":{"general":"Travesseiro - Pouso Novo","local":""},"timestamp":null,
 "position":{"bacia":"RS - Rio Taquari-Antas","latitude":-29.2145,"longitude":-52.1595},
 "data":{"rio":{"rio_alarmes":{"inundacao":{"ativo":{"value":true},"status":{"value":null}}},
   "rio_nivel":{"value":null}},
  "chuva":{"acumulado":{"min005":{"value":null},"h024":{"value":0},"h048":{"value":0}}}},
 "filter":{"relacao":{"tem_chuva_acumulada":true,"tem_nivel_do_rio":true}},
 "resource":{"estacao":{"estado":{"manutencao":{"value":false}}}}}
''';

void main() {
  test('lê a estação de Santa Cruz do Sul', () {
    final e = Estacao.fromJson(jsonDecode(_santaCruz));
    expect(e.codigo, 'DCRS-00108');
    expect(e.nome, 'Santa Cruz do Sul');
    expect(e.regiao, Regiao.valeDoRioPardo);
    expect(e.bacia, 'Rio Pardo');
    expect(e.coordenadoria, 'LAJEADO');
    expect(e.latitude, closeTo(-29.646, 0.001));
    expect(e.rio.nivel, 32.54);
    expect(e.rio.alarmeAtivo, isTrue);
    expect(e.rio.alarmeStatus, 0);
    expect(e.chuva.h24, 2.4);
    expect(e.chuva.h168, 3.4);
    expect(e.temperatura.maximaHoje, 31.27);
    expect(e.vento.direcao, 35.8);
    expect(e.sensores.nivelRio, isTrue);
    expect(e.sensores.vazao, isFalse);
    expect(e.emManutencao, isFalse);
    // 22:25 em Brasília = 01:25 UTC do dia seguinte.
    expect(e.ultimaLeitura, DateTime.utc(2026, 11, 18, 1, 25));
  });

  test('situação de Santa Cruz: rio normal, chuva normal → geral normal', () {
    final e = Estacao.fromJson(jsonDecode(_santaCruz));
    final s = SituacaoEstacao.calcular(e, mm72: 3.0);
    expect(s.rio.nivel, Nivel.normal);
    expect(s.chuva.nivel, Nivel.normal);
    expect(s.geral.nivel, Nivel.normal);
  });

  test('estação fora do ar: chuva zerada não conta como NORMAL', () {
    final e = Estacao.fromJson(jsonDecode(_foraDoAr));
    expect(e.semLeitura, isTrue);
    final s = SituacaoEstacao.calcular(e, mm72: null);
    expect(s.rio.rotulo, 'Sem leitura');
    expect(s.chuva.nivel, isNull);
    expect(s.geral.nivel, isNull);
    expect(s.geral.rotulo, 'Sem dados');
  });

  test('modo demonstração simula ALERTA', () {
    final e = Estacao.fromJson(jsonDecode(_santaCruz));
    final s = SituacaoEstacao.calcular(e).simularAlerta();
    expect(s.geral.nivel, Nivel.alerta);
  });

  test('histórico: soma a chuva por bloco (chuva_mm), ignorando nulos', () {
    final itens = [
      {'ts': '2026-11-17T09:00:00.000', 'chuva_mm': 1.2, 'chuva_total': 50},
      {'ts': '2026-11-17T10:00:00.000', 'chuva_mm': null},
      {'ts': '2026-11-17T11:00:00.000', 'chuva_mm': 3.3, 'rio_nivel': 27.24},
    ].map((j) => LeituraHistorica.fromJson(j)!).toList();
    expect(somarChuva(itens), closeTo(4.5, 1e-9));
    expect(itens.last.nivelRio, 27.24);
    expect(somarChuva([]), isNull);
  });

  test('datas da API em horário de Brasília', () {
    expect(lerDataBrasilia('2026-10-14T08:40:00.000'),
        DateTime.utc(2026, 10, 14, 11, 40));
    expect(lerDataBrasilia(null), isNull);
    expect(formatarDataParaApi(DateTime.utc(2026, 10, 13, 15)),
        '2026-10-13 12:00:00');
  });

  test('lista do recorte tem 20 estações e todas têm município', () {
    expect(estacoesMonitoradas.length, 20);
    expect(
      estacoesMonitoradas.keys.every(municipiosDasEstacoes.containsKey),
      isTrue,
    );
  });
}
