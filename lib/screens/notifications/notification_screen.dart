import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/notification_repository.dart';
import '../../core/services/notification_rtdb_repository.dart';
import '../greenhouse/greenhouse_repository.dart';
import '../../models/notification_item.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Halaman untuk menampilkan history notifikasi
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  String? _selectedDeviceFilter;
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    // Use the proper StreamProvider for RTDB notifications
    final notificationsAsync = ref.watch(rtdbNotificationsStreamProvider);
    final availableGreenhousesAsync = ref.watch(availableGreenhousesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (!didPop) {
          // Handle back button press
          context.go('/dashboard');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Kembali ke Dashboard',
          ),
          title: const Text('Notifikasi'),
        actions: [
          // Filter unread only
          IconButton(
            icon: Icon(
              _showUnreadOnly ? Icons.mark_email_read : Icons.filter_list,
            ),
            onPressed: () {
              setState(() {
                _showUnreadOnly = !_showUnreadOnly;
              });
            },
            tooltip: _showUnreadOnly ? 'Tampilkan semua' : 'Belum dibaca saja',
          ),
          // Mark all as read
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final repo = ref.read(notificationRtdbRepositoryProvider);
                await repo.markAllAsRead(user.uid);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Semua notifikasi ditandai sudah dibaca'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: 'Tandai semua sudah dibaca',
          ),
        ],
      ),
      body: availableGreenhousesAsync.when(
        data: (availableGreenhouses) {
          // Get device IDs dari greenhouse yang di-assign ke user
          final userDeviceIds = availableGreenhouses.map((g) => g.deviceId).toSet();

          return notificationsAsync.when(
            data: (allNotifications) {
              // Debug: Print notification count
              print('DEBUG: Total notifications from RTDB: ${allNotifications.length}');
              print('DEBUG: User device IDs: $userDeviceIds');
              
              // Filter notifikasi: hanya tampilkan dari greenhouse user
              final notifications = allNotifications
                  .where((n) => userDeviceIds.contains(n.deviceId))
                  .toList();
              
              print('DEBUG: Filtered notifications: ${notifications.length}');

              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada notifikasi',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Notifikasi dari greenhouse Anda akan muncul di sini',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Apply filters
              var filtered = notifications;
              if (_selectedDeviceFilter != null) {
                filtered = filtered.where((n) => n.deviceId == _selectedDeviceFilter).toList();
              }
              if (_showUnreadOnly) {
                filtered = filtered.where((n) => !n.isRead).toList();
              }

              // Group by date
              final grouped = <String, List<NotificationItem>>{};
              for (final notification in filtered) {
                final dateKey = DateFormat('yyyy-MM-dd').format(notification.timestamp);
                grouped.putIfAbsent(dateKey, () => []).add(notification);
              }

              final sortedDates = grouped.keys.toList()
                ..sort((a, b) => b.compareTo(a)); // Descending

              return Column(
                children: [
                  // Device filter chips
                  _buildDeviceFilterChips(notifications, theme, isDark),
                  
                  // Notification list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                    final dateKey = sortedDates[index];
                    final dateNotifications = grouped[dateKey]!;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _formatDateHeader(dateKey),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Notifications for this date
                        ...dateNotifications.map((notification) {
                          return _buildNotificationCard(
                            notification,
                            theme,
                            isDark,
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat notifikasi...'),
            ],
          ),
        ),
        error: (error, stackTrace) {
          print('DEBUG: Error loading notifications: $error');
          print('DEBUG: Stack trace: $stackTrace');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Gagal memuat notifikasi'),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Gagal memuat data greenhouse'),
        ),
      ),
      ),
    );
  }

  Widget _buildDeviceFilterChips(
    List<NotificationItem> notifications,
    ThemeData theme,
    bool isDark,
  ) {
    // Get unique devices
    final devices = notifications
        .map((n) => n.deviceName)
        .toSet()
        .toList()
      ..sort();

    if (devices.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // All devices chip
            FilterChip(
              label: const Text('Semua'),
              selected: _selectedDeviceFilter == null,
              onSelected: (selected) {
                setState(() {
                  _selectedDeviceFilter = null;
                });
              },
            ),
            const SizedBox(width: 8),
            
            // Individual device chips
            ...devices.map((deviceName) {
              final deviceId = notifications
                  .firstWhere((n) => n.deviceName == deviceName)
                  .deviceId;
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(deviceName),
                  selected: _selectedDeviceFilter == deviceId,
                  onSelected: (selected) {
                    setState(() {
                      _selectedDeviceFilter = selected ? deviceId : null;
                    });
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    NotificationItem notification,
    ThemeData theme,
    bool isDark,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    final repo = ref.read(notificationRtdbRepositoryProvider);
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        // Delete from RTDB first
        if (user != null) {
          try {
            await repo.deleteNotification(user.uid, notification.id);
            return true; // Allow dismiss
          } catch (e) {
            print('Error deleting notification: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gagal menghapus notifikasi'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            return false; // Cancel dismiss
          }
        }
        return false;
      },
      onDismissed: (_) {
        // Show snackbar after successful deletion
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifikasi dihapus'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: notification.isRead
            ? (isDark ? Colors.grey[850] : Colors.white)
            : (isDark ? Colors.grey[800] : Colors.blue[50]),
        child: InkWell(
          onTap: () async {
            if (!notification.isRead && user != null) {
              await repo.markAsRead(user.uid, notification.id);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: notification.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and device name
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (notification.isCritical)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PENTING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      // Message
                      Text(
                        notification.message,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      
                      // Time and device
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('HH:mm').format(notification.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.sensors,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              notification.deviceName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Unread indicator
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8, top: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hari Ini';
    } else if (dateOnly == yesterday) {
      return 'Kemarin';
    } else {
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
    }
  }
}
