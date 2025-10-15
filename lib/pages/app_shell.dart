import 'package:flutter/material.dart';
import '../notes/workspace_page.dart';
import '../profile/settings_page.dart';
import '../notes/advanced_search_page.dart';
import '../notes/graph_page.dart';
import '../notes/tasks_page.dart';
import '../notes/export_page.dart';
import 'shared_notes_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();

  static AppShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<AppShellState>();
  }
}

class AppShellState extends State<AppShell> with AutomaticKeepAliveClientMixin {
  int _index = 0;
  late final PageController _pageController;

  // Orden de páginas y sus índices públicos
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    _pages = [
  KeepAliveWrapper(child: WorkspacePage()),
      KeepAliveWrapper(child: SettingsPage()),
      KeepAliveWrapper(child: AdvancedSearchPage()),
      KeepAliveWrapper(child: GraphPage()),
      KeepAliveWrapper(child: TasksPage()),
      KeepAliveWrapper(child: SharedNotesPage()),
      KeepAliveWrapper(child: ExportPage()),
    ];
  }

  // Expose navigation helpers for other pages
  void navigateToWorkspace() => _setIndex(0);
  void navigateToSettings() => _setIndex(1);
  void navigateToShared() => _setIndex(5);

  void _setIndex(int i) {
    if (!mounted) return;
    setState(() => _index = i);
    _pageController.jumpToPage(i);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _setIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Notas',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: 'Grafo',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.share_outlined),
            selectedIcon: Icon(Icons.share),
            label: 'Compartidas',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Exportar',
          ),
        ],
      ),
    );
  }
}

// Keep pages alive inside PageView
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
