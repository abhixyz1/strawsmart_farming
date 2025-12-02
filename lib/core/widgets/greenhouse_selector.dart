import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/greenhouse_membership.dart';
import '../../screens/greenhouse/greenhouse_repository.dart';

/// Widget dropdown untuk memilih greenhouse
/// Hanya ditampilkan untuk admin/owner dengan lebih dari 1 greenhouse
class GreenhouseSelector extends ConsumerWidget {
  const GreenhouseSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShow = ref.watch(shouldShowGreenhouseSelectorProvider);

    if (!shouldShow) {
      // Return compact display for single greenhouse
      return const _SingleGreenhouseDisplay();
    }

    return const _GreenhouseDropdown();
  }
}

/// Display untuk user dengan 1 greenhouse saja
class _SingleGreenhouseDisplay extends ConsumerWidget {
  const _SingleGreenhouseDisplay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGreenhouseProvider);

    if (selected == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.eco,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              selected.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown untuk memilih greenhouse
class _GreenhouseDropdown extends ConsumerWidget {
  const _GreenhouseDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableAsync = ref.watch(availableGreenhousesProvider);
    final selectedId = ref.watch(selectedGreenhouseIdProvider);

    return availableAsync.when(
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, _) => Text(
        'Error: $e',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (memberships) {
        if (memberships.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedId,
              hint: Text(
                'Pilih Greenhouse',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              borderRadius: BorderRadius.circular(12),
              items: memberships.map((m) => _buildDropdownItem(context, m)).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(selectedGreenhouseIdProvider.notifier).selectGreenhouse(value);
                }
              },
            ),
          ),
        );
      },
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(
    BuildContext context,
    GreenhouseMembership membership,
  ) {
    return DropdownMenuItem<String>(
      value: membership.greenhouseId,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.eco,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  membership.greenhouseName ?? 'Greenhouse',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (membership.greenhouseLocation != null)
                  Text(
                    membership.greenhouseLocation!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget untuk menampilkan state ketika user tidak punya akses ke greenhouse
class NoGreenhouseAccessWidget extends StatelessWidget {
  const NoGreenhouseAccessWidget({super.key, this.onRequestAccess});

  final VoidCallback? onRequestAccess;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.eco_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Akses Greenhouse',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Anda belum memiliki akses ke greenhouse manapun. '
              'Hubungi admin untuk mendapatkan akses.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRequestAccess != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRequestAccess,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Minta Akses'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget untuk menampilkan loading state greenhouse
class GreenhouseLoadingWidget extends StatelessWidget {
  const GreenhouseLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat data greenhouse...'),
        ],
      ),
    );
  }
}

/// Compact info bar yang menampilkan greenhouse aktif
class ActiveGreenhouseBar extends ConsumerWidget {
  const ActiveGreenhouseBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGreenhouseProvider);
    final accessState = ref.watch(greenhouseAccessStateProvider);

    if (accessState == GreenhouseAccessState.loading) {
      return const LinearProgressIndicator();
    }

    if (selected == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selected.displayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selected.deviceId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                selected.deviceId!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
