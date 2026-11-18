# Hidro Vales — monitoramento hidrometeorológico e risco de enchentes

App Android em Flutter (trabalho de Dispositivos Móveis, **Opção 3**). O app consulta a
**Rede Hidrometeorológica da Defesa Civil RS** e mostra nível dos rios, chuva e condições de
**20 estações dos Vales do Rio Pardo e do Taquari**, com histórico e avisos indicativos.

> Indicação não oficial. Não é previsão garantida de enchente e não substitui os comunicados
> da Defesa Civil.

## Como rodar

Requisitos: Flutter (SDK Dart ^3.13), Android Studio e um emulador ou celular com
**Android 7.0 (API 24)** ou mais novo.

```bash
flutter pub get
flutter test          # testes das regras de nível e da leitura da API
flutter run           # roda no emulador/celular conectado
flutter build apk     # gera build/app/outputs/flutter-apk/app-release.apk
```

Teste no **emulador ou celular**. A API bloqueia chamadas feitas por navegador vindas de
outros sites (CORS), então `flutter run -d chrome` não carrega os dados.

## Telas e requisitos

| Tela | O que mostra | Requisitos |
|---|---|---|
| **Início** | Quantidade de estações por nível, banner de avisos das favoritas, favoritas, estações em atenção ou acima, hora da medição e da próxima atualização | HM-01, HM-07, HM-09 |
| **Estações** | Lista e mapa (OpenStreetMap) coloridos pelo nível geral; busca; filtros por região, município, tipo (sensores), favoritas e "atenção ou acima" | HM-02, HM-05 |
| **Detalhe** | Nível geral, rio e chuva com o motivo de cada um; tabela de chuva × limiares; medidas atuais; gráfico histórico (24 h a 90 dias) com linhas de limiar; avisos de dado atrasado, manutenção ou não homologado | HM-03, HM-04, HM-06, HM-08, HM-09 |
| **Avisos** | Avisos gerados quando o nível geral de uma favorita sobe para atenção ou acima; modo demonstração | HM-07 |
| **Sobre** | Fonte dos dados, regras dos níveis, limites dos indicadores, aviso de caráter não oficial, lista de estações | HM-10 |

## Regras de nível

O app mostra **três indicadores** por estação, na escala 0–3 com as cores da Defesa Civil:

| Escala | Rio (API) | Chuva (documento) | Geral | Cor |
|---|---|---|---|---|
| 0 | Normalidade | NORMAL | Normal | `#69a82f` |
| 1 | Atenção Inundação | ATENÇÃO | Atenção | `#faba00` |
| 2 | Alerta Inundação | ALERTA | Alerta | `#e67819` |
| 3 | Inundação | EMERGÊNCIA | Crítico | `#e20228` |

- **Rio:** vem pronto da API (`rio_alarmes.inundacao`). As cotas em metros não são publicadas.
- **Chuva** (`lib/domain/nivel_chuva.dart`), regra do documento de requisitos; vale o maior
  nível atingido:
  - ATENÇÃO: 24 h ≥ 30 mm, ou 48 h ≥ 50 mm, ou 72 h ≥ 60 mm
  - ALERTA: 24 h ≥ 50, ou 48 h ≥ 70, ou 72 h ≥ 90
  - EMERGÊNCIA: 24 h ≥ 80, ou 48 h ≥ 100, ou 72 h ≥ 120

  Os acumulados de 24 h e 48 h vêm da API. O de 72 h é a soma de `chuva_mm` da consulta
  `Historic` com intervalo de 1 hora: a soma de 48 h por esse método bateu com o `h048` da API.
- **Geral** (`lib/domain/nivel_geral.dart`): o maior entre rio e chuva, considerando só os que
  têm dado. Sem nenhum dado, aparece "Sem dados", nunca "Normal".

## API consumida

`POST https://redehidrometeorologica.defesacivil.rs.gov.br/graphql` (pública, sem login).

| Consulta | Uso | Frequência |
|---|---|---|
| `Tags_data` | Situação atual das 130 estações; o app filtra as 20 do recorte | No horário de `proximaAtualizacaoEm` (≈ 5 min), só com o app aberto |
| `Historic` (HOUR_1, 72 h) | Acumulado de 72 h de cada estação | No máximo a cada 15 min (20 consultas) |
| `Historic` (período escolhido) | Gráfico do detalhe | Ao abrir o gráfico ou trocar o período |

A API só aceita o **texto exato** das duas consultas (`lib/config/api_config.dart`). Não
altere nem a ordem dos campos. Limite: 120 requisições por minuto por IP.

**Permissões do aparelho:** apenas `INTERNET`.

## Estrutura

```
lib/
  config/    api_config.dart (endpoint e consultas), estacoes_monitoradas.dart (20 estações)
  domain/    nivel.dart, nivel_rio.dart, nivel_chuva.dart, nivel_geral.dart (regras puras)
  models/    estacao.dart, leitura_historica.dart, situacao_estacao.dart, aviso.dart
  services/  api_service.dart (HTTP + erros), armazenamento_local.dart (favoritas e avisos)
  state/     monitoramento_controller.dart (atualização periódica, níveis, avisos)
  screens/   inicio, estacoes (lista + mapa), detalhe, avisos, sobre
  widgets/   nivel_badge, estacao_card, status_atualizacao, grafico_historico
test/        regras de chuva, rio e geral; leitura da API com JSON real; widget
```

## Estações acompanhadas

Para incluir ou tirar uma estação, edite `lib/config/estacoes_monitoradas.dart`.

- **Vale do Rio Pardo:** DCRS-00029 Sinimbu, 00101 Rio Pardo (H), 00108 Santa Cruz do Sul,
  00124 Candelária, 00055 Santa Cruz do Sul / Venâncio Aires, 00028 Rio Pardo – Rio Jacuí,
  00030 Cerro Branco / Candelária, 00066 Encruzilhada do Sul.
- **Vale do Taquari:** DCRS-00009 Imigrante, 00010 Teutônia, 00011 Travesseiro – Pouso Novo,
  00013 Putinga, 00057 Cotiporã – Dois Lajeados, 00068 Canudos do Vale, 00082 Encantado (H),
  00091 Muçum / Encantado, 00092 Encantado / Roca Sales, 00104 Arroio do Meio / Lajeado (H),
  00121 Guaporé / Anta Gorda, 00123 Arroio do Meio – Rio Taquari.

## Demonstração dos avisos

Para testar os avisos sem chuva real, ligue o **modo demonstração** na aba Avisos. Ele simula
chuva em ALERTA na primeira favorita (ou em Santa Cruz do Sul, se não houver favorita). O
aviso, o banner da tela inicial e o contador do sino aparecem na hora.
