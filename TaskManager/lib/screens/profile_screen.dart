import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  String _email = '';
  bool _emailNotif = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final res = await ApiClient.get('/auth/me');
    if (res.statusCode == 200) {
      final user = jsonDecode(res.body);
      setState(() {
        _nameCtrl.text = user['fullName'] ?? '';
        _email = user['email'] ?? '';
        _emailNotif = user['emailNotificationsEnabled'] ?? true;
        _loading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    final res = await ApiClient.put('/users/profile', {
      'fullName': _nameCtrl.text.trim(),
      'emailNotificationsEnabled': _emailNotif,
    });
    if (res.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật thông tin')));
    }
  }

  Future<void> _logout() async {
    await ApiClient.clearAuth();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ cá nhân')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Email: $_email', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Nhận thông báo qua Email'),
              value: _emailNotif,
              onChanged: (v) => setState(() => _emailNotif = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _updateProfile, child: const Text('Lưu thay đổi')),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                onPressed: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}