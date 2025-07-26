const mongoose = require('mongoose');

async function testConnection() {
  try {
    await mongoose.connect('mongodb://localhost:27017/test');
    console.log('Verbindung erfolgreich');
    
    // Einfache Operation testen
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('Verfügbare Collections:', collections.map(c => c.name));
    
    await mongoose.disconnect();
  } catch (error) {
    console.error('Verbindungsfehler:', error);
  }
}

testConnection();