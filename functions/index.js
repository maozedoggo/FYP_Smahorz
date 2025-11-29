const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Get both database references
const db = admin.database(); // Realtime Database
const firestore = admin.firestore(); // Firestore

// ============================================================================
// HYBRID SCHEDULE SYSTEM (Works with your Flutter app)
// ============================================================================

/**
 * Check and execute scheduled tasks every minute
 * This checks FIRESTORE schedules (from your Flutter app)
 */
exports.checkSchedules = onSchedule({
  schedule: 'every 1 minutes',
  timeZone: 'Asia/Kuala_Lumpur',
  region: 'asia-southeast1',
  memory: '256MiB'
}, async (event) => {
  try {
    console.log('🔔 Checking scheduled tasks...');
    const now = new Date();
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    const currentDate = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`;
    
    console.log(`Current time: ${currentTime}, Current date: ${currentDate}`);
    
    // Get all households
    const householdsSnapshot = await firestore.collection('households').get();
    
    let totalExecuted = 0;
    
    for (const householdDoc of householdsSnapshot.docs) {
      const householdUid = householdDoc.id;
      
      // Get all devices in this household
      const devicesSnapshot = await firestore
        .collection('households')
        .doc(householdUid)
        .collection('devices')
        .get();
      
      for (const deviceDoc of devicesSnapshot.docs) {
        const deviceId = deviceDoc.id;
        const deviceData = deviceDoc.data();
        
        // Get schedules for this device that match current time and date
        const schedulesSnapshot = await firestore
          .collection('households')
          .doc(householdUid)
          .collection('devices')
          .doc(deviceId)
          .collection('schedules')
          .where('date', '==', currentDate)
          .where('time', '==', currentTime)
          .where('executed', '==', false)
          .get();
        
        for (const scheduleDoc of schedulesSnapshot.docs) {
          const schedule = scheduleDoc.data();
          const scheduleId = scheduleDoc.id;
          
          console.log(`🎯 Executing schedule for device ${deviceId}: ${schedule.action}`);
          
          // Execute the schedule
          await executeSchedule(householdUid, deviceId, deviceData.type, schedule);
          
          // Mark as executed
          await scheduleDoc.ref.update({
            executed: true,
            executedAt: admin.firestore.FieldValue.serverTimestamp(),
            executedBy: 'auto-scheduler'
          });
          
          totalExecuted++;
          
          // Log execution
          await firestore
            .collection('households')
            .doc(householdUid)
            .collection('schedule_logs')
            .add({
              deviceId,
              deviceName: deviceData.name,
              scheduleId,
              action: schedule.action,
              door: schedule.door || null,
              executedAt: admin.firestore.FieldValue.serverTimestamp(),
              status: 'success'
            });
        }
      }
    }
    
    console.log(`✅ Executed ${totalExecuted} schedules`);
    
  } catch (error) {
    console.error('❌ Error in schedule check:', error);
    throw error;
  }
});

/**
 * Execute a schedule by updating Realtime Database
 */
async function executeSchedule(householdUid, deviceId, deviceType, schedule) {
  try {
    const devicePath = `${householdUid}/${deviceId}`;
    
    // Handle Parcel Box
    if (deviceType && deviceType.toLowerCase().includes('parcel')) {
      const door = schedule.door || 'Inside';
      const doorPath = door === 'Inside' ? 'insideStatus' : 'outsideStatus';
      const status = schedule.action === 'Unlock';
      
      await db.ref(`${devicePath}/${doorPath}`).set(status);
      console.log(`✅ Updated ${devicePath}/${doorPath} to ${status}`);
    } 
    // Handle Clothes Hanger
    else {
      const status = schedule.action === 'Extend';
      await db.ref(`${devicePath}/status`).set(status);
      console.log(`✅ Updated ${devicePath}/status to ${status}`);
    }
    
  } catch (error) {
    console.error('Error executing schedule:', error);
    throw error;
  }
}

/**
 * Sync schedule from Firestore to Realtime Database when created
 * This ensures your Arduino can also see schedules
 */
exports.syncScheduleToRTDB = onDocumentCreated({
  document: 'households/{householdUid}/devices/{deviceId}/schedules/{scheduleId}',
  region: 'asia-southeast1'
}, async (event) => {
  try {
    const scheduleData = event.data.data();
    const { householdUid, deviceId, scheduleId } = event.params;
    
    // Also store in Realtime Database for Arduino access
    await db.ref(`schedules/${householdUid}/${deviceId}/${scheduleId}`).set({
      ...scheduleData,
      createdAt: new Date().toISOString()
    });
    
    console.log(`✅ Synced schedule ${scheduleId} to Realtime Database`);
    
  } catch (error) {
    console.error('Error syncing schedule:', error);
  }
});

/**
 * Monitor device status changes in Realtime Database
 * Log them to Firestore for history
 */
exports.logDeviceStatusChange = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Methods', 'POST');
      response.set('Access-Control-Allow-Headers', 'Content-Type');
      response.status(204).send('');
      return;
    }
    
    const { householdUid, deviceId, status, door } = request.body;
    
    if (!householdUid || !deviceId) {
      response.status(400).json({ error: 'householdUid and deviceId are required' });
      return;
    }
    
    // Log to Firestore
    await firestore
      .collection('households')
      .doc(householdUid)
      .collection('devices')
      .doc(deviceId)
      .collection('status_logs')
      .add({
        status,
        door: door || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        source: 'realtime-db'
      });
    
    response.json({ success: true, message: 'Status logged' });
    
  } catch (error) {
    console.error('Error logging status:', error);
    response.status(500).json({ error: error.message });
  }
});

// ============================================================================
// ARDUINO DEVICE FUNCTIONS (Realtime Database)
// ============================================================================

/**
 * Arduino devices can send sensor data to this endpoint
 * POST https://asia-southeast1-smahorz-fyp.cloudfunctions.net/arduinoData
 * Body: {"householdUid": "xxx", "deviceId": "arduino1", "temperature": 25.5, "humidity": 60}
 */
exports.arduinoData = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Methods', 'POST');
      response.set('Access-Control-Allow-Headers', 'Content-Type');
      response.status(204).send('');
      return;
    }
    
    if (request.method !== 'POST') {
      response.status(405).json({ error: 'Only POST method allowed' });
      return;
    }
    
    const { householdUid, deviceId, temperature, humidity, light, soilMoisture, status } = request.body;
    
    if (!householdUid || !deviceId) {
      response.status(400).json({ error: 'householdUid and deviceId are required' });
      return;
    }
    
    // Store sensor data in Realtime Database
    const sensorData = {
      deviceId,
      temperature: temperature || null,
      humidity: humidity || null,
      light: light || null,
      soilMoisture: soilMoisture || null,
      status: status || 'online',
      timestamp: Date.now(),
      receivedAt: new Date().toISOString()
    };
    
    await db.ref(`sensor_data/${householdUid}/${deviceId}`).push(sensorData);
    
    // Update device status in Realtime Database
    await db.ref(`${householdUid}/${deviceId}/lastSeen`).set(new Date().toISOString());
    await db.ref(`${householdUid}/${deviceId}/lastData`).set(sensorData);
    
    response.json({
      success: true,
      message: 'Sensor data received',
      data: sensorData
    });
    
  } catch (error) {
    console.error('Error processing Arduino data:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Arduino devices can check for pending commands
 * GET https://asia-southeast1-smahorz-fyp.cloudfunctions.net/arduinoCommands?householdUid=xxx&deviceId=arduino1
 */
exports.arduinoCommands = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    const { householdUid, deviceId } = request.query;
    
    if (!householdUid || !deviceId) {
      response.status(400).json({ error: 'householdUid and deviceId query parameters are required' });
      return;
    }
    
    // Get current device status from Realtime Database
    const deviceSnapshot = await db.ref(`${householdUid}/${deviceId}`).once('value');
    const deviceData = deviceSnapshot.val() || {};
    
    response.json({
      success: true,
      householdUid,
      deviceId,
      status: deviceData.status || null,
      insideStatus: deviceData.insideStatus || null,
      outsideStatus: deviceData.outsideStatus || null,
      lastSeen: deviceData.lastSeen || null,
      timestamp: Date.now()
    });
    
  } catch (error) {
    console.error('Error getting Arduino commands:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Get upcoming schedules for a device
 * GET https://asia-southeast1-smahorz-fyp.cloudfunctions.net/getUpcomingSchedules?householdUid=xxx&deviceId=yyy
 */
exports.getUpcomingSchedules = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    const { householdUid, deviceId } = request.query;
    
    if (!householdUid || !deviceId) {
      response.status(400).json({ error: 'householdUid and deviceId are required' });
      return;
    }
    
    const today = new Date();
    const dateKey = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    
    const schedulesSnapshot = await firestore
      .collection('households')
      .doc(householdUid)
      .collection('devices')
      .doc(deviceId)
      .collection('schedules')
      .where('date', '==', dateKey)
      .where('executed', '==', false)
      .orderBy('time')
      .get();
    
    const schedules = schedulesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    response.json({
      success: true,
      schedules,
      count: schedules.length
    });
    
  } catch (error) {
    console.error('Error getting schedules:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Get schedule execution logs
 * GET https://asia-southeast1-smahorz-fyp.cloudfunctions.net/getScheduleLogs?householdUid=xxx&limit=50
 */
exports.getScheduleLogs = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    const { householdUid, limit = '50' } = request.query;
    
    if (!householdUid) {
      response.status(400).json({ error: 'householdUid is required' });
      return;
    }
    
    const logsSnapshot = await firestore
      .collection('households')
      .doc(householdUid)
      .collection('schedule_logs')
      .orderBy('executedAt', 'desc')
      .limit(parseInt(limit))
      .get();
    
    const logs = logsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      executedAt: doc.data().executedAt?.toDate().toISOString()
    }));
    
    response.json({
      success: true,
      logs,
      count: logs.length
    });
    
  } catch (error) {
    console.error('Error getting logs:', error);
    response.status(500).json({ error: error.message });
  }
});