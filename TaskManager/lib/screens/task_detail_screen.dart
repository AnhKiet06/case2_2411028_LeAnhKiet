import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? _task;
  String _myRole = 'viewer';
  List<dynamic> _shares = [];
  List<dynamic> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    final res = await ApiClient.get('/tasks/${widget.taskId}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _task = data['task'];
        _myRole = data['myRole'];
        _shares = data['shares'] ?? [];
        _activities = data['activities'] ?? [];
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _showShareDialog() async {
    final emailCtrl = TextEditingController();
    String role = 'editor';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Chia sẻ công việc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email người nhận'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Phân quyền'),
                items: const [
                  DropdownMenuItem(value: 'editor', child: Text('Editor (Được sửa)')),
                  DropdownMenuItem(value: 'viewer', child: Text('Viewer (Chỉ xem)')),
                ],
                onChanged: (v) => setDialogState(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final res = await ApiClient.post('/tasks/${widget.taskId}/share', {
                  'email': emailCtrl.text.trim(),
                  'role': role,
                });
                if (!mounted) return;
                Navigator.pop(ctx);
                final msg = jsonDecode(res.body)['message'] ?? '';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                _loadDetail();
              },
              child: const Text('Chia sẻ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignDialog() async {
    final emailCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Giao việc cho thành viên'),
        content: TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(labelText: 'Email người được giao'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final res = await ApiClient.put('/tasks/${widget.taskId}/assign', {
                'email': emailCtrl.text.trim(),
              });
              if (!mounted) return;
              Navigator.pop(ctx);
              final msg = jsonDecode(res.body)['message'] ?? '';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              _loadDetail();
            },
            child: const Text('Giao việc'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask() async {
    final res = await ApiClient.delete('/tasks/${widget.taskId}');
    if (res.statusCode == 200 && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_task == null) return const Scaffold(body: Center(child: Text('Không tìm thấy công việc')));

    final canEdit = _myRole == 'owner' || _myRole == 'editor';
    final isOwner = _myRole == 'owner';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskFormScreen(existingTask: _task)));
                _loadDetail();
              },
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteTask,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_task!['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Quyền của bạn: $_myRole')),
              Chip(label: Text('Trạng thái: ${_task!['status']}')),
              Chip(label: Text('Ưu tiên: ${_task!['priority']}')),
            ],
          ),
          const SizedBox(height: 12),
          Text(_task!['description']?.isNotEmpty == true ? _task!['description'] : 'Không có mô tả'),
          const Divider(height: 32),
          Text('Chủ sở hữu: ${_task!['ownerId']['fullName']} (${_task!['ownerId']['email']})'),
          const SizedBox(height: 6),
          Text('Người được giao: ${_task!['assignedTo'] != null ? "${_task!['assignedTo']['fullName']} (${_task!['assignedTo']['email']})" : "Chưa giao"}'),
          if (isOwner) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Chia sẻ'),
                    onPressed: _showShareDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.assignment_ind),
                    label: const Text('Giao việc'),
                    onPressed: _showAssignDialog,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 32),
          const Text('Thành viên tham gia:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ..._shares.map((s) => ListTile(
            dense: true,
            title: Text(s['userId']['fullName']),
            subtitle: Text('${s['userId']['email']} • Quyền: ${s['role']}'),
            trailing: (isOwner && s['role'] != 'owner')
                ? IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () async {
                await ApiClient.delete('/tasks/${widget.taskId}/share/${s['userId']['_id']}');
                _loadDetail();
              },
            )
                : null,
          )),
          const Divider(height: 32),
          const Text('Lịch sử hoạt động:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ..._activities.map((a) => ListTile(
            dense: true,
            leading: const Icon(Icons.history, size: 18),
            title: Text(a['action']),
            subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(a['createdAt']).toLocal())),
          )),
        ],
      ),
    );
  }
}