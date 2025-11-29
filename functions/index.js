const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Get Realtime Database reference
const db = admin.database();

// ============================================================================
// SCHEDULE EXECUTION SYSTEM - Reads from Realtime Database
// ============================================================================

/**
 * Check and execute scheduled tasks every minute
 * Reads schedules from Realtime Database and updates device status
 */
exports.checkSchedules = onSchedule({
  schedule: 'every 1 minutes',
  timeZone: 'Asia/Kuala_Lumpur',
  region: 'asia-southeast1',
  memory: '256MiB'
}, async (event) => {
  try {
    console.log('🔔 Checking scheduled tasks from Realtime Database...');
    
    // Get current time in Malaysia timezone
    const now = new Date();
    const malaysiaTime = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Kuala_Lumpur' }));
    
    const currentHour = malaysiaTime.getHours();
    const currentMinute = malaysiaTime.getMinutes();
    const currentTime = `${currentHour.toString().padStart(2, '0')}:${currentMinute.toString().padStart(2, '0')}`;
    
    const year = malaysiaTime.getFullYear();
    const month = (malaysiaTime.getMonth() + 1).toString().padStart(2, '0');
    const day = malaysiaTime.getDate().toString().padStart(2, '0');
    const currentDate = `${year}-${month}-${day}`;
    
    console.log(`⏰ Current time: ${currentTime}, Current date: ${currentDate}`);
    
    // Get all households from Realtime Database
    const householdsSnapshot = await db.ref('/').once('value');
    const households = householdsSnapshot.val() || {};
    
    console.log(`🏠 Found ${Object.keys(households).length} households to check`);
    
    let totalExecuted = 0;
    let totalChecked = 0;
    
    for (const [householdUid, householdData] of Object.entries(households)) {
      // Skip if not a household (could be other data)
      if (typeof householdData !== 'object' || householdUid.startsWith('_')) {
        continue;
      }
      
      console.log(`🔍 Checking household: ${householdUid}`);
      
      for (const [deviceId, deviceData] of Object.entries(householdData)) {
        // Skip if device has no schedules or is not a device object
        if (typeof deviceData !== 'object' || !deviceData.schedules) {
          continue;
        }
        
        const schedules = deviceData.schedules;
        console.log(`📱 Checking device: ${deviceId}, Schedules: ${Object.keys(schedules).length}`);
        
        for (const [scheduleId, schedule] of Object.entries(schedules)) {
          totalChecked++;
          
          // Check if schedule matches current time and date and not executed
          if (schedule.time === currentTime && 
              schedule.date === currentDate && 
              schedule.executed === false) {
            
            console.log(`🎯 Executing schedule ${scheduleId} for device ${deviceId}`);
            console.log(`📋 Schedule details:`, schedule);
            
            try {
              // Update device status based on action
              const devicePath = `${householdUid}/${deviceId}`;
              
              if (schedule.door) {
                // PARCEL BOX - Use door-specific status
                const doorPath = schedule.door === 'Inside' ? 'insideStatus' : 'outsideStatus';
                const status = schedule.action === 'Unlock';
                
                console.log(`🚪 PARCEL BOX - Door: ${schedule.door}, Action: ${schedule.action}, Setting ${doorPath} to: ${status}`);
                
                await db.ref(`${devicePath}/${doorPath}`).set(status);
                console.log(`✅ Updated ${devicePath}/${doorPath} = ${status}`);
                
                // Verify the update worked
                const verifySnapshot = await db.ref(`${devicePath}/${doorPath}`).once('value');
                console.log(`🔍 VERIFICATION: ${devicePath}/${doorPath} is now: ${verifySnapshot.val()}`);
                
              } else {
                // CLOTHES HANGER - Use both status fields
                const status = schedule.action === 'Extend';
                
                console.log(`📏 CLOTHES HANGER - Action: ${schedule.action}, Setting both insideStatus and outsideStatus to: ${status}`);
                
                // Update both fields for clothes hanger
                await db.ref(`${devicePath}/insideStatus`).set(status);
                await db.ref(`${devicePath}/outsideStatus`).set(status);
                console.log(`✅ Updated ${devicePath}/insideStatus = ${status}`);
                console.log(`✅ Updated ${devicePath}/outsideStatus = ${status}`);
                
                // Verify the updates worked
                const verifyInside = await db.ref(`${devicePath}/insideStatus`).once('value');
                const verifyOutside = await db.ref(`${devicePath}/outsideStatus`).once('value');
                console.log(`🔍 VERIFICATION: insideStatus: ${verifyInside.val()}, outsideStatus: ${verifyOutside.val()}`);
              }
              
              // Mark schedule as executed
              const executedTime = new Date().toISOString();
              await db.ref(`${devicePath}/schedules/${scheduleId}`).update({
                executed: true,
                executedAt: executedTime
              });
              
              console.log(`✅ Marked schedule ${scheduleId} as executed`);
              
              totalExecuted++;
              
            } catch (error) {
              console.error(`❌ Error executing schedule ${scheduleId}:`, error);
            }
          }
        }
      }
    }
    
    console.log(`📊 Checked ${totalChecked} schedules, Executed ${totalExecuted} schedules`);
    
    if (totalExecuted === 0) {
      console.log('ℹ️ No schedules to execute at this time');
    }
    
  } catch (error) {
    console.error('❌ Error in schedule check:', error);
    throw error;
  }
});

// ============================================================================
// TEST FUNCTION - Manual device control for testing
// ============================================================================

/**
 * Manual test function to verify device control
 * Usage: Call via HTTP to test device status updates
 */
exports.testDeviceControl = require('firebase-functions').https.onRequest(async (req, res) => {
  try {
    const { householdUid, deviceId, action, door } = req.query;
    
    if (!householdUid || !deviceId || !action) {
      return res.status(400).json({
        error: 'Missing required parameters: householdUid, deviceId, action'
      });
    }
    
    console.log(`🧪 Manual test: ${householdUid}/${deviceId} - ${action} ${door ? `(${door})` : ''}`);
    
    const devicePath = `${householdUid}/${deviceId}`;
    
    if (door) {
      // Parcel Box test
      const doorPath = door === 'Inside' ? 'insideStatus' : 'outsideStatus';
      const status = action === 'Unlock';
      
      await db.ref(`${devicePath}/${doorPath}`).set(status);
      console.log(`✅ Set ${devicePath}/${doorPath} = ${status}`);
      
    } else {
      // Clothes Hanger test
      const status = action === 'Extend';
      
      await db.ref(`${devicePath}/insideStatus`).set(status);
      await db.ref(`${devicePath}/outsideStatus`).set(status);
      console.log(`✅ Set both status fields = ${status}`);
    }
    
    res.json({
      success: true,
      message: `Device control test completed: ${action} ${door ? `(${door})` : ''}`,
      path: devicePath,
      status: action === 'Unlock' || action === 'Extend'
    });
    
  } catch (error) {
    console.error('❌ Test function error:', error);
    res.status(500).json({
      error: 'Test failed',
      details: error.message
    });
  }
});

// ============================================================================
// CLEANUP FUNCTION - Remove old executed schedules
// ============================================================================

/**
 * Cleanup function to remove old executed schedules (older than 30 days)
 * Runs once per day to keep database clean
 */
exports.cleanupOldSchedules = onSchedule({
  schedule: '0 2 * * *', // 2 AM daily
  timeZone: 'Asia/Kuala_Lumpur',
  region: 'asia-southeast1'
}, async (event) => {
  try {
    console.log('🧹 Cleaning up old executed schedules...');
    
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const cutoffDate = thirtyDaysAgo.toISOString().split('T')[0]; // YYYY-MM-DD
    
    console.log(`🗑️ Removing schedules older than: ${cutoffDate}`);
    
    const householdsSnapshot = await db.ref('/').once('value');
    const households = householdsSnapshot.val() || {};
    
    let totalRemoved = 0;
    
    for (const [householdUid, householdData] of Object.entries(households)) {
      if (typeof householdData !== 'object') continue;
      
      for (const [deviceId, deviceData] of Object.entries(householdData)) {
        if (!deviceData.schedules) continue;
        
        const schedules = deviceData.schedules;
        const devicePath = `${householdUid}/${deviceId}`;
        
        for (const [scheduleId, schedule] of Object.entries(schedules)) {
          // Remove if executed and older than 30 days
          if (schedule.executed === true && schedule.date < cutoffDate) {
            await db.ref(`${devicePath}/schedules/${scheduleId}`).remove();
            console.log(`🗑️ Removed old schedule: ${scheduleId} (${schedule.date})`);
            totalRemoved++;
          }
        }
      }
    }
    
    console.log(`✅ Cleanup completed: Removed ${totalRemoved} old schedules`);
    
  } catch (error) {
    console.error('❌ Cleanup error:', error);
  }
});