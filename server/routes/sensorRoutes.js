const express = require('express');
const router = express.Router();
const SensorData = require('../models/sensorModel');

// Alle Sensordaten abrufen
router.get('/', async (req, res) => {
  try {
    const sensorData = await SensorData.find().sort({ timestamp: -1 }).limit(100);
    res.status(200).json({ success: true, count: sensorData.length, data: sensorData });
  } catch (error) {
    console.error('Fehler beim Abrufen der Sensordaten:', error);
    res.status(400).json({ success: false, error: error.message });
  }
});

// Sensordaten speichern
router.post('/', async (req, res) => {
  try {
    const sensorData = new SensorData(req.body);
    await sensorData.save();
    res.status(201).json({ success: true, sensorData });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// Sensordaten in Bulk speichern
router.post('/bulk', async (req, res) => {
  try {
    const result = await SensorData.insertMany(req.body);
    res.status(201).json({ success: true, count: result.length });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// Sensordaten für ein Gerät abrufen
router.get('/:deviceId', async (req, res) => {
  try {
    const { start, end } = req.query;
    let query = { deviceId: req.params.deviceId };
    if (start || end) {
      query.timestamp = {};
      if (start) query.timestamp.$gte = new Date(start);
      if (end) query.timestamp.$lte = new Date(end);
    }
    const sensorData = await SensorData.find(query).sort({ timestamp: -1 }).limit(100);
    res.status(200).json({ success: true, sensorData });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

module.exports = router;