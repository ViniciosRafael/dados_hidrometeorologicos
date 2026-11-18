import 'package:dados_hidrometeorologicos/domain/nivel.dart';
import 'package:dados_hidrometeorologicos/domain/nivel_chuva.dart';
import 'package:flutter_test/flutter_test.dart';

Nivel? nivel({double? mm24, double? mm48, double? mm72}) =>
    calcularNivelChuva(mm24: mm24, mm48: mm48, mm72: mm72).nivel;

void main() {
  group('Regra de chuva do documento de requisitos', () {
    test('sem chuva é NORMAL', () {
      expect(nivel(mm24: 0, mm48: 0, mm72: 0), Nivel.normal);
    });

    test('logo abaixo dos limiares de atenção continua NORMAL', () {
      expect(nivel(mm24: 29.9, mm48: 49.9, mm72: 59.9), Nivel.normal);
    });

    test('ATENÇÃO exatamente nos limites (>=)', () {
      expect(nivel(mm24: 30, mm48: 0, mm72: 0), Nivel.atencao);
      expect(nivel(mm24: 0, mm48: 50, mm72: 0), Nivel.atencao);
      expect(nivel(mm24: 0, mm48: 0, mm72: 60), Nivel.atencao);
    });

    test('ALERTA exatamente nos limites', () {
      expect(nivel(mm24: 50, mm48: 0, mm72: 0), Nivel.alerta);
      expect(nivel(mm24: 0, mm48: 70, mm72: 0), Nivel.alerta);
      expect(nivel(mm24: 0, mm48: 0, mm72: 90), Nivel.alerta);
    });

    test('EMERGÊNCIA (crítico) exatamente nos limites', () {
      expect(nivel(mm24: 80, mm48: 0, mm72: 0), Nivel.critico);
      expect(nivel(mm24: 0, mm48: 100, mm72: 0), Nivel.critico);
      expect(nivel(mm24: 0, mm48: 0, mm72: 120), Nivel.critico);
    });

    test('vale o maior nível atingido entre as janelas', () {
      // 24 h em atenção, 72 h em emergência → emergência.
      expect(nivel(mm24: 35, mm48: 60, mm72: 125), Nivel.critico);
      // 24 h em alerta, 48 h em atenção → alerta.
      expect(nivel(mm24: 55, mm48: 55, mm72: 55), Nivel.alerta);
    });

    test('valor nulo é ignorado, não vira zero nem dispara', () {
      expect(nivel(mm24: 31, mm48: null, mm72: null), Nivel.atencao);
      expect(nivel(mm24: null, mm48: null, mm72: 95), Nivel.alerta);
      expect(nivel(mm24: 10, mm48: 20, mm72: null), Nivel.normal);
    });

    test('todos nulos → sem dados (nunca NORMAL)', () {
      final r = calcularNivelChuva(mm24: null, mm48: null, mm72: null);
      expect(r.nivel, isNull);
      expect(r.rotulo, 'Sem dados');
    });

    test('rótulos e motivo seguem o documento', () {
      final r = calcularNivelChuva(mm24: 56, mm48: 56, mm72: 56);
      expect(r.rotulo, 'ALERTA');
      expect(r.motivo, '56,0 mm em 24 h (limite 50 mm)');
      expect(
        calcularNivelChuva(mm24: 81, mm48: 0, mm72: 0).rotulo,
        'EMERGÊNCIA',
      );
    });

    test('NORMAL avisa quando o acumulado de 72 h não está disponível', () {
      final r = calcularNivelChuva(mm24: 2.4, mm48: 2.4, mm72: null);
      expect(r.nivel, Nivel.normal);
      expect(r.motivo, contains('72 h indisponível'));
    });

    test('tabela de limiares bate com o documento', () {
      expect(limiaresChuva[Nivel.atencao]!.mm24, 30);
      expect(limiaresChuva[Nivel.atencao]!.mm48, 50);
      expect(limiaresChuva[Nivel.atencao]!.mm72, 60);
      expect(limiaresChuva[Nivel.alerta]!.mm24, 50);
      expect(limiaresChuva[Nivel.alerta]!.mm48, 70);
      expect(limiaresChuva[Nivel.alerta]!.mm72, 90);
      expect(limiaresChuva[Nivel.critico]!.mm24, 80);
      expect(limiaresChuva[Nivel.critico]!.mm48, 100);
      expect(limiaresChuva[Nivel.critico]!.mm72, 120);
    });
  });
}
