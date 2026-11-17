import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class TaskFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingTask;
  const TaskFormScreen({super.key, this.existingTask});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _catCtrl = TextEditingController(text: 'General');
  String _priority = 'medium';
  String _status = 'todo';
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      _titleCtrl.text = t['title'] ?? '';
      _descCtrl.text = t['description'] ?? '';
      _catCtrl.text = t['category'] ?? 'General';
      _priority = t['priority'] ?? 'medium';
      _status = t['status'] ?? 'todo';
      if (t['dueDate'] != null) _dueDate = DateTime.parse(t['dueDate']);
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final body = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'category': _catCtrl.text.trim(),
      'priority': _priority,
      'status': _status,
      'dueDate': _dueDate?.toIso8601String(),
    };

    try {
      final res = widget.existingTask == null
          ? await ApiClient.post('/tasks', body)
          : await ApiClient.put('/tasks/${widget.existingTask!['_id']}', body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Lỗi lưu công việc';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingTask != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Sửa công việc' : 'Tạo công việc mới')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Tiêu đề *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Mô tả chi tiết', border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _catCtrl,
            decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _priority,
            decoration: const InputDecoration(labelText: 'Mức ưu tiên', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Thấp (Low)')),
              DropdownMenuItem(value: 'medium', child: Text('Trung bình (Medium)')),
              DropdownMenuItem(value: 'high', child: Text('Cao (High)')),
            ],
            onChanged: (v) => setState(() => _priority = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Trạng thái', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'todo', child: Text('Cần làm (To do)')),
              DropdownMenuItem(value: 'in_progress', child: Text('Đang làm (In progress)')),
              DropdownMenuItem(value: 'done', child: Text('Hoàn thành (Done)')),
            ],
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text(_dueDate == null ? 'Chọn hạn chót' : 'Hạn chót: ${DateFormat('dd/MM/yyyy').format(_dueDate!)}'),
            trailing: const Icon(Icons.calendar_today),
            shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(6)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : const Text('Lưu công việc'),
            ),
          ),
        ],
      ),
    );
  }
}