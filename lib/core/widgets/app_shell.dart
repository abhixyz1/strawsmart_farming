import 'package:flutter/material.dart';

/// Responsive shell that switches between a NavigationRail (large screens)
/// and a Bottom NavigationBar (mobile).
/// Now with smooth page transition animations!
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.children,
    this.floatingActionButton,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> children; // Changed from single child to list
  final Widget? floatingActionButton;

  static const double _railBreakpoint = 900;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late PageController _pageController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.selectedIndex,
      keepPage: true,
    );
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No animation here - handled directly in onDestinationSelected for faster response
  }

  void _animateToPage(int index) {
    if (_isAnimating || !_pageController.hasClients) return;
    _isAnimating = true;
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200), // Faster animation
      curve: Curves.fastOutSlowIn, // More natural curve
    ).then((_) {
      if (mounted) {
        _isAnimating = false;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= AppShell._railBreakpoint;
        return Scaffold(
          floatingActionButton: widget.floatingActionButton,
          bottomNavigationBar:
              useRail ? null : _buildBottomNavigation(context),
          body: Row(
            children: [
              if (useRail) _buildNavigationRail(context),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    // Only callback if not already animating (prevents double calls)
                    if (!_isAnimating) {
                      widget.onIndexChanged(index);
                    }
                  },
                  physics: const ClampingScrollPhysics(), // Lighter physics
                  allowImplicitScrolling: true, // Pre-cache adjacent pages
                  children: widget.children,
                ),
              ),
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
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: (index) {
            // Immediately trigger animation without waiting for state rebuild
            if (index != widget.selectedIndex) {
              _animateToPage(index);
              widget.onIndexChanged(index);
            }
          },
          destinations: widget.destinations,
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 64,
          animationDuration: const Duration(milliseconds: 150), // Faster indicator animation
        ),
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final railDestinations = widget.destinations
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
        selectedIndex: widget.selectedIndex,
        labelType: NavigationRailLabelType.all,
        onDestinationSelected: widget.onIndexChanged,
        destinations: railDestinations,
      ),
    );
  }
}
