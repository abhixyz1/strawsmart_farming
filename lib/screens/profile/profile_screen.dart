import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_role.dart';
import '../../core/utils/greenhouse_setup_helper.dart';
import '../auth/auth_controller.dart';
import '../auth/user_profile_repository.dart';
import '../admin/user_management_screen.dart';
import 'profile_controller.dart';
import '../../core/providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      data: (profile) => _SettingsView(profile: profile),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat pengaturan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsView extends ConsumerWidget {
  const _SettingsView({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AccountHeader(profile: profile),
              const SizedBox(height: 16),
              // Role badge
              _UserRoleBadge(profile: profile),
              const SizedBox(height: 24),
              if (isWide)
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _PreferencesSection()),
                    SizedBox(width: 16),
                    Expanded(child: _SecuritySection()),
                  ],
                )
              else
                const Column(
                  children: [
                    _PreferencesSection(),
                    SizedBox(height: 16),
                    _SecuritySection(),
                  ],
                ),
              const SizedBox(height: 16),
              // Development section for setup
              const _DevelopmentSection(),
              const SizedBox(height: 32),
              _LogoutButton(onLogout: () {
                ref.read(authControllerProvider.notifier).signOut();
              }),
            ],
          ),
        );
      },
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'avatar',
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.surface,
              backgroundImage: profile?.photoUrl?.isNotEmpty == true
                  ? NetworkImage(profile!.photoUrl!)
                  : null,
              child: profile?.photoUrl?.isEmpty != false
                  ? Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name ?? 'Grower',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                ),
                if (profile?.phoneNumber?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile!.phoneNumber!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () => _showEditProfileDialog(context, profile),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit Profil'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(profile: profile),
    );
  }
}

class _PreferencesSection extends ConsumerStatefulWidget {
  const _PreferencesSection();

  @override
  ConsumerState<_PreferencesSection> createState() => _PreferencesSectionState();
}

class _PreferencesSectionState extends ConsumerState<_PreferencesSection> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    
    return _SettingsCard(
      title: 'Preferensi',
      icon: Icons.tune_outlined,
      children: [
        _SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Notifikasi',
          subtitle: _notificationsEnabled ? 'Aktif' : 'Nonaktif',
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
            },
          ),
        ),
        _SettingsTile(
          icon: Icons.dark_mode_outlined,
          title: 'Mode Gelap',
          subtitle: isDarkMode ? 'Aktif' : 'Nonaktif',
          trailing: Switch(
            value: isDarkMode,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).toggleDarkMode();
            },
          ),
        ),
      ],
    );
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Keamanan',
      icon: Icons.security_outlined,
      children: [
        _SettingsTile(
          icon: Icons.lock_outline,
          title: 'Ubah Kata Sandi',
          subtitle: 'Segera hadir',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fitur segera tersedia')),
            );
          },
        ),
        _SettingsTile(
          icon: Icons.fingerprint,
          title: 'Autentikasi Biometrik',
          subtitle: 'Segera hadir',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fitur segera tersedia')),
            );
          },
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keluar'),
            content: const Text('Apakah Anda yakin ingin keluar?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  onLogout();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.logout),
      label: const Text('Keluar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile? profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _imagePicker = ImagePicker();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _emailController = TextEditingController(text: widget.profile?.email ?? '');
    _phoneController = TextEditingController(text: widget.profile?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Foto Profil'),
        content: const Text('Yakin ingin menghapus foto profil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.profile != null) {
      setState(() {
        _selectedImage = null;
      });
      
      await ref.read(profileControllerProvider.notifier).deleteProfilePhoto(widget.profile!);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final profile = UserProfile(
      id: widget.profile?.id ?? '',
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      photoUrl: widget.profile?.photoUrl,
      createdAt: widget.profile?.createdAt,
      updatedAt: widget.profile?.updatedAt,
    );

    await ref.read(profileControllerProvider.notifier).updateProfile(
      profile,
      newPhoto: _selectedImage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(profileControllerProvider);

    ref.listen<AsyncValue<void>>(profileControllerProvider, (previous, next) {
      next.when(
        data: (_) {
          if (previous?.isLoading == true) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil berhasil diperbarui'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        loading: () {},
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Profil',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Profile Photo Picker
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundImage: _selectedImage != null
                                        ? FileImage(_selectedImage!) as ImageProvider
                                        : (widget.profile?.photoUrl != null
                                            ? NetworkImage(widget.profile!.photoUrl!)
                                            : null),
                                    child: (_selectedImage == null && widget.profile?.photoUrl == null)
                                        ? Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      child: IconButton(
                                        onPressed: _pickImage,
                                        icon: const Icon(
                                          Icons.camera_alt,
                                          size: 20,
                                        ),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        tooltip: 'Pilih Foto',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap ikon kamera untuk mengubah foto',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (widget.profile?.photoUrl != null || _selectedImage != null) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: controllerState.isLoading ? null : _removePhoto,
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text('Hapus Foto'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama wajib diisi';
                            }
                            if (value.trim().length < 2) {
                              return 'Nama minimal 2 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                            enabled: false,
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Telepon (opsional)',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                            hintText: '08123456789',
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              if (value.trim().length < 10) {
                                return 'Minimal 10 digit';
                              }
                              if (value.trim().length > 15) {
                                return 'Maksimal 15 digit';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: controllerState.isLoading ? null : _handleSave,
                          icon: controllerState.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(controllerState.isLoading ? 'Menyimpan...' : 'Simpan'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== USER ROLE BADGE ====================

class _UserRoleBadge extends StatelessWidget {
  const _UserRoleBadge({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    if (profile == null) return const SizedBox.shrink();

    final role = profile!.role;
    final Color badgeColor;
    final IconData badgeIcon;

    switch (role) {
      case UserRole.admin:
        badgeColor = Colors.purple;
        badgeIcon = Icons.admin_panel_settings;
        break;
      case UserRole.owner:
        badgeColor = Colors.blue;
        badgeIcon = Icons.business;
        break;
      case UserRole.petani:
        badgeColor = Colors.green;
        badgeIcon = Icons.agriculture;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(badgeIcon, color: badgeColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Role: ${role.label}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  _getRoleDescription(role),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDescription(UserRole role) {
    // Gunakan deskripsi dari model UserRole
    return role.description;
  }
}

// ==================== DEVELOPMENT SECTION ====================

class _DevelopmentSection extends ConsumerStatefulWidget {
  const _DevelopmentSection();

  @override
  ConsumerState<_DevelopmentSection> createState() => _DevelopmentSectionState();
}

class _DevelopmentSectionState extends ConsumerState<_DevelopmentSection> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Hanya tampilkan di debug mode DAN hanya untuk Admin
    if (!kDebugMode) return const SizedBox.shrink();
    
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    if (profile == null) return const SizedBox.shrink();
    
    // Hanya Admin yang bisa akses Development Tools
    if (!profile.role.canAccessDevTools) return const SizedBox.shrink();

    return _SettingsCard(
      title: 'Development Tools',
      icon: Icons.developer_mode,
      children: [
        // User Management UI
        _SettingsTile(
          icon: Icons.people,
          title: 'Kelola Pengguna',
          subtitle: 'Assign user ke greenhouse & ubah role',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const UserManagementScreen(),
            ),
          ),
        ),
        const Divider(height: 16),
        _SettingsTile(
          icon: Icons.sync,
          title: 'Sync Devices dari RTDB',
          subtitle: 'Buat data devices di Firestore',
          trailing: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _isLoading ? null : _syncGreenhouses,
        ),
        _SettingsTile(
          icon: Icons.add_business,
          title: 'Setup Data Development',
          subtitle: 'Assign user ke semua devices',
          onTap: _isLoading ? null : _setupDevelopmentData,
        ),
        _SettingsTile(
          icon: Icons.group_add,
          title: 'Assign Semua Device ke Saya',
          subtitle: 'Tambahkan semua devices ke membership saya',
          onTap: _isLoading ? null : _assignAllDevicesToMe,
        ),
        const Divider(height: 16),
        _SettingsTile(
          icon: Icons.admin_panel_settings,
          title: 'Set Sebagai Admin',
          subtitle: 'Ubah role menjadi admin',
          onTap: _isLoading ? null : () => _setRole(UserRole.admin),
        ),
        _SettingsTile(
          icon: Icons.business,
          title: 'Set Sebagai Owner',
          subtitle: 'Ubah role menjadi owner',
          onTap: _isLoading ? null : () => _setRole(UserRole.owner),
        ),
        _SettingsTile(
          icon: Icons.agriculture,
          title: 'Set Sebagai Petani',
          subtitle: 'Ubah role menjadi petani',
          onTap: _isLoading ? null : () => _setRole(UserRole.petani),
        ),
        const Divider(height: 16),
        _SettingsTile(
          icon: Icons.delete_sweep,
          title: 'Clear Memberships Saya',
          subtitle: 'Hapus semua membership (untuk testing)',
          onTap: _isLoading ? null : _clearMyMemberships,
        ),
      ],
    );
  }

  Future<void> _syncGreenhouses() async {
    setState(() => _isLoading = true);
    try {
      final helper = GreenhouseSetupHelper();
      final ids = await helper.syncGreenhousesFromRTDB();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced ${ids.length} devices')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setupDevelopmentData() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;

    setState(() => _isLoading = true);
    try {
      final helper = GreenhouseSetupHelper();
      await helper.setupDevelopmentData(profile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Development data setup complete!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignAllDevicesToMe() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;

    setState(() => _isLoading = true);
    try {
      final helper = GreenhouseSetupHelper();
      
      // Sync dulu dari RTDB
      await helper.syncGreenhousesFromRTDB();
      
      // Get semua devices
      final devices = await helper.getAllDevices();
      
      // Assign ke user dengan role sesuai profile
      for (final device in devices) {
        try {
          await helper.assignUserToGreenhouse(
            userId: profile.id,
            greenhouseId: device['id'] as String,
            role: profile.role,
          );
        } catch (e) {
          debugPrint('Error assigning device ${device['id']}: $e');
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assigned ${devices.length} devices ke akun Anda')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearMyMemberships() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;

    // Konfirmasi dulu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Memberships?'),
        content: const Text('Ini akan menghapus semua akses Anda ke greenhouse. Anda harus meminta admin untuk menambahkan kembali.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final helper = GreenhouseSetupHelper();
      final memberships = await helper.getUserMemberships(profile.id);
      
      for (final membership in memberships) {
        await helper.removeUserFromGreenhouse(
          userId: profile.id,
          greenhouseId: membership['greenhouseId'] as String,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared ${memberships.length} memberships')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setRole(UserRole role) async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;

    setState(() => _isLoading = true);
    try {
      final helper = GreenhouseSetupHelper();
      switch (role) {
        case UserRole.admin:
          await helper.setUserAsAdmin(profile.id);
          break;
        case UserRole.owner:
          await helper.setUserAsOwner(profile.id);
          break;
        case UserRole.petani:
          await helper.setUserAsPetani(profile.id);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role diubah menjadi ${role.label}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
