import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';
import 'utils/localization.dart';
import 'screens/auth_screen.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'screens/student/student_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  // Theme & Language Settings
  bool _isDark = true;
  Color _primaryColor = const Color(0xFFB33939); // default
  String _language = 'en';

  // Auth States
  User? _currentUser;
  Map<String, dynamic>? _studentProfile;
  bool _isAuthLoading = true;
  String? _authMessage;

  // Background Animation
  late AnimationController _bgAnimationController;
  late Animation<double> _bgScaleAnimation;

  // Toast System
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _setupAuthListener();

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat(reverse: true);

    _bgScaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _bgAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = prefs.getBool('theme_dark') ?? true;
      _language = prefs.getString('app_lang') ?? 'en';
      Localization.activeLanguage = _language;
      
      final colorVal = prefs.getInt('theme_color');
      if (colorVal != null) {
        _primaryColor = Color(colorVal);
      }
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      setState(() {
        _isAuthLoading = true;
        _currentUser = user;
        _studentProfile = null;
        _authMessage = null;
      });

      if (user != null) {
        if (user.email == FirebaseService.teacherEmail) {
          // Teacher logged in, data will be loaded in dashboard
          setState(() {
            _isAuthLoading = false;
          });
        } else {
          // Student logged in, fetch profile
          try {
            final profile = await FirebaseService().loadStudentDataByUid(user.uid);
            if (profile != null) {
              setState(() {
                _studentProfile = profile;
                _isAuthLoading = false;
              });
            } else {
              // Check if pending
              final isPending = await FirebaseService().isUidPending(user.uid);
              if (isPending) {
                setState(() {
                  _authMessage = "⏳ Account pending approval! Please wait.";
                  _isAuthLoading = false;
                });
              } else {
                setState(() {
                  _authMessage = "❌ Profile not set up by teacher yet.";
                  _isAuthLoading = false;
                });
              }
              await FirebaseService().logout();
            }
          } catch (e) {
            setState(() {
              _authMessage = "❌ Sync error connecting to server.";
              _isAuthLoading = false;
            });
            await FirebaseService().logout();
          }
        }
      } else {
        setState(() {
          _isAuthLoading = false;
        });
      }
    });
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
    });
    _toastTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _toastMessage = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuition Manager Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getThemeData(primaryColor: _primaryColor, isDark: _isDark),
      home: Scaffold(
        body: Stack(
          children: [
            // Dynamic Animated Background Overlay
            AnimatedBuilder(
              animation: _bgScaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bgScaleAnimation.value,
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('dashboard_bg.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Blended Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isDark
                      ? [
                          _primaryColor.withOpacity(0.05 + 0.9 * 0.05),
                          Colors.black.withOpacity(0.92),
                        ]
                      : [
                          _primaryColor.withOpacity(0.08 + 0.92 * 0.08),
                          const Color(0xFF0F172A).withOpacity(0.75),
                        ],
                ),
              ),
            ),

            // Main View
            if (_isAuthLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              _buildActiveScreen(),

            // Toast Messaging System
            if (_toastMessage != null)
              Positioned(
                bottom: 35,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    color: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 10,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text(
                        _toastMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Display Auth messages if signed out due to pending status
            if (_authMessage != null && _currentUser == null)
              Positioned(
                top: 80,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _authMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveScreen() {
    if (_currentUser == null) {
      return AuthScreen(
        onLoginSuccess: () {
          _showToast("🔑 Access Granted!");
        },
        showToast: _showToast,
        isDark: _isDark,
      );
    }

    if (_currentUser!.email == FirebaseService.teacherEmail) {
      return TeacherDashboard(
        isDark: _isDark,
        primaryColor: _primaryColor,
        onLogout: () async {
          await FirebaseService().logout();
          _showToast("👋 Signed out");
        },
        onThemeToggle: () {
          setState(() {
            _isDark = !_isDark;
          });
          _savePreference('theme_dark', _isDark);
        },
        onColorChange: (color) {
          setState(() {
            _primaryColor = color;
          });
          _savePreference('theme_color', color.value);
          _showToast("🎨 Color preference updated!");
        },
        onLanguageChange: (lang) {
          setState(() {
            _language = lang;
            Localization.activeLanguage = lang;
          });
          _savePreference('app_lang', lang);
          _showToast("🌐 Language preference updated!");
        },
        showToast: _showToast,
      );
    }

    if (_studentProfile != null) {
      return StudentDashboard(
        studentProfile: _studentProfile!,
        isDark: _isDark,
        primaryColor: _primaryColor,
        onLogout: () async {
          await FirebaseService().logout();
          _showToast("👋 Signed out");
        },
        onThemeToggle: () {
          setState(() {
            _isDark = !_isDark;
          });
          _savePreference('theme_dark', _isDark);
        },
        onColorChange: (color) {
          setState(() {
            _primaryColor = color;
          });
          _savePreference('theme_color', color.value);
          _showToast("🎨 Color preference updated!");
        },
        onLanguageChange: (lang) {
          setState(() {
            _language = lang;
            Localization.activeLanguage = lang;
          });
          _savePreference('app_lang', lang);
          _showToast("🌐 Language preference updated!");
        },
        showToast: _showToast,
      );
    }

    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}
