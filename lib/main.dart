import 'package:flutter/material.dart';

import 'screens/avisos_screen.dart';
import 'screens/estacoes_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/sobre_screen.dart';
import 'state/monitoramento_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = MonitoramentoController()..iniciar();
  runApp(HidroValesApp(controller: controller));
}

class HidroValesApp extends StatelessWidget {
  const HidroValesApp({super.key, required this.controller});

  final MonitoramentoController controller;

  @override
  Widget build(BuildContext context) {
    const semente = Color(0xFF1565C0);
    return MonitoramentoScope(
      controller: controller,
      child: MaterialApp(
        title: 'Hidro Vales',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: semente),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: semente,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const TelaPrincipal(),
      ),
    );
  }
}

/// Navegação inferior com as quatro áreas do app.
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _aba = 0;
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    // Para de consultar a API com o app em segundo plano.
    _ciclo = AppLifecycleListener(
      onPause: () => MonitoramentoScope.read(context).pausar(),
      onResume: () => MonitoramentoScope.read(context).retomar(),
    );
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  void irPara(int aba) => setState(() => _aba = aba);

  @override
  Widget build(BuildContext context) {
    final controller = MonitoramentoScope.of(context);
    final naoLidos = controller.avisosNaoLidos;

    final telas = [
      InicioScreen(aoVerTodas: () => irPara(1), aoVerAvisos: () => irPara(2)),
      const EstacoesScreen(),
      const AvisosScreen(),
      const SobreScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _aba, children: telas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) {
          // Ao sair da aba Avisos, os avisos vistos deixam de ser "novos".
          if (_aba == 2 && i != 2) controller.marcarAvisosComoLidos();
          irPara(i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          const NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Estações',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: naoLidos > 0,
              label: Text('$naoLidos'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Avisos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Sobre',
          ),
        ],
      ),
    );
  }
}
