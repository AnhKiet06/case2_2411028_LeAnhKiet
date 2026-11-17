const express = require('express');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const User = require('../models/User');
const Notification = require('../models/Notification');
const TaskActivity = require('../models/TaskActivity');
const authMiddleware = require('../middleware/authMiddleware');
const { checkTaskPermission } = require('../middleware/permissionMiddleware');
const { sendNotificationEmail } = require('../services/emailService');

const router = express.Router();

router.get('/', authMiddleware, async (req, res) => {
  try {
    const { filter, status, priority, search, sortBy } = req.query;
    const shares = await TaskShare.find({ userId: req.user._id });
    const sharedTaskIds = shares.map(s => s.taskId);

    let query = {};
    if (filter === 'my') {
      query = { ownerId: req.user._id };
    } else if (filter === 'shared') {
      query = { _id: { $in: sharedTaskIds }, ownerId: { $ne: req.user._id } };
    } else if (filter === 'assigned') {
      query = { assignedTo: req.user._id };
    } else {
      query = { $or: [{ ownerId: req.user._id }, { _id: { $in: sharedTaskIds } }, { assignedTo: req.user._id }] };
    }

    if (status && status !== 'all') query.status = status;
    if (priority && priority !== 'all') query.priority = priority;
    if (search) query.title = { $regex: search, $options: 'i' };

    let sortOption = { createdAt: -1 };
    if (sortBy === 'dueDate') sortOption = { dueDate: 1 };
    if (sortBy === 'priority') sortOption = { priority: 1 };

    const tasks = await Task.find(query)
      .populate('ownerId', 'fullName email')
      .populate('assignedTo', 'fullName email')
      .sort(sortOption);

    const shareMap = {};
    shares.forEach(s => { shareMap[s.taskId.toString()] = s.role; });

    const result = tasks.map(t => {
      const obj = t.toObject();
      obj.myRole = t.ownerId._id.toString() === req.user._id.toString()
        ? 'owner'
        : (shareMap[t._id.toString()] || 'viewer');
      return obj;
    });

    res.json(result);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi lấy danh sách công việc', error: err.message });
  }
});

router.post('/', authMiddleware, async (req, res) => {
  try {
    const { title, description, dueDate, priority, status, category, assignedTo } = req.body;
    const task = await Task.create({
      title,
      description,
      dueDate: dueDate || null,
      priority: priority || 'medium',
      status: status || 'todo',
      category: category || 'General',
      ownerId: req.user._id,
      assignedTo: assignedTo || null
    });

    await TaskShare.create({
      taskId: task._id,
      userId: req.user._id,
      role: 'owner',
      sharedBy: req.user._id
    });

    await TaskActivity.create({
      taskId: task._id,
      userId: req.user._id,
      action: `${req.user.fullName} đã tạo công việc`
    });

    if (assignedTo && assignedTo !== req.user._id.toString()) {
      const assignee = await User.findById(assignedTo);
      if (assignee) {
        await TaskShare.findOneAndUpdate(
          { taskId: task._id, userId: assignee._id },
          { role: 'editor', sharedBy: req.user._id },
          { upsert: true }
        );
        await Notification.create({
          userId: assignee._id,
          taskId: task._id,
          type: 'task_assigned',
          title: 'Bạn được giao công việc mới',
          message: `${req.user.fullName} đã giao công việc "${task.title}" cho bạn.`
        });
        await sendNotificationEmail(
          assignee,
          `[Task Manager] Bạn được giao việc: ${task.title}`,
          `Xin chào ${assignee.fullName},\n\n${req.user.fullName} vừa giao công việc "${task.title}" cho bạn.\nHạn chót: ${dueDate ? new Date(dueDate).toLocaleDateString('vi-VN') : 'Không có'}`
        );
      }
    }

    res.status(201).json(task);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi tạo công việc', error: err.message });
  }
});

router.get('/:id', authMiddleware, checkTaskPermission(['owner', 'editor', 'viewer']), async (req, res) => {
  try {
    const task = await Task.findById(req.params.id)
      .populate('ownerId', 'fullName email')
      .populate('assignedTo', 'fullName email');
    const shares = await TaskShare.find({ taskId: task._id }).populate('userId', 'fullName email');
    const activities = await TaskActivity.find({ taskId: task._id }).populate('userId', 'fullName').sort({ createdAt: -1 });

    res.json({ task, myRole: req.userRole, shares, activities });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi lấy chi tiết công việc', error: err.message });
  }
});

router.put('/:id', authMiddleware, checkTaskPermission(['owner', 'editor']), async (req, res) => {
  try {
    const { title, description, dueDate, priority, status, category } = req.body;
    const task = req.task;

    if (title !== undefined) task.title = title;
    if (description !== undefined) task.description = description;
    if (dueDate !== undefined) task.dueDate = dueDate;
    if (priority !== undefined) task.priority = priority;
    if (status !== undefined) task.status = status;
    if (category !== undefined) task.category = category;
    await task.save();

    await TaskActivity.create({
      taskId: task._id,
      userId: req.user._id,
      action: `${req.user.fullName} đã cập nhật công việc (Trạng thái: ${task.status})`
    });

    const shares = await TaskShare.find({ taskId: task._id, userId: { $ne: req.user._id } });
    for (const s of shares) {
      await Notification.create({
        userId: s.userId,
        taskId: task._id,
        type: 'task_updated',
        title: 'Công việc được cập nhật',
        message: `${req.user.fullName} đã cập nhật công việc "${task.title}".`
      });
    }

    res.json(task);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi cập nhật công việc', error: err.message });
  }
});

router.delete('/:id', authMiddleware, checkTaskPermission(['owner']), async (req, res) => {
  try {
    await Task.findByIdAndDelete(req.params.id);
    await TaskShare.deleteMany({ taskId: req.params.id });
    await TaskActivity.deleteMany({ taskId: req.params.id });
    res.json({ message: 'Đã xóa công việc thành công' });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi xóa công việc', error: err.message });
  }
});

router.post('/:id/share', authMiddleware, checkTaskPermission(['owner']), async (req, res) => {
  try {
    const { email, role } = req.body;
    if (!['editor', 'viewer'].includes(role)) {
      return res.status(400).json({ message: 'Quyền chia sẻ phải là editor hoặc viewer' });
    }
    const targetUser = await User.findOne({ email: email.toLowerCase().trim() });
    if (!targetUser) return res.status(404).json({ message: 'Không tìm thấy người dùng với email này' });
    if (targetUser._id.toString() === req.user._id.toString()) {
      return res.status(400).json({ message: 'Không thể tự chia sẻ cho chính mình' });
    }

    const share = await TaskShare.findOneAndUpdate(
      { taskId: req.task._id, userId: targetUser._id },
      { role, sharedBy: req.user._id },
      { upsert: true, new: true }
    );

    await TaskActivity.create({
      taskId: req.task._id,
      userId: req.user._id,
      action: `${req.user.fullName} đã chia sẻ công việc cho ${targetUser.fullName} (${role})`
    });

    await Notification.create({
      userId: targetUser._id,
      taskId: req.task._id,
      type: 'task_shared',
      title: 'Bạn được chia sẻ công việc',
      message: `${req.user.fullName} đã chia sẻ "${req.task.title}" cho bạn với quyền ${role}.`
    });

    await sendNotificationEmail(
      targetUser,
      `[Task Manager] Công việc mới được chia sẻ: ${req.task.title}`,
      `Xin chào ${targetUser.fullName},\n\n${req.user.fullName} đã chia sẻ công việc "${req.task.title}" cho bạn với quyền ${role}.`
    );

    res.json({ message: 'Chia sẻ thành công', share });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi chia sẻ công việc', error: err.message });
  }
});

router.delete('/:id/share/:userId', authMiddleware, checkTaskPermission(['owner']), async (req, res) => {
  try {
    await TaskShare.findOneAndDelete({ taskId: req.task._id, userId: req.params.userId });
    res.json({ message: 'Đã thu hồi quyền truy cập' });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi thu hồi quyền', error: err.message });
  }
});

router.put('/:id/assign', authMiddleware, checkTaskPermission(['owner']), async (req, res) => {
  try {
    const { email } = req.body;
    const assignee = await User.findOne({ email: email.toLowerCase().trim() });
    if (!assignee) return res.status(404).json({ message: 'Không tìm thấy người dùng với email này' });

    req.task.assignedTo = assignee._id;
    await req.task.save();

    await TaskShare.findOneAndUpdate(
      { taskId: req.task._id, userId: assignee._id },
      { role: 'editor', sharedBy: req.user._id },
      { upsert: true }
    );

    await TaskActivity.create({
      taskId: req.task._id,
      userId: req.user._id,
      action: `${req.user.fullName} đã giao việc cho ${assignee.fullName}`
    });

    await Notification.create({
      userId: assignee._id,
      taskId: req.task._id,
      type: 'task_assigned',
      title: 'Bạn được giao công việc',
      message: `${req.user.fullName} đã giao công việc "${req.task.title}" cho bạn.`
    });

    await sendNotificationEmail(
      assignee,
      `[Task Manager] Bạn được giao công việc: ${req.task.title}`,
      `Xin chào ${assignee.fullName},\n\n${req.user.fullName} đã giao công việc "${req.task.title}" cho bạn.`
    );

    res.json({ message: 'Giao việc thành công', task: req.task });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi giao việc', error: err.message });
  }
});

module.exports = router;