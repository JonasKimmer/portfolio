const mongoose = require('mongoose');

const sensorDataSchema = new mongoose.Schema({
  deviceId: { 
    type: String, 
    required: true, 
    index: true 
  },
  timestamp: { 
    type: Date, 
    default: Date.now 
  },
  gyroscope: {
    x: Number,
    y: Number,
    z: Number
  },
  magnetometer: {
    x: Number,
    y: Number,
    z: Number
  },
  lightSensor: Number,
  proximitySensor: Boolean
});

module.exports = mongoose.model('SensorData', sensorDataSchema, 'sensordatas');