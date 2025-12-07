import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/notification_service.dart';

/// Detailed notification settings screen
/// Allows farmers to toggle individual notification types
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // SharedPreferences keys for individual notification types
  static const String _keyMasterNotification = 'master_notification_enabled';
  static const String _keyTempAnomaly = 'notif_temp';
  static const String _keyHumidityAnomaly = 'notif_humidity';
  static const String _keyMoistureAnomaly = 'notif_moisture';
  static const String _keyWatering = 'notif_watering';
  static const String _keyPhaseChange = 'notif_phase';
  
  // Notification states
  bool _masterEnabled = true;
  bool _tempEnabled = true;
  bool _humidityEnabled = true;
  bool _moistureEnabled = true;
  bool _wateringEnabled = true;
  bool _phaseChangeEnabled = true;
  
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }
  
  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _masterEnabled = prefs.getBool(_keyMasterNotification) ?? true;
      _tempEnabled = prefs.getBool(_keyTempAnomaly) ?? true;
      _humidityEnabled = prefs.getBool(_keyHumidityAnomaly) ?? true;
      _moistureEnabled = prefs.getBool(_keyMoistureAnomaly) ?? true;
      _wateringEnabled = prefs.getBool(_keyWatering) ?? true;
      _phaseChangeEnabled = prefs.getBool(_keyPhaseChange) ?? true;
      _isLoading = false;
    });
  }
  
  Future<void> _toggleMaster(bool value) async {
    // Check permission if enabling
    if (value) {
      final notificationService = NotificationService();
      final hasPermission = await notificationService.requestPermission();
      if (!hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin notifikasi diperlukan. Aktifkan di pengaturan perangkat.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMasterNotification, value);
    setState(() {
      _masterEnabled = value;
    });
  }
  
  Future<void> _toggleNotificationType(String key, bool value, Function(bool) updateState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      updateState(value);
    });
  }
  
  int get _activeNotificationCount {
    if (!_masterEnabled) return 0;
    int count = 0;
    if (_tempEnabled) count++;
    if (_humidityEnabled) count++;
    if (_moistureEnabled) count++;
    if (_wateringEnabled) count++;
    if (_phaseChangeEnabled) count++;
    return count;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pengaturan Notifikasi'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Notifikasi'),
        backgroundColor: isDark ? null : const Color(0xFFE57373),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // Master Toggle Section
          _buildSection(
            title: 'Notifikasi Utama',
            children: [
              SwitchListTile(
                title: const Text(
                  'Aktifkan Semua Notifikasi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _masterEnabled 
                      ? '$_activeNotificationCount dari 5 notifikasi aktif'
                      : 'Semua notifikasi dinonaktifkan',
                ),
                value: _masterEnabled,
                onChanged: _toggleMaster,
                secondary: Icon(
                  _masterEnabled ? Icons.notifications_active : Icons.notifications_off,
                  color: _masterEnabled ? const Color(0xFF26A69A) : Colors.grey,
                ),
              ),
            ],
          ),
          
          const Divider(height: 32),
          
          // Individual Notification Types Section
          _buildSection(
            title: 'Jenis Notifikasi',
            subtitle: 'Pilih notifikasi yang ingin Anda terima',
            children: [
              _buildNotificationTile(
                title: 'Suhu Tidak Normal',
                subtitle: 'Notifikasi saat suhu di luar rentang ideal',
                icon: Icons.thermostat,
                enabled: _tempEnabled && _masterEnabled,
                value: _tempEnabled,
                onChanged: _masterEnabled 
                    ? (value) => _toggleNotificationType(_keyTempAnomaly, value, (v) => _tempEnabled = v)
                    : null,
              ),
              _buildNotificationTile(
                title: 'Kelembaban Udara Tidak Normal',
                subtitle: 'Notifikasi saat kelembaban udara tidak sesuai',
                icon: Icons.water_drop,
                enabled: _humidityEnabled && _masterEnabled,
                value: _humidityEnabled,
                onChanged: _masterEnabled 
                    ? (value) => _toggleNotificationType(_keyHumidityAnomaly, value, (v) => _humidityEnabled = v)
                    : null,
              ),
              _buildNotificationTile(
                title: 'Kelembaban Tanah Tidak Normal',
                subtitle: 'Notifikasi saat kelembaban tanah tidak optimal',
                icon: Icons.grass,
                enabled: _moistureEnabled && _masterEnabled,
                value: _moistureEnabled,
                onChanged: _masterEnabled 
                    ? (value) => _toggleNotificationType(_keyMoistureAnomaly, value, (v) => _moistureEnabled = v)
                    : null,
              ),
              _buildNotificationTile(
                title: 'Penyiraman',
                subtitle: 'Notifikasi saat pompa mulai menyiram',
                icon: Icons.water,
                enabled: _wateringEnabled && _masterEnabled,
                value: _wateringEnabled,
                onChanged: _masterEnabled 
                    ? (value) => _toggleNotificationType(_keyWatering, value, (v) => _wateringEnabled = v)
                    : null,
              ),
              _buildNotificationTile(
                title: 'Perubahan Fase Pertumbuhan',
                subtitle: 'Notifikasi saat tanaman memasuki fase baru',
                icon: Icons.timeline,
                enabled: _phaseChangeEnabled && _masterEnabled,
                value: _phaseChangeEnabled,
                onChanged: _masterEnabled 
                    ? (value) => _toggleNotificationType(_keyPhaseChange, value, (v) => _phaseChangeEnabled = v)
                    : null,
              ),
            ],
          ),
          
          // Info Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notifikasi akan muncul sesuai dengan pengaturan yang Anda pilih. '
                        'Pastikan notifikasi utama diaktifkan untuk menerima notifikasi.',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 13,
                        ),
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
  }
  
  Widget _buildSection({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE57373),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        ...children,
      ],
    );
  }
  
  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool enabled,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
      secondary: Icon(
        icon,
        color: enabled ? const Color(0xFF26A69A) : Colors.grey,
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
