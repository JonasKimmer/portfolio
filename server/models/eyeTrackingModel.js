const mongoose = require('mongoose');

const eyeTrackingSchema = new mongoose.Schema({
  timestamp: {
    type: Date,
    required: true,
    default: Date.now
  },
  isUserLooking: {
    type: Boolean,
    required: true,
    default: true
  },
  direction: {
    type: String,
    enum: ['center', 'left', 'right', 'up', 'down', 'oben', 'unten', 'links', 'rechts', 'mitte', null]
  },
  eyePosition: {
    type: Map,
    of: Number
  },
  deviceId: {
    type: String
  }
}, {
  timestamps: true,
  collection: 'eyetrackings'  
});

module.exports = mongoose.model('EyeTracking', eyeTrackingSchema);