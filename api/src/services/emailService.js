const nodemailer = require('nodemailer');
const EmailLog = require('../models/EmailLog');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT) || 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS
  }
});

const sendNotificationEmail = async (user, subject, textBody) => {
  if (!user || !user.emailNotificationsEnabled || !user.email) return;

  try {
    await transporter.sendMail({
      from: `"Task Manager App" <${process.env.SMTP_USER}>`,
      to: user.email,
      subject,
      text: textBody
    });

    await EmailLog.create({
      toEmail: user.email,
      subject,
      body: textBody,
      status: 'sent'
    });
  } catch (err) {
    console.error('Lỗi gửi email:', err.message);
    await EmailLog.create({
      toEmail: user.email,
      subject,
      body: textBody,
      status: 'failed',
      errorMessage: err.message
    });
  }
};

module.exports = { sendNotificationEmail };