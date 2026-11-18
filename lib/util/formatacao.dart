/// Formatação simples em português (sem depender do pacote intl).
library;

/// Número com vírgula decimal: formatarNumero(3.456, 1) → "3,5".
String formatarNumero(num valor, int casas) =>
    valor.toStringAsFixed(casas).replaceAll('.', ',');

String _dois(int n) => n.toString().padLeft(2, '0');

/// "17/11 22:25"
String formatarDataHoraCurta(DateTime d) {
  final l = d.toLocal();
  return '${_dois(l.day)}/${_dois(l.month)} ${_dois(l.hour)}:${_dois(l.minute)}';
}

/// "17/11/2026 22:25"
String formatarDataHora(DateTime d) {
  final l = d.toLocal();
  return '${_dois(l.day)}/${_dois(l.month)}/${l.year} '
      '${_dois(l.hour)}:${_dois(l.minute)}';
}

/// "22:25"
String formatarHora(DateTime d) {
  final l = d.toLocal();
  return '${_dois(l.hour)}:${_dois(l.minute)}';
}

/// "há 3 min", "há 2 h", "há 4 dias".
String formatarTempoDecorrido(DateTime d, {DateTime? agora}) {
  final diff = (agora ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  return 'há ${diff.inDays} dia${diff.inDays > 1 ? 's' : ''}';
}

/// A API trabalha com horário de Brasília (UTC−3, sem horário de verão)
/// e envia datas sem fuso: "2026-11-17T22:25:00.000".
/// Converte para um DateTime absoluto (UTC).
DateTime? lerDataBrasilia(String? texto) {
  if (texto == null || texto.isEmpty) return null;
  final temFuso =
      texto.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(texto);
  return DateTime.tryParse(temFuso ? texto : '$texto-03:00')?.toUtc();
}

/// Formato pedido pela consulta `Historic`: "AAAA-MM-DD HH:MM:SS" em
/// horário de Brasília.
String formatarDataParaApi(DateTime d) {
  final b = d.toUtc().subtract(const Duration(hours: 3));
  return '${b.year}-${_dois(b.month)}-${_dois(b.day)} '
      '${_dois(b.hour)}:${_dois(b.minute)}:${_dois(b.second)}';
}

/// Direção do vento em graus → ponto cardeal (N, NE, L, SE, S, SO, O, NO).
String direcaoCardeal(double graus) {
  const pontos = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
  final i = ((graus % 360) / 45).round() % 8;
  return pontos[i];
}
