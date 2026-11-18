import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/api_config.dart';
import '../config/estacoes_monitoradas.dart';
import '../domain/nivel.dart';
import '../models/aviso.dart';
import '../models/estacao.dart';
import '../models/situacao_estacao.dart';
import '../services/api_service.dart';
import '../services/armazenamento_local.dart';

/// Estado central do app: estações, níveis, favoritas e avisos.
///
/// Ciclo: consulta `Tags_data` (todas as estações), filtra as 20 do recorte,
/// busca o acumulado de 72 h no histórico, calcula os níveis e gera avisos
/// para as favoritas. Repete no horário indicado pela API
/// (`proximaAtualizacaoEm`), normalmente a cada 5 minutos, enquanto o app
/// estiver aberto.
class MonitoramentoController extends ChangeNotifier {
  MonitoramentoController({ApiService? api, ArmazenamentoLocal? armazenamento})
      : api = api ?? ApiService(),
        _armazenamento = armazenamento ?? ArmazenamentoLocal();

  final ApiService api;
  final ArmazenamentoLocal _armazenamento;

  /// O acumulado de 72 h muda devagar; recalcula no máximo a cada 15 min
  /// (20 consultas por vez, bem abaixo do limite de 120 por minuto).
  static const _validadeMm72 = Duration(minutes: 15);

  List<Estacao> _estacoes = const [];
  final Map<String, SituacaoEstacao> _situacoes = {};
  final Map<String, double?> _mm72 = {};
  DateTime? _mm72CalculadoEm;

  Set<String> _favoritas = {};
  Map<String, int> _ultimosNiveis = {};
  List<Aviso> _avisos = [];
  bool _modoDemonstracao = false;

  bool _carregando = false;
  bool _iniciado = false;
  ApiException? _erro;
  DateTime? _ultimaConsulta;
  DateTime? _proximaAtualizacao;
  Timer? _timer;
  bool _pausado = false;

  // ---------------------------------------------------------------- leitura

  /// Estações do recorte, ordenadas do nível geral mais alto para o mais baixo.
  List<Estacao> get estacoes => _estacoes;

  SituacaoEstacao? situacao(String codigo) => _situacoes[codigo];

  Estacao? estacao(String codigo) {
    for (final e in _estacoes) {
      if (e.codigo == codigo) return e;
    }
    return null;
  }

  bool get carregando => _carregando;

  /// Ainda não houve nenhuma resposta da API.
  bool get semDadosAinda => _ultimaConsulta == null;

  ApiException? get erro => _erro;

  /// Quando o app recebeu dados da API pela última vez.
  DateTime? get ultimaConsulta => _ultimaConsulta;

  DateTime? get proximaAtualizacao => _proximaAtualizacao;

  /// Leitura mais recente entre as estações (horário da medição).
  DateTime? get leituraMaisRecente {
    DateTime? maior;
    for (final e in _estacoes) {
      final t = e.ultimaLeitura;
      if (t != null && (maior == null || t.isAfter(maior))) maior = t;
    }
    return maior;
  }

  Set<String> get favoritas => _favoritas;

  bool ehFavorita(String codigo) => _favoritas.contains(codigo);

  List<Aviso> get avisos => _avisos;

  int get avisosNaoLidos => _avisos.where((a) => !a.lido).length;

  bool get modoDemonstracao => _modoDemonstracao;

  /// Estação que recebe a simulação no modo demonstração.
  String get codigoDemonstracao {
    final favoritasOrdenadas = _favoritas.toList()..sort();
    return favoritasOrdenadas.isNotEmpty
        ? favoritasOrdenadas.first
        : estacaoDeTeste;
  }

  /// Favoritas com nível geral em atenção ou acima (banner da Home).
  List<Estacao> get favoritasEmAtencao => [
        for (final e in _estacoes)
          if (_favoritas.contains(e.codigo) &&
              (_situacoes[e.codigo]?.geral.nivel?.valor ?? -1) >=
                  Nivel.atencao.valor)
            e,
      ];

  /// Quantidade de estações por nível geral (null = sem dados).
  Map<Nivel?, int> get contagemPorNivel {
    final mapa = <Nivel?, int>{};
    for (final e in _estacoes) {
      final n = _situacoes[e.codigo]?.geral.nivel;
      mapa[n] = (mapa[n] ?? 0) + 1;
    }
    return mapa;
  }

  // ------------------------------------------------------------- ciclo de vida

  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    _favoritas = await _armazenamento.lerFavoritas();
    _ultimosNiveis = await _armazenamento.lerUltimosNiveis();
    _avisos = await _armazenamento.lerAvisos();
    _modoDemonstracao = await _armazenamento.lerModoDemonstracao();
    notifyListeners();
    await atualizar();
  }

  /// App foi para segundo plano: para de consultar.
  void pausar() {
    _pausado = true;
    _timer?.cancel();
  }

  /// App voltou: atualiza se já passou da hora.
  void retomar() {
    if (!_pausado) return;
    _pausado = false;
    final proxima = _proximaAtualizacao;
    if (proxima == null || DateTime.now().isAfter(proxima)) {
      atualizar();
    } else {
      _agendar();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    api.fechar();
    super.dispose();
  }

  // ---------------------------------------------------------------- atualizar

  /// Busca os dados atuais. [manual] = puxado pelo usuário (recalcula também
  /// o acumulado de 72 h).
  Future<void> atualizar({bool manual = false}) async {
    if (_carregando) return;
    _carregando = true;
    _timer?.cancel();
    notifyListeners();

    try {
      final resposta = await api.buscarEstacoes();
      final doRecorte = resposta.estacoes
          .where((e) => estacoesMonitoradas.containsKey(e.codigo))
          .toList();

      _estacoes = doRecorte;
      _proximaAtualizacao = resposta.proximaAtualizacao;
      _ultimaConsulta = DateTime.now();
      _erro = null;

      await _atualizarMm72(forcar: manual);
      _recalcularSituacoes();
      await _verificarAvisos();
    } on ApiException catch (e) {
      _erro = e;
    } catch (e) {
      debugPrint('Erro inesperado ao atualizar: $e');
      _erro = ApiException(
        TipoErroApi.servidor,
        'Erro inesperado ao ler os dados.',
        detalhe: '$e',
      );
    } finally {
      _carregando = false;
      _agendar();
      notifyListeners();
    }
  }

  void _agendar() {
    _timer?.cancel();
    if (_pausado) return;
    final agora = DateTime.now();
    Duration espera;
    final proxima = _proximaAtualizacao;
    if (_erro != null) {
      // Com erro, tenta de novo em 1 minuto.
      espera = const Duration(minutes: 1);
    } else if (proxima != null && proxima.isAfter(agora)) {
      // Pequena folga depois do horário indicado pela API.
      espera = proxima.difference(agora) + const Duration(seconds: 20);
    } else {
      espera = ApiConfig.intervaloPadrao;
    }
    if (espera < const Duration(seconds: 60)) {
      espera = const Duration(seconds: 60);
    }
    _timer = Timer(espera, atualizar);
  }

  Future<void> _atualizarMm72({bool forcar = false}) async {
    final calculado = _mm72CalculadoEm;
    final valido = calculado != null &&
        DateTime.now().difference(calculado) < _validadeMm72;
    if (valido && !forcar) return;

    final codigos = _estacoes
        .where((e) => e.sensores.chuva && !e.semLeitura)
        .map((e) => e.codigo)
        .toList();
    final resultados = await Future.wait(codigos.map((c) async {
      try {
        return MapEntry(c, await api.chuvaAcumulada(c, horas: 72));
      } on ApiException {
        // Sem o 72 h, o nível de chuva usa só 24 h e 48 h.
        return MapEntry<String, double?>(c, _mm72[c]);
      }
    }));
    _mm72
      ..clear()
      ..addEntries(resultados);
    _mm72CalculadoEm = DateTime.now();
  }

  void _recalcularSituacoes() {
    _situacoes.clear();
    for (final e in _estacoes) {
      var s = SituacaoEstacao.calcular(e, mm72: _mm72[e.codigo]);
      if (_modoDemonstracao && e.codigo == codigoDemonstracao) {
        s = s.simularAlerta();
      }
      _situacoes[e.codigo] = s;
    }
    _estacoes = [..._estacoes]..sort((a, b) {
        final na = _situacoes[a.codigo]?.geral.nivel?.valor ?? -1;
        final nb = _situacoes[b.codigo]?.geral.nivel?.valor ?? -1;
        if (na != nb) return nb.compareTo(na);
        return a.nome.compareTo(b.nome);
      });
  }

  // ------------------------------------------------------------------- avisos

  /// Gera um aviso quando o nível geral de uma favorita sobe e fica em
  /// atenção ou acima. Guarda o último nível visto para comparar também
  /// depois que o app é fechado e aberto de novo.
  Future<void> _verificarAvisos() async {
    var mudou = false;
    for (final codigo in _favoritas) {
      final s = _situacoes[codigo];
      final e = estacao(codigo);
      final nivel = s?.geral.nivel;
      if (s == null || e == null || nivel == null) continue;

      final anterior = Nivel.doValor(_ultimosNiveis[codigo]);
      final subiu = anterior == null || nivel > anterior;
      if (nivel >= Nivel.atencao && subiu) {
        _avisos.insert(
          0,
          Aviso(
            codigo: codigo,
            nomeEstacao: e.nome,
            nivel: nivel,
            nivelAnterior: anterior,
            motivo: s.geral.motivo,
            horario: DateTime.now(),
            simulado: _modoDemonstracao && codigo == codigoDemonstracao,
          ),
        );
        mudou = true;
      }
      if (_ultimosNiveis[codigo] != nivel.valor) {
        _ultimosNiveis[codigo] = nivel.valor;
        mudou = true;
      }
    }
    if (mudou) {
      if (_avisos.length > ArmazenamentoLocal.maxAvisos) {
        _avisos = _avisos.take(ArmazenamentoLocal.maxAvisos).toList();
      }
      await _armazenamento.salvarAvisos(_avisos);
      await _armazenamento.salvarUltimosNiveis(_ultimosNiveis);
    }
  }

  Future<void> marcarAvisosComoLidos() async {
    if (avisosNaoLidos == 0) return;
    _avisos = [for (final a in _avisos) a.lido ? a : a.marcarLido()];
    notifyListeners();
    await _armazenamento.salvarAvisos(_avisos);
  }

  Future<void> limparAvisos() async {
    _avisos = [];
    notifyListeners();
    await _armazenamento.salvarAvisos(_avisos);
  }

  // ---------------------------------------------------------------- favoritas

  Future<void> alternarFavorita(String codigo) async {
    final nova = {..._favoritas};
    if (!nova.remove(codigo)) {
      nova.add(codigo);
    } else {
      // Ao desfavoritar, esquece o último nível (se voltar a ser favorita,
      // avisa de novo se estiver em atenção).
      _ultimosNiveis.remove(codigo);
      await _armazenamento.salvarUltimosNiveis(_ultimosNiveis);
    }
    _favoritas = nova;
    notifyListeners();
    await _armazenamento.salvarFavoritas(_favoritas);
    // Nova favorita já em atenção gera aviso na hora.
    if (_situacoes.isNotEmpty) {
      await _verificarAvisos();
      notifyListeners();
    }
  }

  // ------------------------------------------------------- modo demonstração

  /// Simula ALERTA de chuva na primeira favorita (ou na estação de teste),
  /// para apresentar os avisos mesmo sem chuva real.
  Future<void> definirModoDemonstracao(bool ativo) async {
    _modoDemonstracao = ativo;
    await _armazenamento.salvarModoDemonstracao(ativo);
    final codigo = codigoDemonstracao;
    if (ativo && !_favoritas.contains(codigo)) {
      _favoritas = {..._favoritas, codigo};
      await _armazenamento.salvarFavoritas(_favoritas);
    }
    if (_estacoes.isNotEmpty) {
      _recalcularSituacoes();
      await _verificarAvisos();
    }
    notifyListeners();
  }
}

/// Disponibiliza o controlador para as telas e as reconstrói quando ele muda.
class MonitoramentoScope extends InheritedNotifier<MonitoramentoController> {
  const MonitoramentoScope({
    super.key,
    required MonitoramentoController controller,
    required super.child,
  }) : super(notifier: controller);

  static MonitoramentoController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MonitoramentoScope>();
    assert(scope != null, 'MonitoramentoScope não encontrado');
    return scope!.notifier!;
  }

  /// Acesso sem registrar dependência (para callbacks fora do build).
  static MonitoramentoController read(BuildContext context) => context
      .getInheritedWidgetOfExactType<MonitoramentoScope>()!
      .notifier!;
}
