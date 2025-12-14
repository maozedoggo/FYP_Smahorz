#include <WiFi.h>
#include <FirebaseESP32.h>

// WiFi settings
char ssid[] = "Huawei-B5076";
char pass[] = "Saitama123";

// Firebase settings
#define FIREBASE_HOST "smahorz-fyp-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "JZlAMaa3q6qfszbvlTUxdH2AUola52ZPhkoF3Efi"

// Device ID - Unique to each ESP32
String deviceId = "Zc8QgHMBXPUYPKGpYU0c";

// Dynamic household ID
String householdId = "";
bool householdFound = false;

// Motor pins
int motorPin1 = 27;
int motorPin2 = 26;
int motorSpeedPin = 14;

// Rain sensor
int rainSensorPin = 33;

// Firebase
FirebaseData fbData;
FirebaseConfig config;
FirebaseAuth auth;

// Motor control
bool motorState = false;
bool rainDetected = false;
bool lastRainState = false;
int dutyCycle = 255;

// Timer variables
unsigned long motorStartTime = 0;
const unsigned long MOTOR_RUN_TIME = 3000;
bool motorTimerActive = false;
bool isReversing = false;

// Command tracking
bool lastFirebaseCommand = false;
bool commandExecuted = false;

// Current state tracking
bool currentExtendedState = false;

// Search variables
unsigned long searchStartTime = 0;
const unsigned long SEARCH_TIMEOUT = 30000; // 30 seconds

// Connection status tracking
bool wasConnected = false;
unsigned long lastConnectionCheck = 0;
const unsigned long CONNECTION_CHECK_INTERVAL = 5000; // Check every 5 seconds

// Function declarations
void connectWiFi();
void connectFirebase();
void findHouseholdForDevice();
void searchAllHouseholds();
void createRealtimeDBStructure();
void setupFirebaseListener();
void stopMotor();
void turnOnMotorForward();
void turnOnMotorReverse();
void checkMotorTimer();
void checkRainSensor();
void checkFirebaseCommands();
void updateLastSeen();
void updateConnectionStatus(bool connected);
void checkAndUpdateConnectionStatus();

void setup() {
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("=== SMART HORIZON HOME - CLOTHES HANGER ===");
  Serial.println("Device ID: " + deviceId);
  
  // Setup pins
  pinMode(motorPin1, OUTPUT);
  pinMode(motorPin2, OUTPUT);
  pinMode(motorSpeedPin, OUTPUT);
  pinMode(rainSensorPin, INPUT);
  
  // Stop motor initially
  stopMotor();
  
  // Connect to WiFi
  connectWiFi();
  
  // Connect to Firebase
  connectFirebase();
  
  // Find our household dynamically
  findHouseholdForDevice();
  
  if (householdFound) {
    Serial.println("✓ Household found: " + householdId);
    
    // Create initial structure
    createRealtimeDBStructure();
    
    // Setup Firebase listener
    setupFirebaseListener();
    
    // Update connection status to true
    updateConnectionStatus(true);
    
    Serial.println("=== SYSTEM READY ===");
    Serial.println("Listening path: /" + householdId + "/" + deviceId + "/status");
    Serial.println("Rain sensor monitoring active");
    Serial.println("Motor runs for " + String(MOTOR_RUN_TIME/1000) + "s then stops");
    Serial.println("STATE: " + String(currentExtendedState ? "EXTENDED" : "RETRACTED"));
  } else {
    Serial.println("✗ Could not find household for this device!");
    Serial.println("Please add this device to a household in Firebase.");
    Serial.println("Device ID: " + deviceId);
    Serial.println("\nExpected structure in Firebase:");
    Serial.println("{householdId}/{deviceId}/status");
    
    // Blink LED or similar to indicate waiting for registration
    while (true) {
      Serial.println("Waiting for household assignment...");
      delay(5000);
    }
  }
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
    Serial.println("Error: " + fbData.errorReason());
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
  
  // Search through all households
  searchAllHouseholds();
}

void searchAllHouseholds() {
  // Get all households from root
  Serial.println("Searching all households...");
  
  if (Firebase.getJSON(fbData, "/")) {
    FirebaseJson *json = fbData.jsonObjectPtr();
    size_t len = json->iteratorBegin();
    
    String key, value = "";
    int type = 0;
    
    for (size_t i = 0; i < len; i++) {
      if (millis() - searchStartTime > SEARCH_TIMEOUT) {
        Serial.println("Search timeout reached");
        break;
      }
      
      json->iteratorGet(i, type, key, value);
      
      // Skip known system nodes
      if (key.length() == 0 || key == ".info" || key == ".settings") {
        continue;
      }
      
      Serial.print("Checking household: ");
      Serial.println(key);
      
      // Check if this household has our device ID
      String deviceCheckPath = key + "/" + deviceId;
      
      if (Firebase.getJSON(fbData, deviceCheckPath)) {
        // Device found in this household!
        householdId = key;
        householdFound = true;
        Serial.println("✓ Device found in household: " + householdId);
        
        json->iteratorEnd();
        return;
      }
      
      delay(100); // Small delay to avoid flooding Firebase
    }
    
    json->iteratorEnd();
  } else {
    Serial.println("Failed to get root data: " + fbData.errorReason());
  }
  
  if (!householdFound) {
    Serial.println("✗ Device not found in any household");
    Serial.println("\nINSTRUCTIONS:");
    Serial.println("1. Go to your Firebase Realtime Database console");
    Serial.println("2. Add this structure:");
    Serial.println("   {householdId}/{deviceId}/status = false");
    Serial.println("3. Replace {householdId} with your household ID");
    Serial.println("4. Replace {deviceId} with: " + deviceId);
  }
}

void createRealtimeDBStructure() {
  if (!Firebase.ready() || !householdFound) {
    return;
  }
  
  String path = householdId + "/" + deviceId;
  Serial.println("Creating/updating structure at: " + path);
  
  // Set initial status if not exists
  Firebase.setBool(fbData, path + "/status", currentExtendedState);
  
  // Add/update device info
  Firebase.setString(fbData, path + "/type", "Clothe Hanger");
  Firebase.setString(fbData, path + "/name", "Automatic Clothe Hanger");
  Firebase.setString(fbData, path + "/deviceId", deviceId);
  Firebase.setString(fbData, path + "/lastSeen", String(millis()));
  
  // Set initial connection status to true (we're connected!)
  Firebase.setBool(fbData, path + "/connectionStatus", true);
  wasConnected = true;
  
  Serial.println("✓ Device structure created/updated");
}

void setupFirebaseListener() {
  if (!Firebase.ready() || !householdFound) {
    return;
  }
  
  String path = householdId + "/" + deviceId + "/status";
  
  if (Firebase.beginStream(fbData, path)) {
    Serial.println("✓ Listening to: " + path);
  } else {
    Serial.println("✗ Stream begin failed: " + fbData.errorReason());
  }
}

void loop() {
  // Check motor timer first
  checkMotorTimer();
  
  // Check and update connection status periodically
  checkAndUpdateConnectionStatus();
  
  // Only check other inputs if motor is not running
  if (!motorTimerActive && !motorState) {
    // Check rain sensor
    checkRainSensor();
    
    // Check Firebase stream for commands
    if (Firebase.ready() && householdFound) {
      checkFirebaseCommands();
      
      // Periodically update last seen timestamp
      static unsigned long lastUpdate = 0;
      if (millis() - lastUpdate > 30000) { // Every 30 seconds
        updateLastSeen();
        lastUpdate = millis();
      }
    }
  }
  
  delay(100);
}

void checkMotorTimer() {
  if (motorTimerActive) {
    unsigned long currentTime = millis();
    unsigned long elapsedTime = currentTime - motorStartTime;
    
    // Check if motor has been running for the set time
    if (elapsedTime >= MOTOR_RUN_TIME) {
      if (isReversing) {
        Serial.println("⏰ Reverse timer expired - stopping motor");
        currentExtendedState = false; // Update state to retracted
      } else {
        Serial.println("⏰ Forward timer expired - stopping motor");
        currentExtendedState = true; // Update state to extended
      }
      stopMotor();
      motorTimerActive = false;
      isReversing = false;
      
      // Update Firebase status to reflect current state
      if (Firebase.ready() && householdFound) {
        Firebase.setBool(fbData, householdId + "/" + deviceId + "/status", currentExtendedState);
        Serial.println("✓ Firebase state updated to: " + String(currentExtendedState ? "EXTENDED" : "RETRACTED"));
      }
      
      // Reset command tracking
      commandExecuted = false;
    }
  }
}

void checkRainSensor() {
  int rainValue = digitalRead(rainSensorPin);
  bool newRainDetected = (rainValue == LOW);  // LOW = rain detected
  
  // Only process if rain state changed AND motor is not running
  if (newRainDetected != lastRainState) {
    if (newRainDetected && !rainDetected) {
      // Rain just started - extend clothes (forward) to protect from rain
      // Only extend if not already extended
      if (!currentExtendedState) {
        Serial.println("🌧 Rain detected! Extending clothes to protect from rain...");
        rainDetected = true;
        turnOnMotorForward();
        
        // Update Firebase to reflect rain override
        if (Firebase.ready() && householdFound) {
          Firebase.setBool(fbData, householdId + "/" + deviceId + "/rainOverride", true);
        }
      } else {
        Serial.println("🌧 Rain detected! Clothes already extended - no action needed.");
        rainDetected = true;
      }
    } 
    else if (!newRainDetected && rainDetected) {
      // Rain just stopped - BUT DO NOT RETRACT automatically
      Serial.println("☀️ Rain stopped - clothes remain extended (manual retract required)");
      rainDetected = false;
      
      // Only update the rain override status, don't move the motor
      if (Firebase.ready() && householdFound) {
        Firebase.setBool(fbData, householdId + "/" + deviceId + "/rainOverride", false);
      }
    }
    
    // Update last rain state
    lastRainState = newRainDetected;
  }
}

void checkFirebaseCommands() {
  // Check Firebase stream
  if (!Firebase.readStream(fbData)) {
    Serial.println("✗ Stream read error: " + fbData.errorReason());
    
    // If stream has error, restart it
    if (fbData.httpCode() != 200) {
      Serial.println("Restarting stream...");
      setupFirebaseListener();
    }
    return;
  }

  if (fbData.streamAvailable()) {
    if (fbData.dataType() == "boolean") {
      bool value = fbData.boolData();
      
      // Only process if command changed AND motor is not running AND state is different
      if (value != lastFirebaseCommand && !motorTimerActive && !motorState && value != currentExtendedState) {
        Serial.println("=== FIREBASE COMMAND RECEIVED ===");
        Serial.print("Household: " + householdId);
        Serial.print(" | Device: " + deviceId);
        Serial.print(" | Current State: ");
        Serial.print(currentExtendedState ? "EXTENDED" : "RETRACTED");
        Serial.print(" | Command: ");
        Serial.println(value ? "EXTEND" : "RETRACT");
        
        if (value) {
          // Switch ON = Move forward (extend) for 5 seconds then stop
          turnOnMotorForward();
        } else {
          // Switch OFF = Move reverse (retract) for 5 seconds then stop
          turnOnMotorReverse();
        }
        
        // Mark command as executed
        commandExecuted = true;
      }
      else if (value == currentExtendedState) {
        Serial.println("⚠️  Command ignored: Already in " + String(value ? "EXTENDED" : "RETRACTED") + " state");
      }
      
      // Update last command state
      lastFirebaseCommand = value;
    } else {
      Serial.println("Wrong data type: " + fbData.dataType());
    }
  }
  
  // Check for stream timeout
  if (fbData.streamTimeout()) {
    Serial.println("Stream timeout detected");
    if (!fbData.httpConnected()) {
      Serial.println("HTTP disconnected, restarting stream...");
      setupFirebaseListener();
    }
  }
}

void turnOnMotorForward() {
  if (motorState) {
    stopMotor(); // Stop current movement first
    delay(100); // Brief delay for direction change
  }
  
  Serial.println("🚀 Moving FORWARD - Extending clothes hanger");
  digitalWrite(motorPin1, HIGH);
  digitalWrite(motorPin2, LOW);
  analogWrite(motorSpeedPin, dutyCycle);
  motorState = true;
  isReversing = false;
  
  // Start the timer
  motorStartTime = millis();
  motorTimerActive = true;
  
  Serial.println("⏰ Forward timer started: " + String(MOTOR_RUN_TIME/1000) + " seconds");
}

void turnOnMotorReverse() {
  if (motorState) {
    stopMotor(); // Stop current movement first
    delay(100); // Brief delay for direction change
  }
  
  Serial.println("🔙 Moving REVERSE - Retracting clothes hanger");
  digitalWrite(motorPin1, LOW);
  digitalWrite(motorPin2, HIGH);
  analogWrite(motorSpeedPin, dutyCycle);
  motorState = true;
  isReversing = true;
  
  // Start the timer
  motorStartTime = millis();
  motorTimerActive = true;
  
  Serial.println("⏰ Reverse timer started: " + String(MOTOR_RUN_TIME/1000) + " seconds");
}

void stopMotor() {
  if (motorState) {
    Serial.println("🛑 Stopping motor");
    digitalWrite(motorPin1, LOW);
    digitalWrite(motorPin2, LOW);
    analogWrite(motorSpeedPin, 0);
    motorState = false;
  }
  motorTimerActive = false;
}

void updateLastSeen() {
  if (householdFound && Firebase.ready()) {
    String path = householdId + "/" + deviceId + "/lastSeen";
    Firebase.setString(fbData, path, String(millis()));
  }
}

void updateConnectionStatus(bool connected) {
  if (householdFound && Firebase.ready()) {
    String path = householdId + "/" + deviceId + "/connectionStatus";
    
    // Try to update connection status
    if (Firebase.setBool(fbData, path, connected)) {
      Serial.println("📡 Connection status updated to: " + String(connected ? "ONLINE" : "OFFLINE"));
      wasConnected = connected;
    } else {
      Serial.println("Failed to update connection status: " + fbData.errorReason());
    }
  }
}

void checkAndUpdateConnectionStatus() {
  unsigned long currentTime = millis();
  
  // Check connection status periodically
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