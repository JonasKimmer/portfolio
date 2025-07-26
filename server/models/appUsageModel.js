const mongoose = require('mongoose');

const appUsageSchema = new mongoose.Schema({
  deviceId: {
    type: String,
    required: true,
    index: true
  },
  packageName: String,
  appName: String,
  usageDuration: Number,
  openCount: Number,
  timestamp: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('AppUsage', appUsageSchema);