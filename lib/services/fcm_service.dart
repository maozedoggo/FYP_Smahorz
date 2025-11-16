import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _isInitialized = false;

  // Callback for handling invite actions when app is opened from notification
  Function(String householdId, String inviterName, String householdName)? onInviteReceived;

  // ==================== INITIALIZATION ====================
  
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _setupFCM();
      await _getFCMToken();
      _isInitialized = true;
      print('✅ FCM Service initialized');
    } catch (e) {
      print('❌ FCM Service initialization failed: $e');
    }
  }

  Future<void> _setupFCM() async {
    // Request permission (still needed for iOS)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ONLY handle when app is opened from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle when app is opened from terminated state
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }

    // Handle token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _storeFCMToken(newToken);
    });
  }

  Future<void> _getFCMToken() async {
    _fcmToken = await _firebaseMessaging.getToken();
    if (_fcmToken != null) {
      await _storeFCMToken(_fcmToken!);
    }
    print("FCM Token: $_fcmToken");
  }

  // ==================== BACKGROUND NOTIFICATION HANDLER ====================

  void _handleBackgroundMessage(RemoteMessage message) {
    print('📱 App opened from notification: ${message.data}');
    
    final data = message.data;
    
    if (data['type'] == 'household_invite') {
      _handleHouseholdInvite(
        householdId: data['householdId'] ?? '',
        inviterName: data['inviterName'] ?? 'Someone',
        householdName: data['householdName'] ?? 'a household',
      );
    }
  }

  void _handleHouseholdInvite({
    required String householdId,
    required String inviterName,
    required String householdName,
  }) {
    // Trigger callback for UI handling
    if (onInviteReceived != null) {
      onInviteReceived!(householdId, inviterName, householdName);
    }

    print('🏠 Invite received from $inviterName for $householdName');
  }

  // ==================== FCM TOKEN MANAGEMENT ====================

  Future<void> _storeFCMToken(String token) async {
    // Store token in your backend/Firestore
    print('💾 FCM Token stored: $token');
    
    // Example: Save to Firestore
    // final user = FirebaseAuth.instance.currentUser;
    // if (user != null) {
    //   await FirebaseFirestore.instance.collection('users').doc(user.email).set({
    //     'fcmToken': token,
    //     'updatedAt': FieldValue.serverTimestamp(),
    //   }, SetOptions(merge: true));
    // }
  }

  // ==================== PUBLIC METHODS ====================

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  // Manual token refresh if needed
  Future<void> refreshToken() async {
    await _getFCMToken();
  }
}