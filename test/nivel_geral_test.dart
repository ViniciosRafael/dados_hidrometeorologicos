import 'package:dados_hidrometeorologicos/domain/nivel.dart';
import 'package:dados_hidrometeorologicos/domain/nivel_geral.dart';
import 'package:dados_hidrometeorologicos/domain/nivel_rio.dart';
import 'package:flutter_test/flutter_test.dart';

ResultadoNivel r(Nivel? n, [String motivo = 'm']) =>
    ResultadoNivel(nivel: n, rotulo: n?.rotulo ?? 'Sem dados', motivo: motivo);

void main() {
  group('Nível geral = maior entre rio e chuva', () {
    final valores = <Nivel?>[null, ...Nivel.values];

    test('todas as combinações', () {
      for (final rio in valores) {
        for (final chuva in valores) {
          final g = calcularNivelGeral(rio: r(rio), chuva: r(chuva)).nivel;
          if (rio == null && chuva == null) {
            expect(g, isNull, reason: 'rio=$rio chuva=$chuva');
          } else {
            final esperado = [rio, chuva]
                .whereType<Nivel>()
                .reduce((a, b) => a.valor >= b.valor ? a : b);
            expect(g, esperado, reason: 'rio=$rio chuva=$chuva');
          }
        }
      }
    });

    test('sem dados de rio e chuva → "Sem dados", nunca Normal', () {
      final g = calcularNivelGeral(rio: r(null), chuva: r(null));
      expect(g.nivel, isNull);
      expect(g.rotulo, 'Sem dados');
    });

    test('rio sem limiar + chuva em alerta → alerta por chuva', () {
      final g = calcularNivelGeral(
        rio: r(null),
        chuva: r(Nivel.alerta, '56,0 mm em 24 h (limite 50 mm)'),
      );
      expect(g.nivel, Nivel.alerta);
      expect(g.motivo, 'por chuva: 56,0 mm em 24 h (limite 50 mm)');
    });

    test('rio maior que chuva → motivo "por nível do rio"', () {
      final g = calcularNivelGeral(rio: r(Nivel.critico), chuva: r(Nivel.atencao));
      expect(g.nivel, Nivel.critico);
      expect(g.motivo, 'por nível do rio');
    });
  });

  group('Nível do rio (tabela do guia da API)', () {
    ResultadoNivel rio({bool sensor = true, bool? ativo, int? status}) =>
        calcularNivelRio(
          temSensorDeRio: sensor,
          alarmeAtivo: ativo,
          status: status,
          nivelMetros: 32.5,
        );

    test('ativo=true e status 0..3', () {
      expect(rio(ativo: true, status: 0).nivel, Nivel.normal);
      expect(rio(ativo: true, status: 1).nivel, Nivel.atencao);
      expect(rio(ativo: true, status: 2).nivel, Nivel.alerta);
      expect(rio(ativo: true, status: 3).nivel, Nivel.critico);
      expect(rio(ativo: true, status: 3).rotulo, 'Inundação');
    });

    test('ativo=true e status null → sem leitura', () {
      final x = rio(ativo: true, status: null);
      expect(x.nivel, isNull);
      expect(x.rotulo, 'Sem leitura');
    });

    test('ativo=false → sem limiar cadastrado', () {
      final x = rio(ativo: false, status: 0);
      expect(x.nivel, isNull);
      expect(x.rotulo, 'Sem limiar');
    });

    test('sem sensor de rio', () {
      expect(rio(sensor: false, ativo: true, status: 2).nivel, isNull);
    });
  });
}
