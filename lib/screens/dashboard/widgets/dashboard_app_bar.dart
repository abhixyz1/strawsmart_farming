import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/notification_repository.dart';
import '../../../core/services/notification_rtdb_repository.dart';
import '../../greenhouse/greenhouse_repository.dart';

/// App bar untuk dashboard dengan selector greenhouse
class DashboardAppBar extends ConsumerWidget {
  const DashboardAppBar({
    super.key,
    required this.title,
    this.isHomeTab = false,
  });

  final String title;
  final bool isHomeTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Untuk tab beranda, tampilkan header dengan background ilustrasi
    if (isHomeTab) {
      return _buildHomeHeader(context, ref, theme);
    }

    // Untuk tab Pengaturan, tampilkan header standar (tanpa greenhouse selector)
    if (title == 'Pengaturan') {
      return _buildSettingsHeader(context, theme);
    }

    // Untuk tab lain (Monitoring, Batch, Laporan) - tampilkan header konsisten
    return _buildOtherTabHeader(context, ref, theme);
  }

  /// Header dengan background ilustrasi untuk tab beranda
  Widget _buildHomeHeader(BuildContext context, WidgetRef ref, ThemeData theme) {
    final selected = ref.watch(selectedGreenhouseProvider);
    final shouldShowSelector = ref.watch(shouldShowGreenhouseSelectorProvider);
    final greenhouseName = selected?.displayName ?? 'StrawSmart';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withAlpha((255 * 0.08).round()),
            theme.colorScheme.tertiary.withAlpha((255 * 0.15).round()),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              // Ikon lokasi
              Icon(
                Icons.location_on,
                size: 22,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              // Nama greenhouse dengan dropdown icon
              Expanded(
                child: GestureDetector(
                  onTap: shouldShowSelector
                      ? () => _showGreenhouseSelector(context, ref)
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          greenhouseName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (shouldShowSelector) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Tombol notifikasi dengan badge
              _NotificationButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Header untuk tab Pengaturan - dengan notification icon, sama seperti tab lain
  Widget _buildSettingsHeader(BuildContext context, ThemeData theme) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withAlpha((255 * 0.12).round()),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            // Tombol notifikasi dengan badge
            const _NotificationButton(),
          ],
        ),
      ),
    );
  }

  /// Header konsisten untuk tab Monitoring, Batch, Laporan
  Widget _buildOtherTabHeader(BuildContext context, WidgetRef ref, ThemeData theme) {
    final selected = ref.watch(selectedGreenhouseProvider);
    final shouldShowSelector = ref.watch(shouldShowGreenhouseSelectorProvider);
    final greenhouseName = selected?.displayName ?? 'StrawSmart';

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withAlpha((255 * 0.12).round()),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Judul tab
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            // Greenhouse selector di kanan
            GestureDetector(
              onTap: shouldShowSelector
                  ? () => _showGreenhouseSelector(context, ref)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: Text(
                        greenhouseName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (shouldShowSelector) ...[
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Tombol notifikasi dengan badge di paling kanan
            const _NotificationButton(),
          ],
        ),
      ),
    );
  }

  void _showGreenhouseSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _GreenhouseSelectorSheet(),
    );
  }
}

/// Notification button widget with badge count
class _NotificationButton extends ConsumerWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadCountAsync = ref.watch(rtdbUnreadCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifikasi',
          icon: Icon(
            Icons.notifications_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            context.go('/notifications');
          },
        ),
        unreadCountAsync.when(
          data: (unreadCount) {
            if (unreadCount == 0) return const SizedBox.shrink();
            
            return Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Bottom sheet untuk memilih greenhouse
class _GreenhouseSelectorSheet extends ConsumerWidget {
  const _GreenhouseSelectorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final greenhousesAsync = ref.watch(availableGreenhousesProvider);
    final selected = ref.watch(selectedGreenhouseProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withAlpha((255 * 0.3).round()),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.eco,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Pilih Ladang',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Greenhouse list
          greenhousesAsync.when(
            data: (greenhouses) {
              if (greenhouses.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Tidak ada ladang tersedia',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: greenhouses.map((gh) {
                  final isSelected = gh.greenhouseId == selected?.greenhouseId;
                  return _GreenhouseListTile(
                    name: gh.displayName,
                    isSelected: isSelected,
                    onTap: () {
                      ref
                          .read(selectedGreenhouseIdProvider.notifier)
                          .selectGreenhouse(gh.greenhouseId);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Error: $e',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Tile untuk item greenhouse dalam bottom sheet
class _GreenhouseListTile extends StatelessWidget {
  const _GreenhouseListTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withAlpha((255 * 0.1).round())
            : theme.colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.eco,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
