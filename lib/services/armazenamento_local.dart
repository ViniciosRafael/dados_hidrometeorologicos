import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/aviso.dart';

/// Dados guardados no aparelho: favoritas, último nível visto de cada
/// favorita (para gerar avisos também ao reabrir o app) e a lista de avisos.
class ArmazenamentoLocal {
  static const _chaveFavoritas = 'favoritas';
  static const _chaveUltimosNiveis = 'ultimos_niveis';
  static const _chaveAvisos = 'avisos';
  static const _chaveDemonstracao = 'modo_demonstracao';

  /// Quantidade máxima de avisos guardados.
  static const maxAvisos = 50;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<Set<String>> lerFavoritas() async =>
      ((await _p).getStringList(_chaveFavoritas) ?? const []).toSet();

  Future<void> salvarFavoritas(Set<String> codigos) async =>
      (await _p).setStringList(_chaveFavoritas, codigos.toList()..sort());

  /// codigo → valor do nível geral (0–3) visto na última atualização.
  Future<Map<String, int>> lerUltimosNiveis() async {
    final texto = (await _p).getString(_chaveUltimosNiveis);
    if (texto == null) return {};
    try {
      final mapa = jsonDecode(texto);
      if (mapa is! Map) return {};
      return {
        for (final e in mapa.entries)
          if (e.value is int) e.key.toString(): e.value as int,
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> salvarUltimosNiveis(Map<String, int> niveis) async =>
      (await _p).setString(_chaveUltimosNiveis, jsonEncode(niveis));

  Future<List<Aviso>> lerAvisos() async {
    final texto = (await _p).getString(_chaveAvisos);
    if (texto == null) return [];
    try {
      final lista = jsonDecode(texto);
      if (lista is! List) return [];
      return [
        for (final item in lista)
          if (item is Map) ?Aviso.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on FormatException {
      return [];
    }
  }

  Future<void> salvarAvisos(List<Aviso> avisos) async => (await _p).setString(
        _chaveAvisos,
        jsonEncode(avisos.take(maxAvisos).map((a) => a.toJson()).toList()),
      );

  Future<bool> lerModoDemonstracao() async =>
      (await _p).getBool(_chaveDemonstracao) ?? false;

  Future<void> salvarModoDemonstracao(bool ativo) async =>
      (await _p).setBool(_chaveDemonstracao, ativo);
}
