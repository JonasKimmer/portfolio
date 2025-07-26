const mongoose = require('mongoose');

const touchSchema = new mongoose.Schema({
  timestamp: {
    type: Number,
    required: true
  },
  x: {
    type: Number,
    required: true
  },
  y: {
    type: Number,
    required: true
  },
  type: {
    type: String,
    required: true,
    enum: ['tap', 'swipe', 'longpress']
  },
  direction: {
    type: String,
    enum: ['up', 'down', 'left', 'right', null]
  },
  endX: {
    type: Number
  },
  endY: {
    type: Number
  },
  durationMs: {
    type: Number
  },
  deviceId: {
    type: String
  }
}, {
  timestamps: true,
  collection: 'touchevents'  
});

module.exports = mongoose.model('Touch', touchSchema);