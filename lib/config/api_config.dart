/// Configuração da API de Dados Hidrometeorológicos da Defesa Civil RS.
///
/// Guia: https://sistemas.defesacivil.rs.gov.br/api-redehidrometeorologica
///
/// IMPORTANTE: a API só aceita o texto EXATO das duas consultas do guia
/// (mesmos campos, mesma ordem). Espaços e quebras de linha não importam,
/// mas tirar, acrescentar ou trocar a ordem de um campo faz a consulta ser
/// recusada com QUERY_NOT_ALLOWED. Não altere as consultas abaixo.
library;

class ApiConfig {
  ApiConfig._();

  static const String endpoint =
      'https://redehidrometeorologica.defesacivil.rs.gov.br/graphql';

  /// Único cliente aceito pela API.
  static const String cliente = 'casa-militar-defesa-civil-rs';

  /// Tempo máximo de espera por resposta.
  static const Duration timeout = Duration(seconds: 25);

  /// Os dados mudam a cada 5 minutos. Usado quando a API não informa
  /// `proximaAtualizacaoEm`.
  static const Duration intervaloPadrao = Duration(minutes: 5);

  /// A API só guarda 3 meses de histórico.
  static const Duration historicoMaximo = Duration(days: 90);

  /// Consulta `Tags_data`: leitura mais recente de todas as estações.
  static const String queryTagsData = r'''
query Tags_data {
  tags_data(clients: ["casa-militar-defesa-civil-rs"]) {
    qualle_meteorologia {
      codigo
      name {
        prefix
        general
        local
      }
      show
      timestamp
      position {
        bacia
        latitude
        longitude
        regiao
        altitude
        filtros {
          outros {
            crepdec {
              nome {
                value
              }
              codigo {
                value
              }
            }
          }
        }
      }
      data {
        rio {
          rio_alarmes {
            inundacao {
              ativo {
                value
              }
              status {
                value
              }
            }
          }
          rio_nome {
            value
          }
          rio_nivel {
            value
          }
          rio_nivel_tendencia {
            value
          }
          rio_area_drenagem {
            value
          }
          homologacao {
            relacao {
              valido {
                value
              }
            }
          }
        }
        chuva {
          acumulado {
            min005 {
              value
            }
            h001 {
              value
            }
            h003 {
              value
            }
            h006 {
              value
            }
            h012 {
              value
            }
            h024 {
              value
            }
            h048 {
              value
            }
            h168 {
              value
            }
          }
          homologacao {
            relacao {
              valido {
                value
              }
            }
          }
        }
        pressaoatmos {
          atual {
            value
          }
          historico {
            diaanterior {
              media {
                value
              }
            }
            diaatual {
              media {
                value
              }
            }
          }
          tendencia {
            value
          }
          homologacao {
            relacao {
              valido {
                value
              }
            }
          }
        }
        senstermica {
          atual {
            value
          }
          historico {
            diaatual {
              media {
                value
              }
            }
            diaanterior {
              media {
                value
              }
            }
          }
          tendencia {
            value
          }
          homologacao {
            relacao {
              valido {
                value
              }
            }
          }
        }
        radiacaosolar {
          atual {
            value
          }
          homologacao {
            relacao {
              valido {
                value
              }
            }
          }
        }
        temperatura {
          atual {
            value
          }
          historico {
            diaanterior {
              media {
                value
              }
            }
            diaatual {
              media {
                value
              }
              maxima {
                value
              }
              minima {
                value
              }
            }
          }
          tendencia {
            value
          }
          homologacao {
            relacao {
              valido {
                value
              }
            }
          }
        }
        umidade {
          atual {
            value
          }
          historico {
            diaanterior {
              media {
                value
              }
            }
            diaatual {
              media {
                value
              }
            }
          }
          tendencia {
            value
          }
          homologacao {
            relacao {
              valido {
                value
              }
            }
          }
        }
        vento {
          direcao {
            value
          }
          velocidade_maxima {
            value
          }
          velocidade_media {
            value
          }
          homologacao {
            relacao {
              valido {
                value
              }
            }
          }
        }
      }
      type
      filter {
        relacao {
          tem_chuva_acumulada
          tem_nivel_do_rio
          tem_pressao_atmosferica
          tem_sensacao_termica
          tem_umidade
          tem_vazao_do_rio
          tem_vento
        }
      }
      resource {
        estacao {
          estado {
            manutencao {
              value
            }
          }
        }
      }
    }
    proximaAtualizacaoEm
  }
}
''';

  /// Consulta `Historic`: série de uma estação. Os valores que mudam vão
  /// sempre em `variables`, nunca dentro do texto.
  static const String queryHistoric = r'''
query Historic($stationCode: String!, $startDate: String!, $endDate: String!, $interval: QueryInterval) {
  historic(
    system: Qualle_Hidrometeorologia
    client: "casa-militar-defesa-civil-rs"
    stationCode: $stationCode
    startDate: $startDate
    endDate: $endDate
    interval: $interval
    opts: { ordenacao: ASC }
  )
}
''';
}

/// Intervalos aceitos pela consulta `Historic`.
enum IntervaloHistorico {
  min5('MIN_5', Duration(minutes: 5)),
  min10('MIN_10', Duration(minutes: 10)),
  hora1('HOUR_1', Duration(hours: 1)),
  hora3('HOUR_3', Duration(hours: 3)),
  hora6('HOUR_6', Duration(hours: 6)),
  hora12('HOUR_12', Duration(hours: 12));

  const IntervaloHistorico(this.valorApi, this.duracao);
  final String valorApi;
  final Duration duracao;
}
