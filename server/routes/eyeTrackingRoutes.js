const express = require('express');
const router = express.Router();
const EyeTrackingModel = require('../models/eyeTrackingModel');

// POST-Endpunkt zum Speichern von Eye-Tracking-Daten
router.post('/', async (req, res) => {
  try {
    console.log('Eye-Tracking-Daten empfangen:', req.body);
    
    // Überprüfen, ob die Daten im richtigen Format vorliegen
    if (!req.body.eyeTrackingData || !Array.isArray(req.body.eyeTrackingData)) {
      return res.status(400).json({ error: 'Ungültiges Datenformat. Erwarte ein "eyeTrackingData"-Array.' });
    }
    
    // Zeitstempel für jedes Dokument konvertieren (falls als String übergeben)
    const processedData = req.body.eyeTrackingData.map(data => {
      // Wenn timestamp ein String ist, konvertieren wir es zu einem Date-Objekt
      if (typeof data.timestamp === 'string') {
        data.timestamp = new Date(data.timestamp);
      }
      return data;
    });
    
    // Daten in die Datenbank einfügen
    const result = await EyeTrackingModel.insertMany(processedData);
    
    console.log(`${result.length} Eye-Tracking-Datensätze gespeichert`);
    res.status(201).json({ 
      success: true, 
      message: `${result.length} Eye-Tracking-Datensätze erfolgreich gespeichert`,
      count: result.length 
    });
  } catch (err) {
    console.error('Fehler beim Speichern der Eye-Tracking-Daten:', err);
    res.status(500).json({ error: err.message });
  }
});

// GET-Endpunkt zum Abrufen aller Eye-Tracking-Daten
router.get('/', async (req, res) => {
  try {
    const eyeTrackingData = await EyeTrackingModel.find();
    res.status(200).json({ 
      success: true, 
      count: eyeTrackingData.length,
      data: eyeTrackingData 
    });
  } catch (err) {
    console.error('Fehler beim Abrufen der Eye-Tracking-Daten:', err);
    res.status(500).json({ error: err.message });
  }
});

// GET-Endpunkt zum Abrufen der Eye-Tracking-Daten für eine bestimmte Blickrichtung
router.get('/direction/:direction', async (req, res) => {
  try {
    const direction = req.params.direction;
    const eyeTrackingData = await EyeTrackingModel.find({ direction });
    
    res.status(200).json({ 
      success: true, 
      count: eyeTrackingData.length,
      data: eyeTrackingData 
    });
  } catch (err) {
    console.error('Fehler beim Abrufen der Eye-Tracking-Daten nach Richtung:', err);
    res.status(500).json({ error: err.message });
  }
});

// DELETE-Endpunkt zum Löschen aller Eye-Tracking-Daten
router.delete('/', async (req, res) => {
  try {
    const result = await EyeTrackingModel.deleteMany({});
    
    res.status(200).json({ 
      success: true, 
      message: `${result.deletedCount} Eye-Tracking-Datensätze gelöscht` 
    });
  } catch (err) {
    console.error('Fehler beim Löschen der Eye-Tracking-Daten:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;