import 'package:flutter/material.dart';

/// Responsive shell that switches between a NavigationRail (large screens)
/// and a Bottom NavigationBar (mobile).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.child,
    this.floatingActionButton,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget child;
  final Widget? floatingActionButton;

  static const double _railBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _railBreakpoint;
        return Scaffold(
          floatingActionButton: floatingActionButton,
          bottomNavigationBar:
              useRail ? null : _buildBottomNavigation(context),
          body: Row(
            children: [
              if (useRail) _buildNavigationRail(context),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onIndexChanged,
          destinations: destinations,
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 64,
        ),
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final railDestinations = destinations
        .map(
          (dest) => NavigationRailDestination(
            icon: dest.icon,
            selectedIcon: dest.selectedIcon ?? dest.icon,
            label: Text(dest.label),
          ),
        )
        .toList();

    return SafeArea(
      right: false,
      child: NavigationRail(
        selectedIndex: selectedIndex,
        labelType: NavigationRailLabelType.all,
        onDestinationSelected: onIndexChanged,
        destinations: railDestinations,
      ),
    );
  }
}
