// routes/deviceRoutes.js
const express = require('express');
const router = express.Router();
const Device = require('../models/deviceModel');

// Gerätedaten speichern
router.post('/', async (req, res) => {
  try {
    const device = new Device(req.body);
    await device.save();
    res.status(201).json({ success: true, device });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// Alle Gerätedaten abrufen
router.get('/', async (req, res) => {
  try {
    const devices = await Device.find();
    res.status(200).json({ success: true, count: devices.length, data: devices });
  } catch (error) {
    console.error('Fehler beim Abrufen aller Geräte:', error);
    res.status(400).json({ success: false, error: error.message });
  }
});

// Gerätedaten abrufen
router.get('/:deviceId', async (req, res) => {
  try {
    // Stelle sicher, dass req.params.deviceId definiert ist
    console.log('Suche nach Gerät:', req.params.deviceId);
    
    const device = await Device.findOne({ deviceId: req.params.deviceId });
    
    if (!device) {
      return res.status(404).json({ success: false, message: 'Gerät nicht gefunden' });
    }
    
    res.status(200).json({ success: true, device });
  } catch (error) {
    console.error('Fehler beim Abrufen des Geräts:', error);
    res.status(400).json({ success: false, error: error.message });
  }
});

module.exports = router;