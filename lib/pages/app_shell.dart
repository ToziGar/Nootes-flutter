import 'package:flutter/material.dart';
import '../notes/workspace_page.dart';
import '../profile/settings_page.dart';
import '../theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with AutomaticKeepAliveClientMixin {
  int _index = 0;
  late final PageController _pageController;

  final _pages = const [
    NotesWorkspacePage(),
    SettingsPage(),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_index != index) {
      setState(() => _index = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isCompact = MediaQuery.of(context).size.width < 800;
    final destinations = const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Workspace'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
    ];

    if (isCompact) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x1A4C6EF5), // primary 10%
                Color(0x1A2FD6C6), // secondary 10%
                Color(0x0DFF8A65), // accent 5%
              ],
            ),
          ),
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (_index != index) {
                setState(() => _index = index);
              }
            },
            children: _pages,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: destinations,
          onDestinationSelected: _onDestinationSelected,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: AppColors.space16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppColors.space8),
                padding: const EdgeInsets.all(AppColors.space8),
                decoration: BoxDecoration(
                  gradient: AppTheme.gradientPrimary,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: const Icon(Icons.note_alt_rounded, color: Colors.white),
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Workspace')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Ajustes')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x1A4C6EF5),
                    Color(0x1A2FD6C6),
                    Color(0x0DFF8A65),
                  ],
                ),
              ),
              child: _pages[_index],
            ),
          ),
        ],
      ),
    );
  }
}
