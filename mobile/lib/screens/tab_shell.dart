import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'task_selection_screen.dart';
import 'profile_tab_screen.dart';

/// Post-login shell: 3-tab layout.
///
/// We render only the active tab so that state is rebuilt and fresh data is
/// fetched from the backend whenever the user switches tabs.
///
/// Individual tabs call [TabShell.of(context).switchTab(i)] to change the
/// selected tab (e.g., Home tapping "Explore" jumps to Request tab).
class TabShell extends StatefulWidget {
  static const routeName = '/shell';
  const TabShell({super.key});

  @override
  State<TabShell> createState() => TabShellState();

  /// Look up the nearest [TabShellState] from any descendant widget.
  static TabShellState of(BuildContext context) {
    final state = context.findAncestorStateOfType<TabShellState>();
    assert(state != null, 'TabShell.of() called outside a TabShell');
    return state!;
  }
}

class TabShellState extends State<TabShell> {
  int _currentIndex = 0;

  /// Switch to a tab by index (0=Home, 1=Request, 2=Profile).
  void switchTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    Widget currentTab;
    switch (_currentIndex) {
      case 0:
        currentTab = const HomeTabScreen();
        break;
      case 1:
        currentTab = const TaskSelectionScreen(preloadSelection: true);
        break;
      case 2:
      default:
        currentTab = const ProfileTabScreen();
        break;
    }

    return Scaffold(
      body: currentTab,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: switchTab,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Request',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
