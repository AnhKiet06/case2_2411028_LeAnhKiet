const express = require('express');
const User = require('../models/User');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/search', authMiddleware, async (req, res) => {
  try {
    const q = req.query.q || '';
    const users = await User.find({
      _id: { $ne: req.user._id },
      $or: [
        { email: { $regex: q, $options: 'i' } },
        { fullName: { $regex: q, $options: 'i' } }
      ]
    }).select('_id fullName email avatarUrl').limit(10);
    res.json(users);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi tìm kiếm người dùng', error: err.message });
  }
});

router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const { fullName, avatarUrl, emailNotificationsEnabled } = req.body;
    if (fullName !== undefined) req.user.fullName = fullName;
    if (avatarUrl !== undefined) req.user.avatarUrl = avatarUrl;
    if (emailNotificationsEnabled !== undefined) req.user.emailNotificationsEnabled = emailNotificationsEnabled;
    await req.user.save();
    res.json(req.user);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi cập nhật hồ sơ', error: err.message });
  }
});

module.exports = router;