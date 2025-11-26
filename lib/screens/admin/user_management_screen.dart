import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_role.dart';
import '../../core/utils/greenhouse_setup_helper.dart';
import '../auth/user_profile_repository.dart';

/// Provider untuk list semua users
final allUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return UserProfile(
        id: doc.id,
        email: data['email'] as String? ?? '',
        name: data['name'] as String? ?? 'Pengguna',
        phoneNumber: data['phoneNumber'] as String?,
        photoUrl: data['photoUrl'] as String?,
        role: UserRole.fromString(data['role'] as String?),
        currentGreenhouseId: data['currentGreenhouseId'] as String?,
      );
    }).toList();
  });
});

/// Provider untuk list semua devices
final allDevicesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('devices')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  });
});

/// Screen untuk Admin mengelola users dan assign ke greenhouse
class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final devicesAsync = ref.watch(allDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
        centerTitle: true,
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          final devices = devicesAsync.valueOrNull ?? [];
          
          if (users.isEmpty) {
            return const Center(
              child: Text('Belum ada pengguna terdaftar'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _UserCard(
                user: user,
                devices: devices,
              );
            },
          );
        },
      ),
    );
  }
}

class _UserCard extends ConsumerStatefulWidget {
  const _UserCard({
    required this.user,
    required this.devices,
  });

  final UserProfile user;
  final List<Map<String, dynamic>> devices;

  @override
  ConsumerState<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<_UserCard> {
  bool _isExpanded = false;
  bool _isLoading = false;
  List<String> _userMemberships = [];

  @override
  void initState() {
    super.initState();
    _loadMemberships();
  }

  Future<void> _loadMemberships() async {
    final helper = GreenhouseSetupHelper();
    final memberships = await helper.getUserMemberships(widget.user.id);
    if (mounted) {
      setState(() {
        _userMemberships = memberships
            .map((m) => m['greenhouseId'] as String)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = widget.user;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // User header
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(user.role).withAlpha((255 * 0.2).round()),
              child: Text(
                user.name.isNotEmpty
                    ? user.name[0].toUpperCase() 
                    : user.email[0].toUpperCase(),
                style: TextStyle(
                  color: _getRoleColor(user.role),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user.name.isNotEmpty ? user.name : 'Pengguna',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                const SizedBox(height: 4),
                _RoleBadge(role: user.role),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),
          
          // Expanded section
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role selector
                  Text(
                    'Ubah Role',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<UserRole>(
                    segments: UserRole.values.map((role) {
                      return ButtonSegment(
                        value: role,
                        label: Text(role.label),
                        icon: Icon(_getRoleIcon(role), size: 18),
                      );
                    }).toList(),
                    selected: {user.role},
                    onSelectionChanged: _isLoading 
                        ? null 
                        : (selection) => _changeRole(selection.first),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Greenhouse assignment
                  Text(
                    'Assign Greenhouse',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (widget.devices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Belum ada device. Sync dari RTDB dulu.'),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.devices.map((device) {
                        final deviceId = device['id'] as String;
                        final deviceName = device['name'] as String? ?? deviceId;
                        final isAssigned = _userMemberships.contains(deviceId);
                        
                        return FilterChip(
                          label: Text(deviceName),
                          selected: isAssigned,
                          onSelected: _isLoading 
                              ? null 
                              : (selected) => _toggleAssignment(deviceId, selected),
                          avatar: Icon(
                            isAssigned ? Icons.check : Icons.add,
                            size: 16,
                          ),
                        );
                      }).toList(),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _assignAllDevices,
                          icon: const Icon(Icons.select_all, size: 18),
                          label: const Text('Assign Semua'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _removeAllAssignments,
                          icon: const Icon(Icons.deselect, size: 18),
                          label: const Text('Hapus Semua'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changeRole(UserRole newRole) async {
    setState(() => _isLoading = true);
    try {
      final helper = GreenhouseSetupHelper();
      switch (newRole) {
        case UserRole.admin:
          await helper.setUserAsAdmin(widget.user.id);
          break;
        case UserRole.owner:
          await helper.setUserAsOwner(widget.user.id);
          break;
        case UserRole.petani:
          await helper.setUserAsPetani(widget.user.id);
          break;
      }
      _showSnackBar('Role berhasil diubah ke ${newRole.label}');
    } catch (e) {
      _showSnackBar('Gagal mengubah role: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAssignment(String deviceId, bool assign) async {
    setState(() => _isLoading = true);
    try {
      final helper = GreenhouseSetupHelper();
      if (assign) {
        await helper.assignUserToGreenhouse(
          userId: widget.user.id,
          greenhouseId: deviceId,
          role: widget.user.role,
        );
        _userMemberships.add(deviceId);
      } else {
        await helper.removeUserFromGreenhouse(
          userId: widget.user.id,
          greenhouseId: deviceId,
        );
        _userMemberships.remove(deviceId);
      }
      _showSnackBar(assign ? 'Berhasil di-assign' : 'Assignment dihapus');
    } catch (e) {
      _showSnackBar('Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignAllDevices() async {
    setState(() => _isLoading = true);
    try {
      final helper = GreenhouseSetupHelper();
      for (final device in widget.devices) {
        final deviceId = device['id'] as String;
        if (!_userMemberships.contains(deviceId)) {
          await helper.assignUserToGreenhouse(
            userId: widget.user.id,
            greenhouseId: deviceId,
            role: widget.user.role,
          );
        }
      }
      await _loadMemberships();
      _showSnackBar('Semua device berhasil di-assign');
    } catch (e) {
      _showSnackBar('Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeAllAssignments() async {
    setState(() => _isLoading = true);
    try {
      final helper = GreenhouseSetupHelper();
      for (final deviceId in List.from(_userMemberships)) {
        await helper.removeUserFromGreenhouse(
          userId: widget.user.id,
          greenhouseId: deviceId,
        );
      }
      await _loadMemberships();
      _showSnackBar('Semua assignment dihapus');
    } catch (e) {
      _showSnackBar('Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError 
            ? Theme.of(context).colorScheme.error 
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.owner:
        return Colors.blue;
      case UserRole.petani:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.owner:
        return Icons.business;
      case UserRole.petani:
        return Icons.agriculture;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = _getRoleColor(role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.15).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getRoleIcon(role), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            role.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.owner:
        return Colors.blue;
      case UserRole.petani:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.owner:
        return Icons.business;
      case UserRole.petani:
        return Icons.agriculture;
    }
  }
}
