import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// State
import 'user_state.dart';
import 'services/firestore_service.dart';

// Start screens
import 'screens/startscreen/splash_screen.dart';
import 'screens/startscreen/onboarding_screen.dart';

// Auth screens
import 'screens/login/register/login.dart';
import 'screens/login/register/login_screen.dart';
import 'screens/login/register/register_screen.dart';
import 'screens/login/register/forgotpassword.dart';
import 'screens/login/register/createnewpass.dart';
import 'screens/login/register/verifypassword.dart';

// Dashboard screens
import 'screens/dashboard/home_screen.dart';
import 'screens/dashboard/edit_profile.dart';
import 'screens/dashboard/notification.dart';

// ─── Background FCM handler (must be a top-level function) ───────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialised before using any Firebase service here
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 Background message: ${message.messageId}');
}

// ─── Entry point ─────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialise Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Crashlytics — catch Flutter framework errors
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // 3. Crashlytics — catch async errors outside Flutter (dart:async zone)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // 4. FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

// ─── Root widget ─────────────────────────────────────────────────────────────
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ── User state (single source of truth for logged-in user) ──────────────
  UserData _userData = const UserData();

  // ── Firebase Analytics instance ─────────────────────────────────────────
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _initMessaging();
  }

  // ── FCM setup ────────────────────────────────────────────────────────────
  Future<void> _initMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS requires this; Android 13+ also requires it)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages — show a snackbar / local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground message: ${message.notification?.title}');
      // TODO: show an in-app notification banner here
    });

    // Save FCM token to Firestore so you can send targeted notifications
    final token = await messaging.getToken();
    if (token != null) _saveFcmToken(token);

    // Refresh token when it changes (e.g. app re-install)
    messaging.onTokenRefresh.listen(_saveFcmToken);
  }

  Future<void> _saveFcmToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirestoreService.saveFcmToken(uid, token);

    // Keep local state in sync
    setState(() {
      _userData = _userData.copyWith(fcmToken: token);
    });
  }

  // ── Load user profile from Firestore after login ─────────────────────────
  Future<void> _loadUserProfile(String uid) async {
    try {
      final profile = await FirestoreService.getUserData(uid);
      if (profile != null) {
        setState(() {
          _userData = profile;
        });

        // Identify user in Analytics and Crashlytics
        await _analytics.setUserId(id: uid);
        await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      debugPrint('Failed to load user profile: $e');
    }
  }

  // ── Update user data locally + sync to Firestore ─────────────────────────
  void _handleUserUpdate(UserData updated) {
    setState(() => _userData = updated);

    if (updated.uid.isNotEmpty) {
      FirestoreService.saveUserData(updated)
          .catchError((e) => debugPrint('Profile sync failed: $e'));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return UserState(
      data: _userData,
      onUpdate: _handleUserUpdate,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'moveKigali',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),

        // Analytics — automatic screen name tracking
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: _analytics),
        ],

        // ── Auth gate: Firebase persists sessions across restarts ──────────
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Waiting for Firebase to confirm auth state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = snapshot.data;

            if (user != null) {
              // User is logged in — load their profile then go home
              _loadUserProfile(user.uid);
              return const HomeScreen(username: '',);
            }

            // Not logged in — show splash / onboarding
            return const SplashScreen();
          },
        ),

        // ── Named routes — all const, no prop drilling ────────────────────
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/onboarding': (_) => const OnboardingScreen(),

          '/login': (_) => const Login(),
          '/login_screen': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/forgot_password': (_) => const ForgotPasswordScreen(),
          '/create_new_password': (_) => const CreateNewPasswordScreen(),
          '/verify_password': (_) => const VerifyPasswordScreen(),

          '/home': (_) => const HomeScreen(username: '',),
          '/notification': (_) => const NotificationScreen(),
          '/edit_profile': (_) => EditProfileScreen(onSave: (ProfileData p1) {  },),

          // Booking screens — uncomment as you build them
          // '/event_detail': (_) => const EventDetailScreen(),
          // '/book_ticket': (_) => const BookTicketScreen(),
          // '/my_bookings': (_) => const MyBookingsScreen(),
          // '/ticket': (_) => const TicketScreen(),
        },
      ),
    );
  }
}