const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

const checkTaskPermission = (allowedRoles) => {
  return async (req, res, next) => {
    try {
      const taskId = req.params.id || req.params.taskId;
      const task = await Task.findById(taskId);
      if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });

      let role = null;
      if (task.ownerId.toString() === req.user._id.toString()) {
        role = 'owner';
      } else {
        const share = await TaskShare.findOne({ taskId, userId: req.user._id });
        if (share) role = share.role;
      }

      if (!role || !allowedRoles.includes(role)) {
        return res.status(403).json({ message: 'Bạn không có quyền thực hiện thao tác này' });
      }

      req.task = task;
      req.userRole = role;
      next();
    } catch (err) {
      res.status(500).json({ message: 'Lỗi kiểm tra phân quyền', error: err.message });
    }
  };
};

module.exports = { checkTaskPermission };