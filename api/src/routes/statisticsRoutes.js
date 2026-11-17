const express = require('express');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/overview', authMiddleware, async (req, res) => {
  try {
    const shares = await TaskShare.find({ userId: req.user._id });
    const sharedIds = shares.map(s => s.taskId);
    const tasks = await Task.find({
      $or: [{ ownerId: req.user._id }, { _id: { $in: sharedIds } }, { assignedTo: req.user._id }]
    });

    const now = new Date();
    const stats = {
      total: tasks.length,
      todo: tasks.filter(t => t.status === 'todo').length,
      inProgress: tasks.filter(t => t.status === 'in_progress').length,
      done: tasks.filter(t => t.status === 'done').length,
      overdue: tasks.filter(t => t.status !== 'done' && t.dueDate && new Date(t.dueDate) < now).length,
      ownedByMe: tasks.filter(t => t.ownerId.toString() === req.user._id.toString()).length,
      assignedToMe: tasks.filter(t => t.assignedTo && t.assignedTo.toString() === req.user._id.toString()).length
    };

    res.json(stats);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi thống kê', error: err.message });
  }
});

module.exports = router;