const mongoose = require('mongoose');

const emailLogSchema = new mongoose.Schema({
  toEmail: { type: String, required: true },
  subject: { type: String, required: true },
  body: { type: String, required: true },
  status: { type: String, enum: ['sent', 'failed'], required: true },
  errorMessage: { type: String, default: '' }
}, { timestamps: true });

module.exports = mongoose.model('EmailLog', emailLogSchema);