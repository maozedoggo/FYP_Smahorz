const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Get Realtime Database reference
const db = admin.database();

// ============================================================================
// SCHEDULE SYSTEM FUNCTIONS (Realtime Database)
// ============================================================================

/**
 * Check and execute scheduled tasks every 5 minutes
 */
exports.checkSchedules = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'Asia/Kuala_Lumpur',
  region: 'asia-southeast1',
  memory: '256MiB'
}, async (event) => {
  try {
    console.log('🔔 Checking scheduled tasks...');
    const now = new Date();
    const currentTime = now.toTimeString().split(' ')[0].substring(0, 5); // "HH:MM"
    
    // Get all schedules from Realtime Database
    const schedulesRef = db.ref('schedules');
    const snapshot = await schedulesRef.once('value');
    
    if (!snapshot.exists()) {
      console.log('No schedules found');
      return;
    }
    
    const schedules = snapshot.val();
    const executedTasks = [];
    
    // Check each schedule
    for (const [scheduleId, schedule] of Object.entries(schedules)) {
      if (schedule.time === currentTime && schedule.enabled) {
        console.log(`🎯 Executing schedule: ${schedule.name} at ${schedule.time}`);
        
        // Execute the scheduled task
        await executeScheduleTask(scheduleId, schedule);
        executedTasks.push(schedule.name);
        
        // Update last executed time
        await schedulesRef.child(scheduleId).update({
          lastExecuted: now.toISOString()
        });
      }
    }
    
    console.log(`✅ Executed ${executedTasks.length} tasks:`, executedTasks);
    
  } catch (error) {
    console.error('❌ Error in schedule check:', error);
    throw error;
  }
});

/**
 * Execute individual schedule task
 */
async function executeScheduleTask(scheduleId, schedule) {
  try {
    // Based on schedule type, perform different actions
    switch (schedule.type) {
      case 'device_control':
        // Control Arduino devices
        await controlDevice(schedule.deviceId, schedule.action);
        break;
        
      case 'notification':
        // Send notification
        await sendNotification(schedule.title, schedule.message);
        break;
        
      case 'data_cleanup':
        // Clean up old data
        await cleanupData();
        break;
        
      default:
        console.log(`Unknown schedule type: ${schedule.type}`);
    }
    
    // Log the execution
    await db.ref('schedule_logs').push({
      scheduleId,
      scheduleName: schedule.name,
      executedAt: new Date().toISOString(),
      type: schedule.type,
      status: 'success'
    });
    
  } catch (error) {
    console.error(`Error executing schedule ${scheduleId}:`, error);
    
    // Log error
    await db.ref('schedule_logs').push({
      scheduleId,
      scheduleName: schedule.name,
      executedAt: new Date().toISOString(),
      type: schedule.type,
      status: 'error',
      error: error.message
    });
  }
}

/**
 * Control Arduino device
 */
async function controlDevice(deviceId, action) {
  console.log(`🔧 Controlling device ${deviceId}: ${action}`);
  
  // Update device status in Realtime Database
  await db.ref(`devices/${deviceId}`).update({
    status: action,
    lastUpdated: new Date().toISOString()
  });
  
  // Send commands to Arduino
  await db.ref(`device_commands/${deviceId}`).push({
    command: action,
    timestamp: Date.now(),
    status: 'pending'
  });
}

/**
 * Send notification
 */
async function sendNotification(title, message) {
  console.log(`📢 Notification: ${title} - ${message}`);
  
  // Store notification in Realtime Database
  await db.ref('notifications').push({
    title,
    message,
    timestamp: new Date().toISOString(),
    read: false
  });
}

/**
 * Clean up old data
 */
async function cleanupData() {
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  
  // Clean up old logs
  const logsRef = db.ref('schedule_logs');
  const logsSnapshot = await logsRef.once('value');
  
  if (logsSnapshot.exists()) {
    const updates = {};
    logsSnapshot.forEach((childSnapshot) => {
      const log = childSnapshot.val();
      const logDate = new Date(log.executedAt);
      
      if (logDate < sevenDaysAgo) {
        updates[childSnapshot.key] = null; // Mark for deletion
      }
    });
    
    await logsRef.update(updates);
    console.log('🧹 Cleaned up old schedule logs');
  }
}

// ============================================================================
// ARDUINO DEVICE FUNCTIONS (Realtime Database)
// ============================================================================

/**
 * Arduino devices can send sensor data to this endpoint
 * POST https://asia-southeast1-smahorz-fyp.cloudfunctions.net/arduinoData
 * Body: {"deviceId": "arduino1", "temperature": 25.5, "humidity": 60}
 */
exports.arduinoData = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    // Enable CORS
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
    
    const { deviceId, temperature, humidity, light, soilMoisture, status } = request.body;
    
    if (!deviceId) {
      response.status(400).json({ error: 'deviceId is required' });
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
    
    await db.ref(`sensor_data/${deviceId}`).push(sensorData);
    
    // Update device status
    await db.ref(`devices/${deviceId}`).update({
      lastSeen: new Date().toISOString(),
      lastData: sensorData,
      status: 'online'
    });
    
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
 * Arduino devices can check for commands from this endpoint
 * GET https://asia-southeast1-smahorz-fyp.cloudfunctions.net/arduinoCommands?deviceId=arduino1
 */
exports.arduinoCommands = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    const { deviceId } = request.query;
    
    if (!deviceId) {
      response.status(400).json({ error: 'deviceId query parameter is required' });
      return;
    }
    
    // Get pending commands for this device
    const commandsRef = db.ref(`device_commands/${deviceId}`);
    const snapshot = await commandsRef.orderByChild('status').equalTo('pending').once('value');
    
    const commands = [];
    const updates = {};
    
    snapshot.forEach((childSnapshot) => {
      const command = childSnapshot.val();
      commands.push({
        id: childSnapshot.key,
        ...command
      });
      
      // Mark command as delivered
      updates[`${childSnapshot.key}/status`] = 'delivered';
      updates[`${childSnapshot.key}/deliveredAt`] = Date.now();
    });
    
    // Update commands status
    if (Object.keys(updates).length > 0) {
      await commandsRef.update(updates);
    }
    
    response.json({
      success: true,
      deviceId,
      commands,
      timestamp: Date.now()
    });
    
  } catch (error) {
    console.error('Error getting Arduino commands:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Your Flutter app can call this to send commands to Arduino
 * POST https://asia-southeast1-smahorz-fyp.cloudfunctions.net/sendCommand
 * Body: {"deviceId": "arduino1", "command": "turn_on", "parameters": {}}
 */
exports.sendCommand = onRequest({
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
    
    const { deviceId, command, parameters } = request.body;
    
    if (!deviceId || !command) {
      response.status(400).json({ error: 'deviceId and command are required' });
      return;
    }
    
    // Create command in Realtime Database
    const commandRef = await db.ref(`device_commands/${deviceId}`).push({
      command,
      parameters: parameters || {},
      status: 'pending',
      createdAt: Date.now(),
      createdBy: 'app'
    });
    
    response.json({
      success: true,
      message: 'Command sent to device',
      commandId: commandRef.key,
      deviceId,
      command
    });
    
  } catch (error) {
    console.error('Error sending command:', error);
    response.status(500).json({ error: error.message });
  }
});

// ============================================================================
// SCHEDULE MANAGEMENT FUNCTIONS
// ============================================================================

/**
 * Create a new schedule from your Flutter app
 * POST https://asia-southeast1-smahorz-fyp.cloudfunctions.net/createSchedule
 * Body: {
 *   "name": "Morning Light On",
 *   "time": "07:00",
 *   "type": "device_control",
 *   "deviceId": "arduino1",
 *   "action": "turn_on",
 *   "enabled": true
 * }
 */
exports.createSchedule = onRequest({
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
    
    const { name, time, type, deviceId, action, title, message, enabled = true } = request.body;
    
    if (!name || !time || !type) {
      response.status(400).json({ error: 'name, time, and type are required' });
      return;
    }
    
    // Validate time format (HH:MM)
    const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/;
    if (!timeRegex.test(time)) {
      response.status(400).json({ error: 'Invalid time format. Use HH:MM' });
      return;
    }
    
    // Create schedule in Realtime Database
    const scheduleData = {
      name,
      time,
      type,
      enabled,
      createdAt: new Date().toISOString(),
      createdBy: 'user'
    };
    
    // Add type-specific fields
    if (type === 'device_control') {
      scheduleData.deviceId = deviceId || null;
      scheduleData.action = action || null;
    } else if (type === 'notification') {
      scheduleData.title = title || null;
      scheduleData.message = message || null;
    }
    
    const scheduleRef = await db.ref('schedules').push(scheduleData);
    
    response.json({
      success: true,
      message: 'Schedule created successfully',
      scheduleId: scheduleRef.key,
      schedule: scheduleData
    });
    
  } catch (error) {
    console.error('Error creating schedule:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Get all schedules
 * GET https://asia-southeast1-smahorz-fyp.cloudfunctions.net/getSchedules
 */
exports.getSchedules = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    const schedulesRef = db.ref('schedules');
    const snapshot = await schedulesRef.once('value');
    
    const schedules = [];
    if (snapshot.exists()) {
      snapshot.forEach((childSnapshot) => {
        schedules.push({
          id: childSnapshot.key,
          ...childSnapshot.val()
        });
      });
    }
    
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
 * Update a schedule
 * PUT https://asia-southeast1-smahorz-fyp.cloudfunctions.net/updateSchedule
 * Body: {"scheduleId": "abc123", "updates": {"enabled": false}}
 */
exports.updateSchedule = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Methods', 'POST, PUT');
      response.set('Access-Control-Allow-Headers', 'Content-Type');
      response.status(204).send('');
      return;
    }
    
    if (request.method !== 'POST' && request.method !== 'PUT') {
      response.status(405).json({ error: 'Only POST/PUT methods allowed' });
      return;
    }
    
    const { scheduleId, updates } = request.body;
    
    if (!scheduleId || !updates) {
      response.status(400).json({ error: 'scheduleId and updates are required' });
      return;
    }
    
    // Update schedule
    await db.ref(`schedules/${scheduleId}`).update({
      ...updates,
      updatedAt: new Date().toISOString()
    });
    
    response.json({
      success: true,
      message: 'Schedule updated successfully',
      scheduleId
    });
    
  } catch (error) {
    console.error('Error updating schedule:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Delete a schedule
 * DELETE https://asia-southeast1-smahorz-fyp.cloudfunctions.net/deleteSchedule
 * Body: {"scheduleId": "abc123"}
 */
exports.deleteSchedule = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Methods', 'POST, DELETE');
      response.set('Access-Control-Allow-Headers', 'Content-Type');
      response.status(204).send('');
      return;
    }
    
    if (request.method !== 'POST' && request.method !== 'DELETE') {
      response.status(405).json({ error: 'Only POST/DELETE methods allowed' });
      return;
    }
    
    const { scheduleId } = request.body;
    
    if (!scheduleId) {
      response.status(400).json({ error: 'scheduleId is required' });
      return;
    }
    
    // Delete schedule
    await db.ref(`schedules/${scheduleId}`).remove();
    
    response.json({
      success: true,
      message: 'Schedule deleted successfully',
      scheduleId
    });
    
  } catch (error) {
    console.error('Error deleting schedule:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Get schedule logs
 * GET https://asia-southeast1-smahorz-fyp.cloudfunctions.net/getScheduleLogs?limit=50
 */
exports.getScheduleLogs = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.set('Access-Control-Allow-Origin', '*');
    
    const limit = parseInt(request.query.limit) || 50;
    
    const logsRef = db.ref('schedule_logs');
    const snapshot = await logsRef.orderByChild('executedAt').limitToLast(limit).once('value');
    
    const logs = [];
    if (snapshot.exists()) {
      snapshot.forEach((childSnapshot) => {
        logs.push({
          id: childSnapshot.key,
          ...childSnapshot.val()
        });
      });
    }
    
    // Reverse to show newest first
    logs.reverse();
    
    response.json({
      success: true,
      logs,
      count: logs.length
    });
    
  } catch (error) {
    console.error('Error getting schedule logs:', error);
    response.status(500).json({ error: error.message });
  }
});