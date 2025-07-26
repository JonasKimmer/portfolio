const express = require('express');
const router = express.Router();
const TouchModel = require('../models/touchModel');

// POST-Endpunkt zum Speichern von Touch-Daten
router.post('/', async (req, res) => {
  try {
    console.log('Touch-Daten empfangen:', req.body);
    
    // Überprüfen, ob die Daten im richtigen Format vorliegen
    if (!req.body.touchData || !Array.isArray(req.body.touchData)) {
      return res.status(400).json({ error: 'Ungültiges Datenformat. Erwarte ein "touchData"-Array.' });
    }
    
    // Daten in die Datenbank einfügen
    const result = await TouchModel.insertMany(req.body.touchData);
    
    console.log(`${result.length} Touch-Datensätze gespeichert`);
    res.status(201).json({ 
      success: true, 
      message: `${result.length} Touch-Datensätze erfolgreich gespeichert`,
      count: result.length 
    });
  } catch (err) {
    console.error('Fehler beim Speichern der Touch-Daten:', err);
    res.status(500).json({ error: err.message });
  }
});

// GET-Endpunkt zum Abrufen aller Touch-Daten
router.get('/', async (req, res) => {
  try {
    const touchData = await TouchModel.find();
    res.status(200).json({ 
      success: true, 
      count: touchData.length,
      data: touchData 
    });
  } catch (err) {
    console.error('Fehler beim Abrufen der Touch-Daten:', err);
    res.status(500).json({ error: err.message });
  }
});

// GET-Endpunkt zum Abrufen der Touch-Daten eines bestimmten Typs
router.get('/type/:type', async (req, res) => {
  try {
    const type = req.params.type;
    const touchData = await TouchModel.find({ type });
    
    res.status(200).json({ 
      success: true, 
      count: touchData.length,
      data: touchData 
    });
  } catch (err) {
    console.error('Fehler beim Abrufen der Touch-Daten nach Typ:', err);
    res.status(500).json({ error: err.message });
  }
});

// DELETE-Endpunkt zum Löschen aller Touch-Daten
router.delete('/', async (req, res) => {
  try {
    const result = await TouchModel.deleteMany({});
    
    res.status(200).json({ 
      success: true, 
      message: `${result.deletedCount} Touch-Datensätze gelöscht` 
    });
  } catch (err) {
    console.error('Fehler beim Löschen der Touch-Daten:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;