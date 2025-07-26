const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bodyParser = require('body-parser');
const serverless = require('serverless-http');

const app = express();
const PORT = process.env.PORT || 3000;

// MongoDB Atlas-Verbindung
const connectDB = async () => {
  try {
    const mongoURI = process.env.MONGODB_URI || 
      'mongodb+srv://jonaskimmer:Kk4y7STCSSXbaqOI@cluster0.ujpcvhz.mongodb.net/adaptive-ui-tracker?retryWrites=true&w=majority';
    
    await mongoose.connect(mongoURI);
    console.log('MongoDB Atlas erfolgreich verbunden');
  } catch (error) {
    console.error('MongoDB Atlas Verbindungsfehler:', error);
    setTimeout(connectDB, 5000);
  }
};

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '10mb' }));

// Routen importieren
const deviceRoutes = require('../../routes/deviceRoutes');
const sensorRoutes = require('../../routes/sensorRoutes');
const touchRoutes = require('../../routes/touchRoutes');
const eyeTrackingRoutes = require('../../routes/eyeTrackingRoutes');
const appUsageRoutes = require('../../routes/appUsageRoutes');

// Routen einbinden
app.use('/api/device', deviceRoutes);
app.use('/api/sensor', sensorRoutes);
app.use('/api/touch', touchRoutes);
app.use('/api/eyetracking', eyeTrackingRoutes);
app.use('/api/appusage', appUsageRoutes);

// Standardroute
app.get('/', (req, res) => {
  res.send('Adaptive UI Tracker API ist aktiv - Running on Netlify Functions');
});

// Ping-Endpunkt für Verbindungstests
app.get('/api/ping', (req, res) => {
  console.log('Ping-Anfrage empfangen');
  res.status(200).json({
    message: 'pong',
    database: 'MongoDB Atlas',
    timestamp: new Date().toISOString()
  });
});

// Health Check für Cloud-Hosting
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    uptime: process.uptime()
  });
});

// Fehlerbehandlung
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Ein interner Serverfehler ist aufgetreten',
    error: process.env.NODE_ENV === 'production' ? {} : err.stack
  });
});

// Datenbankverbindung herstellen
connectDB();

// Export für Netlify Functions
module.exports.handler = serverless(app); 