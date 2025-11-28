const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// ============================================================================
// HTTP FUNCTIONS
// ============================================================================

/**
 * Simple Hello World endpoint
 * URL: https://asia-southeast1-smahorz-fyp.cloudfunctions.net/helloWorld
 */
exports.helloWorld = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    response.json({ 
      message: 'Hello from Firebase Functions v2!',
      timestamp: new Date().toISOString(),
      region: 'asia-southeast1'
    });
  } catch (error) {
    console.error('Error in helloWorld:', error);
    response.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Custom API endpoint with CORS and multiple HTTP methods
 * URL: https://asia-southeast1-smahorz-fyp.cloudfunctions.net/api
 */
exports.api = onRequest({
  region: 'asia-southeast1'
}, async (request, response) => {
  try {
    // Enable CORS
    response.set('Access-Control-Allow-Origin', '*');
    
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
      response.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      response.set('Access-Control-Max-Age', '3600');
      response.status(204).send('');
      return;
    }
    
    // Handle different HTTP methods
    switch (request.method) {
      case 'GET':
        // Example: Get data from Firestore
        const snapshot = await admin.firestore()
          .collection('status')
          .doc('api')
          .get();
        
        response.json({ 
          status: 'success', 
          message: 'API is working!',
          timestamp: new Date().toISOString(),
          data: snapshot.exists ? snapshot.data() : null
        });
        break;
        
      case 'POST':
        const data = request.body;
        
        // Validate request body
        if (!data || Object.keys(data).length === 0) {
          response.status(400).json({ 
            error: 'Bad request',
            message: 'Request body is required'
          });
          return;
        }
        
        // Example: Save data to Firestore
        await admin.firestore()
          .collection('api_logs')
          .add({
            data: data,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            ip: request.ip
          });
        
        response.json({ 
          status: 'success', 
          received: data,
          message: 'Data received and saved successfully!'
        });
        break;
        
      case 'PUT':
        response.json({ 
          status: 'success', 
          message: 'PUT request received'
        });
        break;
        
      case 'DELETE':
        response.json({ 
          status: 'success', 
          message: 'DELETE request received'
        });
        break;
        
      default:
        response.status(405).json({ 
          error: 'Method not allowed',
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE']
        });
    }
  } catch (error) {
    console.error('Error in API endpoint:', error);
    response.status(500).json({ 
      error: 'Internal server error',
      message: error.message 
    });
  }
});

// ============================================================================
// SCHEDULED FUNCTIONS
// ============================================================================

/**
 * Runs every 5 minutes
 * Cron schedule: "every 5 minutes"
 */
exports.scheduledTask = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'Asia/Kuala_Lumpur',
  region: 'asia-southeast1',
  retryCount: 3,
  memory: '256MiB'
}, async (event) => {
  try {
    console.log('Scheduled task running...');
    const timestamp = new Date().toISOString();
    console.log('Executed at:', timestamp);
    
    // Example: Update a status document
    await admin.firestore()
      .collection('status')
      .doc('scheduler')
      .set({
        lastRun: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
        message: 'Scheduled task executed successfully'
      }, { merge: true });
    
    console.log('Scheduled task completed successfully');
  } catch (error) {
    console.error('Error in scheduled task:', error);
    throw error;
  }
});

/**
 * Daily cleanup task - runs every 24 hours at midnight (Malaysia time)
 * Cron schedule: "0 0 * * *"
 */
exports.dailyCleanup = onSchedule({
  schedule: '0 0 * * *',
  timeZone: 'Asia/Kuala_Lumpur',
  region: 'asia-southeast1',
  retryCount: 2,
  memory: '512MiB'
}, async (event) => {
  try {
    console.log('Running daily cleanup task...');
    
    // Example: Delete old logs (older than 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const oldLogsSnapshot = await admin.firestore()
      .collection('api_logs')
      .where('timestamp', '<', thirtyDaysAgo)
      .limit(500)
      .get();
    
    if (oldLogsSnapshot.empty) {
      console.log('No old logs to delete');
      return;
    }
    
    // Delete in batch
    const batch = admin.firestore().batch();
    oldLogsSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`Deleted ${oldLogsSnapshot.size} old log entries`);
    
    await admin.firestore()
      .collection('status')
      .doc('cleanup')
      .set({
        lastRun: admin.firestore.FieldValue.serverTimestamp(),
        deletedCount: oldLogsSnapshot.size,
        status: 'completed'
      }, { merge: true });
    
  } catch (error) {
    console.error('Error in daily cleanup:', error);
    throw error;
  }
});

/**
 * Weekly report - runs every Monday at 9 AM (Malaysia time)
 * Cron schedule: "0 9 * * 1"
 */
exports.weeklyReport = onSchedule({
  schedule: '0 9 * * 1',
  timeZone: 'Asia/Kuala_Lumpur',
  region: 'asia-southeast1',
  memory: '512MiB'
}, async (event) => {
  try {
    console.log('Generating weekly report...');
    
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('createdAt', '>=', oneWeekAgo)
      .get();
    
    const report = {
      weekStart: oneWeekAgo,
      weekEnd: new Date(),
      newUsers: usersSnapshot.size,
      generatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await admin.firestore()
      .collection('reports')
      .doc('weekly')
      .collection('history')
      .add(report);
    
    console.log('Weekly report generated:', report);
    
  } catch (error) {
    console.error('Error generating weekly report:', error);
    throw error;
  }
});

// ============================================================================
// FIRESTORE TRIGGERS
// ============================================================================

/**
 * Triggered when a new user document is created
 * Path: users/{userId}
 * 
 * This trigger handles user initialization when a document is created
 * in the users collection. You should create the user document from your
 * client app after Firebase Authentication signup.
 */
exports.onUserDataCreated = onDocumentCreated({
  document: 'users/{userId}',
  region: 'asia-southeast1'
}, async (event) => {
  try {
    const snapshot = event.data;
    if (!snapshot) {
      console.log('No data associated with the event');
      return;
    }
    
    const userId = event.params.userId;
    const userData = snapshot.data();
    
    console.log('New user data created:', userId, userData);
    
    // Example: Initialize user settings
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc('preferences')
      .set({
        theme: 'light',
        notifications: true,
        language: 'en',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    
    // Example: Add to analytics
    await admin.firestore()
      .collection('analytics')
      .doc('users')
      .set({
        totalUsers: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    
    console.log('User initialization completed for:', userId);
    
  } catch (error) {
    console.error('Error in onUserDataCreated:', error);
    throw error;
  }
});

/**
 * Triggered when a user document is updated
 * Path: users/{userId}
 */
exports.onUserDataUpdated = onDocumentUpdated({
  document: 'users/{userId}',
  region: 'asia-southeast1'
}, async (event) => {
  try {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const userId = event.params.userId;
    
    console.log('User data updated:', userId);
    console.log('Before:', beforeData);
    console.log('After:', afterData);
    
    // Example: Track specific field changes
    if (beforeData.email !== afterData.email) {
      console.log('Email changed from', beforeData.email, 'to', afterData.email);
      
      // Log the change
      await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('audit_log')
        .add({
          field: 'email',
          oldValue: beforeData.email,
          newValue: afterData.email,
          changedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
    
  } catch (error) {
    console.error('Error in onUserDataUpdated:', error);
    throw error;
  }
});

/**
 * Triggered when a user document is deleted
 * Path: users/{userId}
 */
exports.onUserDataDeleted = onDocumentDeleted({
  document: 'users/{userId}',
  region: 'asia-southeast1'
}, async (event) => {
  try {
    const deletedData = event.data.data();
    const userId = event.params.userId;
    
    console.log('User data deleted:', userId, deletedData);
    
    // Example: Clean up related data
    const settingsSnapshot = await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('settings')
      .get();
    
    const batch = admin.firestore().batch();
    settingsSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    
    // Update analytics
    await admin.firestore()
      .collection('analytics')
      .doc('users')
      .set({
        totalUsers: admin.firestore.FieldValue.increment(-1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    
    console.log('Cleanup completed for deleted user:', userId);
    
  } catch (error) {
    console.error('Error in onUserDataDeleted:', error);
    throw error;
  }
});

/**
 * Triggered when a document is created in any collection
 * You can customize the path pattern to match your needs
 */
exports.onTaskCreated = onDocumentCreated({
  document: 'tasks/{taskId}',
  region: 'asia-southeast1'
}, async (event) => {
  try {
    const taskData = event.data.data();
    const taskId = event.params.taskId;
    
    console.log('New task created:', taskId, taskData);
    
    // Example: Send notification about new task
    // You could integrate with FCM, email service, etc.
    
  } catch (error) {
    console.error('Error in onTaskCreated:', error);
    throw error;
  }
});

// ============================================================================
// CALLABLE FUNCTIONS (Can be called from client apps)
// ============================================================================

/**
 * Get user data - callable from client
 * 
 * Client usage (JavaScript):
 * const response = await fetch('https://asia-southeast1-smahorz-fyp.cloudfunctions.net/getUserData', {
 *   method: 'POST',
 *   headers: { 'Content-Type': 'application/json' },
 *   body: JSON.stringify({ userId: 'abc123' })
 * });
 */
exports.getUserData = onRequest({
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
      response.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    const { userId } = request.body;
    
    if (!userId) {
      response.status(400).json({ error: 'userId is required' });
      return;
    }
    
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userDoc.exists) {
      response.status(404).json({ error: 'User not found' });
      return;
    }
    
    response.json({
      success: true,
      data: userDoc.data()
    });
    
  } catch (error) {
    console.error('Error getting user data:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Create user profile - should be called from client after Firebase Auth signup
 * 
 * Client usage (JavaScript):
 * // After Firebase Auth signup
 * const user = await firebase.auth().createUserWithEmailAndPassword(email, password);
 * 
 * // Call this function to create Firestore profile
 * await fetch('https://asia-southeast1-smahorz-fyp.cloudfunctions.net/createUserProfile', {
 *   method: 'POST',
 *   headers: { 'Content-Type': 'application/json' },
 *   body: JSON.stringify({
 *     userId: user.user.uid,
 *     email: user.user.email,
 *     displayName: displayName
 *   })
 * });
 */
exports.createUserProfile = onRequest({
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
      response.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    const { userId, email, displayName, photoURL } = request.body;
    
    if (!userId || !email) {
      response.status(400).json({ error: 'userId and email are required' });
      return;
    }
    
    // Create user document
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .set({
        uid: userId,
        email: email,
        displayName: displayName || null,
        photoURL: photoURL || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        role: 'user',
        status: 'active'
      });
    
    response.json({
      success: true,
      message: 'User profile created successfully'
    });
    
  } catch (error) {
    console.error('Error creating user profile:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Update user profile
 */
exports.updateUserProfile = onRequest({
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
      response.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    const { userId, updates } = request.body;
    
    if (!userId || !updates) {
      response.status(400).json({ error: 'userId and updates are required' });
      return;
    }
    
    // Update user document
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        ...updates,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    
    response.json({
      success: true,
      message: 'User profile updated successfully'
    });
    
  } catch (error) {
    console.error('Error updating user profile:', error);
    response.status(500).json({ error: error.message });
  }
});

/**
 * Cleanup old images from Firebase Storage
 * Runs daily at 2 AM Malaysia time
 * Deletes images older than 90 days
 */
exports.cleanupOldImages = onSchedule({
  schedule: '0 2 * * *',
  timeZone: 'Asia/Kuala_Lumpur',
  region: 'asia-southeast1',
  memory: '512MiB'
}, async (event) => {
  try {
    console.log('Running image cleanup task...');
    const bucket = admin.storage().bucket();
    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);
    
    // Get old image metadata from Firestore
    const oldImages = await admin.firestore()
      .collection('images')
      .where('createdAt', '<', ninetyDaysAgo)
      .limit(100) // Process in batches to avoid timeout
      .get();
    
    if (oldImages.empty) {
      console.log('No old images to delete');
      return;
    }
    
    let deletedCount = 0;
    
    for (const doc of oldImages.docs) {
      try {
        const imagePath = doc.data().storagePath;
        
        // Delete from Storage
        await bucket.file(imagePath).delete();
        
        // Delete metadata from Firestore
        await doc.ref.delete();
        
        deletedCount++;
        console.log('Deleted old image:', imagePath);
      } catch (err) {
        console.error('Error deleting image:', doc.id, err);
      }
    }
    
    console.log(`Cleanup completed. Deleted ${deletedCount} images`);
    
    // Log cleanup status
    await admin.firestore()
      .collection('status')
      .doc('image_cleanup')
      .set({
        lastRun: admin.firestore.FieldValue.serverTimestamp(),
        deletedCount: deletedCount,
        status: 'completed'
      }, { merge: true });
    
  } catch (error) {
    console.error('Error in image cleanup:', error);
    throw error;
  }
});