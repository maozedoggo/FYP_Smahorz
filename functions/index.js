const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Schedule checker that runs every minute
exports.checkSchedules = functions.pubsub.schedule("* * * * *")
    .onRun(async (context) => {
      const now = new Date();

      // Get current time in HH:MM format (24-hour)
      const currentTime = now.toLocaleTimeString("en-US", {
        hour12: false,
        hour: "2-digit",
        minute: "2-digit",
      });

      // Get current date in YYYY-MM-DD format
      const currentDate = now.toISOString().split("T")[0];

      console.log(`Checking schedules for ${currentDate} at ${currentTime}`);

      try {
        // Get all households
        const householdsSnapshot = await admin.firestore()
            .collection("households")
            .get();

        let totalExecuted = 0;

        // Check schedules for each household
        for (const householdDoc of householdsSnapshot.docs) {
          const householdId = householdDoc.id;

          // Get all devices in this household
          const devicesSnapshot = await admin.firestore()
              .collection("households")
              .doc(householdId)
              .collection("devices")
              .get();

          // Check schedules for each device
          for (const deviceDoc of devicesSnapshot.docs) {
            const deviceId = deviceDoc.id;
            const deviceData = deviceDoc.data();

            const executedCount = await checkDeviceSchedules(
                admin,
                householdId,
                deviceId,
                deviceData,
                currentDate,
                currentTime
            );

            totalExecuted += executedCount;
          }
        }

        console.log(`Executed ${totalExecuted} schedules across households`);
      } catch (error) {
        console.error("Error checking schedules:", error);
      }

      return null;
    });

/**
 * Check schedules for a specific device
 */
async function checkDeviceSchedules(
    admin, householdId, deviceId, deviceData, currentDate, currentTime
) {
  try {
    const schedulesSnapshot = await admin.firestore()
        .collection("households")
        .doc(householdId)
        .collection("devices")
        .doc(deviceId)
        .collection("schedules")
        .where("date", "==", currentDate)
        .where("time", "==", currentTime)
        .where("executed", "==", false)
        .get();

    if (schedulesSnapshot.empty) {
      return 0;
    }

    console.log(`Found ${schedulesSnapshot.size} schedules for ${deviceId}`);

    // Execute each schedule
    const promises = schedulesSnapshot.docs.map(async (doc) => {
      const schedule = doc.data();
      const scheduleId = doc.id;

      console.log("Executing schedule:", {
        scheduleId,
        deviceId,
        action: schedule.action,
        door: schedule.door,
        deviceType: schedule.deviceType,
      });

      // Update Realtime Database
      await executeSchedule(admin, householdId, deviceId, deviceData, schedule);

      // Mark schedule as executed
      return doc.ref.update({
        executed: true,
        executedAt: admin.firestore.FieldValue.serverTimestamp(),
        executedBy: "cloud-function",
      });
    });

    await Promise.all(promises);
    return schedulesSnapshot.size;
  } catch (error) {
    console.error(`Error checking schedules for ${deviceId}:`, error);
    return 0;
  }
}

/**
 * Execute a schedule by updating Realtime Database
 */
async function executeSchedule(admin, householdId, deviceId, deviceData, schedule) {
  const {action, door, deviceType} = schedule;
  const devicePath = `${householdId}/${deviceId}`;

  try {
    const db = admin.database();

    if (deviceType && deviceType.toLowerCase().includes("parcel")) {
      // Parcel Box - update specific door
      const doorPath = door === "Inside" ? "insideStatus" : "outsideStatus";
      const status = action === "Unlock";

      await db.ref(`${devicePath}/${doorPath}`).set(status);
      console.log(`Parcel Box: ${doorPath} = ${status}`);

      // Also update Firestore
      await updateFirestoreParcelStatus(admin, householdId, deviceId, door, status);
    } else if (deviceType &&
      (deviceType.toLowerCase().includes("hanger") ||
       deviceType.toLowerCase().includes("clothe"))) {
      // Clothes Hanger - update simple status
      const status = action === "Extend";

      await db.ref(`${devicePath}/status`).set(status);
      console.log(`Clothes Hanger: status = ${status}`);

      // Also update Firestore
      await updateFirestoreHangerStatus(admin, householdId, deviceId, status);
    }
  } catch (error) {
    console.error(`Error executing schedule for ${deviceId}:`, error);
    throw error;
  }
}

/**
 * Update Firestore status for parcel box
 */
async function updateFirestoreParcelStatus(
    admin, householdId, deviceId, door, status
) {
  try {
    const deviceRef = admin.firestore()
        .collection("households")
        .doc(householdId)
        .collection("devices")
        .doc(deviceId);

    const deviceDoc = await deviceRef.get();
    const currentData = deviceDoc.data() || {};
    const currentStatus = currentData.status ||
      {insideStatus: false, outsideStatus: false};

    const updatedStatus = {...currentStatus};
    if (door === "Inside") {
      updatedStatus.insideStatus = status;
    } else if (door === "Outside") {
      updatedStatus.outsideStatus = status;
    }

    await deviceRef.update({
      status: updatedStatus,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Error updating Firestore parcel status:", error);
  }
}

/**
 * Update Firestore status for clothes hanger
 */
async function updateFirestoreHangerStatus(admin, householdId, deviceId, status) {
  try {
    const deviceRef = admin.firestore()
        .collection("households")
        .doc(householdId)
        .collection("devices")
        .doc(deviceId);

    await deviceRef.update({
      status: status,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Error updating Firestore hanger status:", error);
  }
}