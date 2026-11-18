import 'package:dados_hidrometeorologicos/domain/nivel.dart';
import 'package:dados_hidrometeorologicos/widgets/nivel_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NivelBadge mostra o rótulo do nível', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NivelBadge(
            resultado: ResultadoNivel(
              nivel: Nivel.alerta,
              rotulo: 'Alerta',
              motivo: 'teste',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Alerta'), findsOneWidget);
  });
}
