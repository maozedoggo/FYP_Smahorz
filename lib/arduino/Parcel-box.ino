#include <WiFi.h>
#include <FirebaseESP32.h>

// WiFi settings
char ssid[] = "Huawei-B5076";
char pass[] = "Saitama123";

// Firebase settings
#define FIREBASE_HOST "smahorz-fyp-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "JZlAMaa3q6qfszbvlTUxdH2AUola52ZPhkoF3Efi"

// Pin Definitions
#define RELAY1_PIN 16  // Inside door solenoid
#define RELAY2_PIN 17  // Outside door solenoid  
#define LED_PIN    5   // LED indicator
#define LDR_PIN    34  // Light sensor
#define BUZZER_PIN 18  // Buzzer for feedback

// Firebase - TWO data objects for dual streams
FirebaseData fbDataInside;
FirebaseData fbDataOutside;
FirebaseConfig config;
FirebaseAuth auth;

// Device ID
String deviceId = "iCAN1cVZ7gPzbR6D3mhH";

// Household ID - Will be discovered dynamically
String householdId = "";
bool householdFound = false;

// ===========================================================================
// STATE MANAGEMENT
// ===========================================================================
bool insideDoorState = false;
bool outsideDoorState = false;
bool ledState = false;

// Door timing
unsigned long doorUnlockTime = 0;
const unsigned long DOOR_UNLOCK_DURATION = 10000;

// ===========================================================================
// CONNECTION STATUS VARIABLES (FROM ORIGINAL CODE)
// ===========================================================================
bool wasConnected = false;
unsigned long lastConnectionCheck = 0;
const unsigned long CONNECTION_CHECK_INTERVAL = 5000; // Check every 5 seconds

// Stream monitoring
unsigned long lastStreamCheck = 0;
const unsigned long STREAM_CHECK_INTERVAL = 2000;
bool insideStreamConnected = false;
bool outsideStreamConnected = false;
unsigned long lastReconnectAttempt = 0;
const unsigned long RECONNECT_INTERVAL = 3000;

// Household discovery
unsigned long searchStartTime = 0;
const unsigned long SEARCH_TIMEOUT = 30000; // 30 seconds
unsigned long lastHouseholdCheck = 0;
const unsigned long HOUSEHOLD_CHECK_INTERVAL = 30000; // Check every 30 seconds

// Light sensor timing
unsigned long lastLDRCheck = 0;
const unsigned long LDR_CHECK_INTERVAL = 1000;

// ===========================================================================
// FUNCTION DECLARATIONS (FOLLOWING ORIGINAL STRUCTURE)
// ===========================================================================
void connectWiFi();
void connectFirebase();
void findHouseholdForDevice();
bool searchAllHouseholds();
void createRealtimeDBStructure();
void setupDualStreamListeners();
void checkAndUpdateConnectionStatus();
void updateConnectionStatus(bool connected);
void syncWithDatabaseState();
void checkStreamConnections();
void processDualStreams();
void setInsideDoor(bool state);
void setOutsideDoor(bool state);
void checkDoorTimeouts();
void updateLEDFromLDR();
void beep(int count);

void setup() {
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("=== SMART PARCEL BOX SYSTEM ===");
  Serial.println("Device ID: " + deviceId);
  
  // Setup pins
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(LDR_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  
  // Start with everything OFF for safety
  digitalWrite(RELAY1_PIN, LOW);
  digitalWrite(RELAY2_PIN, LOW);
  digitalWrite(LED_PIN, LOW);
  digitalWrite(BUZZER_PIN, LOW);
  
  // Connect to WiFi (using original function structure)
  connectWiFi();
  
  // Connect to Firebase (using original function structure)
  connectFirebase();
  
  // Find our household dynamically (following original pattern)
  findHouseholdForDevice();
  
  if (householdFound) {
    Serial.println("✓ Household found: " + householdId);
    
    // Create initial structure
    createRealtimeDBStructure();
    
    // CRITICAL: SYNC WITH DATABASE STATE FIRST
    syncWithDatabaseState();
    
    // Setup DUAL STREAM listeners for both doors
    setupDualStreamListeners();
    
    // Update connection status to true (following original pattern)
    updateConnectionStatus(true);
    wasConnected = true;
    
    Serial.println("=== SYSTEM READY - DATABASE SYNCED ===");
    Serial.println("Listening paths:");
    Serial.println("1. /" + householdId + "/" + deviceId + "/insideStatus");
    Serial.println("2. /" + householdId + "/" + deviceId + "/outsideStatus");
  } else {
    Serial.println("✗ Could not find household for this device!");
    Serial.println("Please add this device to a household in Firebase.");
    Serial.println("Device ID: " + deviceId);
    Serial.println("\nExpected structure in Firebase:");
    Serial.println("{householdId}/{deviceId}/insideStatus");
    Serial.println("{householdId}/{deviceId}/outsideStatus");
    
    // Blink LED to indicate waiting for registration
    while (true) {
      Serial.println("Waiting for household assignment...");
      digitalWrite(LED_PIN, HIGH);
      delay(500);
      digitalWrite(LED_PIN, LOW);
      delay(4500);
    }
  }
  
  beep(1);
}

void connectWiFi() {
  Serial.println("Attempting to connect to WiFi...");
  Serial.println("SSID: " + String(ssid));
  
  WiFi.begin(ssid, pass);
  
  unsigned long startTime = millis();
  bool connected = false;
  
  while (millis() - startTime < 30000) {
    if (WiFi.status() == WL_CONNECTED) {
      connected = true;
      break;
    }
    Serial.print(".");
    delay(500);
  }
  
  if (connected) {
    Serial.println("\n✓ WiFi Connected!");
    Serial.println("IP Address: " + WiFi.localIP().toString());
  } else {
    Serial.println("\n✗ WiFi Connection FAILED!");
    while (true) {
      Serial.println("System halted - check WiFi connection");
      delay(5000);
    }
  }
}

void connectFirebase() {
  Serial.println("Connecting to Firebase...");
  
  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  config.timeout.serverResponse = 30 * 1000;
  config.timeout.sslHandshake = 30 * 1000;
  config.timeout.socketConnection = 30 * 1000;
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  delay(2000);
  
  if (Firebase.ready()) {
    Serial.println("✓ Firebase Connected and Ready!");
  } else {
    Serial.println("✗ Firebase Connection Failed!");
    Serial.println("Error: " + fbDataInside.errorReason());
  }
}

void findHouseholdForDevice() {
  if (!Firebase.ready()) {
    Serial.println("Firebase not ready for household search");
    return;
  }
  
  Serial.println("Searching for household for device: " + deviceId);
  Serial.println("This may take a moment...");
  
  searchStartTime = millis();
  
  // Search through all households (following original pattern)
  searchAllHouseholds();
}

bool searchAllHouseholds() {
  // Get all households from root
  Serial.println("Searching all households...");
  
  if (Firebase.getJSON(fbDataInside, "/")) {
    FirebaseJson *json = fbDataInside.jsonObjectPtr();
    size_t len = json->iteratorBegin();
    
    String key, value = "";
    int type = 0;
    int householdCount = 0;
    
    for (size_t i = 0; i < len; i++) {
      if (millis() - searchStartTime > SEARCH_TIMEOUT) {
        Serial.println("Search timeout reached");
        break;
      }
      
      json->iteratorGet(i, type, key, value);
      
      // Skip known system nodes (like in original code)
      if (key.length() == 0 || key == ".info" || key == ".settings") {
        continue;
      }
      
      householdCount++;
      if (householdCount % 5 == 0) {
        Serial.print("Checked ");
        Serial.print(householdCount);
        Serial.println(" households...");
      }
      
      // Check if this household has our device ID
      String deviceCheckPath = key + "/" + deviceId;
      
      if (Firebase.getJSON(fbDataInside, deviceCheckPath)) {
        // Device found in this household!
        householdId = key;
        householdFound = true;
        Serial.println("✓ Device found in household #" + String(householdCount) + ": " + householdId);
        
        json->iteratorEnd();
        return true;
      }
      
      delay(100); // Small delay to avoid flooding Firebase
    }
    
    json->iteratorEnd();
  } else {
    Serial.println("Failed to get root data: " + fbDataInside.errorReason());
  }
  
  if (!householdFound) {
    Serial.println("✗ Device not found in any household");
    Serial.println("\nINSTRUCTIONS:");
    Serial.println("1. Go to your Firebase Realtime Database console");
    Serial.println("2. Add this structure:");
    Serial.println("   {householdId}/{deviceId}/insideStatus = false");
    Serial.println("   {householdId}/{deviceId}/outsideStatus = false");
    Serial.println("3. Replace {householdId} with your household ID");
    Serial.println("4. Replace {deviceId} with: " + deviceId);
  }
  
  return false;
}

void createRealtimeDBStructure() {
  if (!Firebase.ready() || !householdFound) {
    return;
  }
  
  String path = householdId + "/" + deviceId;
  Serial.println("Creating/updating structure at: " + path);
  
  // Set initial status if not exists
  Firebase.setBool(fbDataInside, path + "/insideStatus", insideDoorState);
  Firebase.setBool(fbDataInside, path + "/outsideStatus", outsideDoorState);
  
  // Add/update device info
  Firebase.setString(fbDataInside, path + "/type", "Parcel Box");
  Firebase.setString(fbDataInside, path + "/name", "Smart Parcel Box");
  Firebase.setString(fbDataInside, path + "/deviceId", deviceId);
  Firebase.setString(fbDataInside, path + "/lastSeen", String(millis()));
  
  Serial.println("✓ Device structure created/updated");
}

void syncWithDatabaseState() {
  if (!Firebase.ready() || !householdFound) return;
  
  Serial.println("Syncing with database state...");
  
  // Read inside door state from database
  String insidePath = householdId + "/" + deviceId + "/insideStatus";
  if (Firebase.getBool(fbDataInside, insidePath)) {
    bool dbInsideState = fbDataInside.boolData();
    if (dbInsideState != insideDoorState) {
      insideDoorState = dbInsideState;
      digitalWrite(RELAY1_PIN, dbInsideState ? HIGH : LOW);
      Serial.println("✓ Inside door synced: " + String(dbInsideState ? "UNLOCKED" : "LOCKED"));
    }
  } else {
    Serial.println("✗ Failed to read inside door state");
  }
  
  // Read outside door state from database
  String outsidePath = householdId + "/" + deviceId + "/outsideStatus";
  if (Firebase.getBool(fbDataOutside, outsidePath)) {
    bool dbOutsideState = fbDataOutside.boolData();
    if (dbOutsideState != outsideDoorState) {
      outsideDoorState = dbOutsideState;
      digitalWrite(RELAY2_PIN, dbOutsideState ? HIGH : LOW);
      Serial.println("✓ Outside door synced: " + String(dbOutsideState ? "UNLOCKED" : "LOCKED"));
    }
  } else {
    Serial.println("✗ Failed to read outside door state");
  }
  
  // If any door is unlocked, start the timer
  if (insideDoorState || outsideDoorState) {
    doorUnlockTime = millis();
    Serial.println("✓ Door unlock timer started");
  }
}

void setupDualStreamListeners() {
  if (!Firebase.ready() || !householdFound) return;
  
  String insidePath = householdId + "/" + deviceId + "/insideStatus";
  String outsidePath = householdId + "/" + deviceId + "/outsideStatus";
  
  // Start stream for INSIDE door
  if (Firebase.beginStream(fbDataInside, insidePath)) {
    Serial.println("✓ Inside door stream started");
    insideStreamConnected = true;
  } else {
    Serial.println("✗ Inside stream failed: " + fbDataInside.errorReason());
  }
  
  // Start stream for OUTSIDE door
  if (Firebase.beginStream(fbDataOutside, outsidePath)) {
    Serial.println("✓ Outside door stream started");
    outsideStreamConnected = true;
  } else {
    Serial.println("✗ Outside stream failed: " + fbDataOutside.errorReason());
  }
  
  lastStreamCheck = millis();
}

// ===========================================================================
// HEARTBEAT/CONNECTION MONITORING FUNCTION (EXACTLY FROM ORIGINAL CODE)
// ===========================================================================
void checkAndUpdateConnectionStatus() {
  unsigned long currentTime = millis();
  
  // Check connection status periodically (5 second interval from original)
  if (currentTime - lastConnectionCheck >= CONNECTION_CHECK_INTERVAL) {
    lastConnectionCheck = currentTime;
    
    if (householdFound) {
      bool isCurrentlyConnected = (WiFi.status() == WL_CONNECTED && Firebase.ready());
      
      // Only update if connection status changed
      if (isCurrentlyConnected != wasConnected) {
        if (isCurrentlyConnected) {
          Serial.println("🔗 Device reconnected to network");
        } else {
          Serial.println("🔌 Device disconnected from network");
        }
        
        // Update connection status in Firebase
        updateConnectionStatus(isCurrentlyConnected);
      }
    }
  }
}

// ===========================================================================
// UPDATE CONNECTION STATUS FUNCTION (FROM ORIGINAL CODE)
// ===========================================================================
void updateConnectionStatus(bool connected) {
  if (householdFound && Firebase.ready()) {
    String path = householdId + "/" + deviceId + "/connectionStatus";
    
    // Try to update connection status (exact same logic as original)
    if (Firebase.setBool(fbDataInside, path, connected)) {
      Serial.println("📡 Connection status updated to: " + String(connected ? "ONLINE" : "OFFLINE"));
      wasConnected = connected;
    } else {
      Serial.println("Failed to update connection status: " + fbDataInside.errorReason());
    }
  }
}

void loop() {
  unsigned long currentTime = millis();
  
  // Check if we need to rediscover household ID
  if (!householdFound && currentTime - lastHouseholdCheck > HOUSEHOLD_CHECK_INTERVAL) {
    Serial.println("🔄 Attempting to discover household ID...");
    findHouseholdForDevice();
    
    if (householdFound) {
      // Setup listener now that we have household ID
      syncWithDatabaseState();
      setupDualStreamListeners();
      updateConnectionStatus(true);
      wasConnected = true;
    }
    
    lastHouseholdCheck = currentTime;
  }
  
  // 1. HEARTBEAT: Check and update connection status (from original code)
  checkAndUpdateConnectionStatus();
  
  // 2. HIGHEST PRIORITY: Door timeouts
  checkDoorTimeouts();
  
  // 3. Stream monitoring
  if (currentTime - lastStreamCheck > STREAM_CHECK_INTERVAL) {
    checkStreamConnections(currentTime);
    lastStreamCheck = currentTime;
  }
  
  // 4. PROCESS BOTH STREAMS
  processDualStreams();
  
  // 5. Light sensor (LOW PRIORITY - local only)
  if (currentTime - lastLDRCheck > LDR_CHECK_INTERVAL) {
    updateLEDFromLDR();
    lastLDRCheck = currentTime;
  }
  
  delay(10);
}

void checkStreamConnections(unsigned long currentTime) {
  if ((!insideStreamConnected || !outsideStreamConnected) && Firebase.ready() && householdFound) {
    if (currentTime - lastReconnectAttempt > RECONNECT_INTERVAL) {
      Serial.println("Reconnecting streams...");
      setupDualStreamListeners();
      lastReconnectAttempt = currentTime;
    }
  }
}

void processDualStreams() {
  // PROCESS INSIDE DOOR STREAM
  if (insideStreamConnected && Firebase.ready() && householdFound) {
    if (!Firebase.readStream(fbDataInside)) {
      Serial.println("✗ Inside stream read error: " + fbDataInside.errorReason());
      
      if (fbDataInside.httpCode() != 200) {
        Serial.println("Restarting inside stream...");
        setupDualStreamListeners();
      }
      return;
    }

    if (fbDataInside.streamAvailable()) {
      if (fbDataInside.dataType() == "boolean") {
        bool value = fbDataInside.boolData();
        if (value != insideDoorState) {
          setInsideDoor(value);
        }
      } else {
        Serial.println("Wrong data type for inside door: " + fbDataInside.dataType());
      }
    }
    
    if (fbDataInside.streamTimeout()) {
      Serial.println("Inside stream timeout detected");
      if (!fbDataInside.httpConnected()) {
        Serial.println("Inside HTTP disconnected, restarting stream...");
        setupDualStreamListeners();
      }
    }
  }
  
  // PROCESS OUTSIDE DOOR STREAM
  if (outsideStreamConnected && Firebase.ready() && householdFound) {
    if (!Firebase.readStream(fbDataOutside)) {
      Serial.println("✗ Outside stream read error: " + fbDataOutside.errorReason());
      
      if (fbDataOutside.httpCode() != 200) {
        Serial.println("Restarting outside stream...");
        setupDualStreamListeners();
      }
      return;
    }

    if (fbDataOutside.streamAvailable()) {
      if (fbDataOutside.dataType() == "boolean") {
        bool value = fbDataOutside.boolData();
        if (value != outsideDoorState) {
          setOutsideDoor(value);
        }
      } else {
        Serial.println("Wrong data type for outside door: " + fbDataOutside.dataType());
      }
    }
    
    if (fbDataOutside.streamTimeout()) {
      Serial.println("Outside stream timeout detected");
      if (!fbDataOutside.httpConnected()) {
        Serial.println("Outside HTTP disconnected, restarting stream...");
        setupDualStreamListeners();
      }
    }
  }
}

void setInsideDoor(bool state) {
  if (state != insideDoorState) {
    insideDoorState = state;
    digitalWrite(RELAY1_PIN, state ? HIGH : LOW);
    
    // Immediate minimal feedback
    digitalWrite(BUZZER_PIN, HIGH);
    delay(20);
    digitalWrite(BUZZER_PIN, LOW);
    
    if (state) {
      doorUnlockTime = millis();
    }
    
    Serial.println("INSIDE: " + String(state ? "UNLOCKED" : "LOCKED"));
  }
}

void setOutsideDoor(bool state) {
  if (state != outsideDoorState) {
    outsideDoorState = state;
    digitalWrite(RELAY2_PIN, state ? HIGH : LOW);
    
    // Immediate minimal feedback
    digitalWrite(BUZZER_PIN, HIGH);
    delay(20);
    digitalWrite(BUZZER_PIN, LOW);
    
    if (state) {
      doorUnlockTime = millis();
    }
    
    Serial.println("OUTSIDE: " + String(state ? "UNLOCKED" : "LOCKED"));
  }
}

void updateLEDFromLDR() {
  int ldrValue = analogRead(LDR_PIN);
  
  // Simple local control - dark = LED on, light = LED off
  bool newLedState = (ldrValue < 2700); // Adjust threshold as needed
  
  if (newLedState != ledState) {
    ledState = newLedState;
    digitalWrite(LED_PIN, ledState ? HIGH : LOW);
  }
}

void checkDoorTimeouts() {
  if (doorUnlockTime > 0 && millis() - doorUnlockTime > DOOR_UNLOCK_DURATION) {
    if (insideDoorState) {
      setInsideDoor(false);
    }
    if (outsideDoorState) {
      setOutsideDoor(false);
    }
    doorUnlockTime = 0;
  }
}

void beep(int count) {
  for (int i = 0; i < count; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(30);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < count - 1) delay(30);
  }
}