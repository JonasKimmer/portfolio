const mongoose = require('mongoose');

const deviceSchema = new mongoose.Schema({
  deviceId: { 
    type: String, 
    required: true, 
    index: true 
  },
  model: String,
  manufacturer: String,
  osVersion: String,
  screenBrightness: Number,
  screenOrientation: String,
  oneHandMode: Boolean,
  dominantHand: String,
  timestamp: { 
    type: Date, 
    default: Date.now 
  }
});

module.exports = mongoose.model('Device', deviceSchema);