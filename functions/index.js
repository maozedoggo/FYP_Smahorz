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
            
            console.log(`🎯 Executing schedule ${scheduleId} for device ${deviceId}: ${schedule.action}`);
            
            try {
              // Update device status based on action
              const devicePath = `${householdUid}/${deviceId}`;
              
              if (schedule.door) {
                // Parcel Box - has door selection
                const doorPath = schedule.door === 'Inside' ? 'insideStatus' : 'outsideStatus';
                const status = schedule.action === 'Unlock';
                
                await db.ref(`${devicePath}/${doorPath}`).set(status);
                console.log(`✅ Updated ${devicePath}/${doorPath} = ${status} (${schedule.action})`);
              } else {
                // Clothes Hanger - simple status
                const status = schedule.action === 'Extend';
                
                await db.ref(`${devicePath}/status`).set(status);
                console.log(`✅ Updated ${devicePath}/status = ${status} (${schedule.action})`);
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