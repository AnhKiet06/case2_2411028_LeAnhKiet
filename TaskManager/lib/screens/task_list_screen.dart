import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import 'task_form_screen.dart';
import 'task_detail_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<dynamic> _tasks = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String _filter = 'all';
  String _statusFilter = 'all';
  String _search = '';
  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final query = '?filter=$_filter&status=$_statusFilter&search=$_search';
      final resTasks = await ApiClient.get('/tasks$query');
      final resStats = await ApiClient.get('/statistics/overview');
      final resNotifs = await ApiClient.get('/notifications');

      if (resTasks.statusCode == 200) {
        _tasks = jsonDecode(resTasks.body);
      }
      if (resStats.statusCode == 200) {
        _stats = jsonDecode(resStats.body);
      }
      if (resNotifs.statusCode == 200) {
        _unreadNotifs = jsonDecode(resNotifs.body)['unreadCount'] ?? 0;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _priorityColor(String p) {
    if (p == 'high') return Colors.red;
    if (p == 'medium') return Colors.orange;
    return Colors.green;
  }

  String _statusLabel(String s) {
    if (s == 'done') return 'Hoàn thành';
    if (s == 'in_progress') return 'Đang làm';
    return 'Cần làm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý công việc'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                  _loadAll();
                },
              ),
              if (_unreadNotifs > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text('$_unreadNotifs', style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                )
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: Column(
          children: [
            // Thẻ thống kê tổng quan
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCard('Tổng', '${_stats['total'] ?? 0}', Colors.indigo),
                  _statCard('Đang làm', '${_stats['inProgress'] ?? 0}', Colors.orange),
                  _statCard('Xong', '${_stats['done'] ?? 0}', Colors.green),
                  _statCard('Quá hạn', '${_stats['overdue'] ?? 0}', Colors.red),
                ],
              ),
            ),
            // Thanh tìm kiếm
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm theo tiêu đề...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) {
                  _search = val;
                  _loadAll();
                },
              ),
            ),
            // Bộ lọc nhóm việc & trạng thái
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _filterChip('Tất cả', 'all'),
                  const SizedBox(width: 6),
                  _filterChip('Của tôi', 'my'),
                  const SizedBox(width: 6),
                  _filterChip('Được chia sẻ', 'shared'),
                  const SizedBox(width: 6),
                  _filterChip('Được giao', 'assigned'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _statusFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Mọi trạng thái')),
                      DropdownMenuItem(value: 'todo', child: Text('Cần làm')),
                      DropdownMenuItem(value: 'in_progress', child: Text('Đang làm')),
                      DropdownMenuItem(value: 'done', child: Text('Hoàn thành')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _statusFilter = val;
                        _loadAll();
                      }
                    },
                  ),
                ],
              ),
            ),
            // Danh sách công việc
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tasks.isEmpty
                  ? const Center(child: Text('Chưa có công việc nào'))
                  : ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final t = _tasks[index];
                  final due = t['dueDate'] != null
                      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(t['dueDate']))
                      : 'Không hạn';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _priorityColor(t['priority']),
                        child: Text(
                          t['myRole'].toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(t['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${_statusLabel(t['status'])} • Hạn: $due • Quyền: ${t['myRole']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t['_id'])),
                        );
                        _loadAll();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskFormScreen()));
          _loadAll();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _statCard(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) {
        setState(() => _filter = value);
        _loadAll();
      },
    );
  }
}