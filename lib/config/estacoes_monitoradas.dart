/// Estações acompanhadas pelo app.
///
/// Recorte definido pelo professor: regiões (COREDEs) Vale do Rio Pardo e
/// Vale do Taquari. A API da Defesa Civil não informa o COREDE de cada
/// estação, então a lista é fixa e foi montada pelo município que aparece
/// no nome de cada estação (conferido em 17/11/2026).
///
/// Para acrescentar ou remover uma estação, altere apenas este mapa.
library;

enum Regiao {
  valeDoRioPardo('Vale do Rio Pardo'),
  valeDoTaquari('Vale do Taquari');

  const Regiao(this.rotulo);
  final String rotulo;
}

const Map<String, Regiao> estacoesMonitoradas = {
  // Vale do Rio Pardo
  'DCRS-00029': Regiao.valeDoRioPardo, // Sinimbu
  'DCRS-00101': Regiao.valeDoRioPardo, // Rio Pardo (H)
  'DCRS-00108': Regiao.valeDoRioPardo, // Santa Cruz do Sul
  'DCRS-00124': Regiao.valeDoRioPardo, // Candelária
  'DCRS-00055': Regiao.valeDoRioPardo, // Santa Cruz do Sul / Venâncio Aires
  'DCRS-00028': Regiao.valeDoRioPardo, // Rio Pardo – Rio Jacuí
  'DCRS-00030': Regiao.valeDoRioPardo, // Cerro Branco / Candelária (divisa)
  'DCRS-00066': Regiao.valeDoRioPardo, // Encruzilhada do Sul

  // Vale do Taquari
  'DCRS-00009': Regiao.valeDoTaquari, // Imigrante
  'DCRS-00010': Regiao.valeDoTaquari, // Teutônia
  'DCRS-00011': Regiao.valeDoTaquari, // Travesseiro – Pouso Novo
  'DCRS-00013': Regiao.valeDoTaquari, // Putinga
  'DCRS-00057': Regiao.valeDoTaquari, // Cotiporã – Dois Lajeados (divisa)
  'DCRS-00068': Regiao.valeDoTaquari, // Canudos do Vale
  'DCRS-00082': Regiao.valeDoTaquari, // Encantado (H)
  'DCRS-00091': Regiao.valeDoTaquari, // Muçum / Encantado
  'DCRS-00092': Regiao.valeDoTaquari, // Encantado / Roca Sales
  'DCRS-00104': Regiao.valeDoTaquari, // Arroio do Meio / Lajeado (H)
  'DCRS-00121': Regiao.valeDoTaquari, // Guaporé / Anta Gorda (divisa)
  'DCRS-00123': Regiao.valeDoTaquari, // Arroio do Meio – Rio Taquari
};

/// Municípios de cada estação (para o filtro por município). Estações de
/// divisa aparecem nos dois municípios.
const Map<String, List<String>> municipiosDasEstacoes = {
  'DCRS-00029': ['Sinimbu'],
  'DCRS-00101': ['Rio Pardo'],
  'DCRS-00108': ['Santa Cruz do Sul'],
  'DCRS-00124': ['Candelária'],
  'DCRS-00055': ['Santa Cruz do Sul', 'Venâncio Aires'],
  'DCRS-00028': ['Rio Pardo'],
  'DCRS-00030': ['Cerro Branco', 'Candelária'],
  'DCRS-00066': ['Encruzilhada do Sul'],
  'DCRS-00009': ['Imigrante'],
  'DCRS-00010': ['Teutônia'],
  'DCRS-00011': ['Travesseiro', 'Pouso Novo'],
  'DCRS-00013': ['Putinga'],
  'DCRS-00057': ['Cotiporã', 'Dois Lajeados'],
  'DCRS-00068': ['Canudos do Vale'],
  'DCRS-00082': ['Encantado'],
  'DCRS-00091': ['Muçum', 'Encantado'],
  'DCRS-00092': ['Encantado', 'Roca Sales'],
  'DCRS-00104': ['Arroio do Meio', 'Lajeado'],
  'DCRS-00121': ['Guaporé', 'Anta Gorda'],
  'DCRS-00123': ['Arroio do Meio'],
};

/// Estação usada como "estação de teste" nos critérios de aceite e no
/// modo demonstração quando não há favoritas.
const String estacaoDeTeste = 'DCRS-00108';
