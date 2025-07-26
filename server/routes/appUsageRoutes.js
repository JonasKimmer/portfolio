const express = require('express');
const router = express.Router();
const AppUsage = require('../models/appUsageModel');

// App-Nutzungsdaten speichern
router.post('/', async (req, res) => {
  try {
    const appUsage = new AppUsage(req.body);
    await appUsage.save();
    res.status(201).json({ success: true, appUsage });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// App-Nutzungsdaten in Bulk speichern
router.post('/bulk', async (req, res) => {
  try {
    const result = await AppUsage.insertMany(req.body);
    res.status(201).json({ success: true, count: result.length });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// Alle App-Nutzungsdaten abrufen
router.get('/', async (req, res) => {
  try {
    const appUsageData = await AppUsage.find().sort({ timestamp: -1 }).limit(100);
    res.status(200).json({ success: true, count: appUsageData.length, data: appUsageData });
  } catch (error) {
    console.error('Fehler beim Abrufen der App-Nutzungsdaten:', error);
    res.status(400).json({ success: false, error: error.message });
  }
});

// App-Nutzungsdaten für ein Gerät abrufen
router.get('/:deviceId', async (req, res) => {
  try {
    const appUsage = await AppUsage.find({ deviceId: req.params.deviceId }).sort({ timestamp: -1 });
    res.status(200).json({ success: true, appUsage });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

module.exports = router;