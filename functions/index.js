const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Get Realtime Database reference
const db = admin.database();

// ============================================================================
// SIMPLE SCHEDULE SYSTEM - Everything in Realtime Database
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
    console.log('🔔 Checking scheduled tasks...');

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

    console.log(`Current time: ${currentTime}, Current date: ${currentDate}`);

    // Get all households
    const householdsSnapshot = await db.ref('/').once('value');
    const households = householdsSnapshot.val() || {};

    let totalExecuted = 0;

    for (const [householdUid, householdData] of Object.entries(households)) {
      // Skip if not a household (could be other data)
      if (typeof householdData !== 'object') continue;

      for (const [deviceId, deviceData] of Object.entries(householdData)) {
        // Skip if device has no schedules
        if (!deviceData.schedules) continue;

        const schedules = deviceData.schedules;

        for (const [scheduleId, schedule] of Object.entries(schedules)) {
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
                const status = schedule.action === 'Lock';

                await db.ref(`${devicePath}/${doorPath}`).set(status);
                console.log(`✅ Updated ${devicePath}/${doorPath} = ${status}`);
              } else {
                // Clothes Hanger - update only status field
                const status = schedule.action === 'Extend';

                await db.ref(`${devicePath}/status`).set(status);
                console.log(`✅ Updated ${devicePath}/status = ${status}`);
              }

              // Mark schedule as executed
              await db.ref(`${devicePath}/schedules/${scheduleId}/executed`).set(true);
              await db.ref(`${devicePath}/schedules/${scheduleId}/executedAt`).set(new Date().toISOString());

              totalExecuted++;

            } catch (error) {
              console.error(`❌ Error executing schedule ${scheduleId}:`, error);
            }
          }
        }
      }
    }

    console.log(`✅ Executed ${totalExecuted} schedules`);

  } catch (error) {
    console.error('❌ Error in schedule check:', error);
    throw error;
  }
});