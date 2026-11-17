import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiClient.get('/notifications');
    if (res.statusCode == 200) {
      setState(() => _notifications = jsonDecode(res.body)['notifications'] ?? []);
    }
    setState(() => _loading = false);
  }

  Future<void> _readAll() async {
    await ApiClient.put('/notifications/read-all', {});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(onPressed: _readAll, child: const Text('Đọc tất cả')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(child: Text('Không có thông báo nào'))
          : ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final n = _notifications[index];
          final isRead = n['isRead'] == true;
          return ListTile(
            tileColor: isRead ? null : Colors.indigo.withOpacity(0.08),
            leading: Icon(
              isRead ? Icons.notifications_none : Icons.notifications_active,
              color: isRead ? Colors.grey : Colors.indigo,
            ),
            title: Text(n['title'], style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
            subtitle: Text('${n['message']}\n${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(n['createdAt']).toLocal())}'),
            isThreeLine: true,
            onTap: () async {
              if (!isRead) {
                await ApiClient.put('/notifications/${n['_id']}/read', {});
                _load();
              }
            },
          );
        },
      ),
    );
  }
}