import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../utils/localization.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final Function(String message) showToast;
  final bool isDark;

  const AuthScreen({
    super.key,
    required this.onLoginSuccess,
    required this.showToast,
    required this.isDark,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();

  // Navigation State
  // 0: Role Selection, 1: Login Box, 2: Signup Box
  int _viewState = 0;
  String _selectedRole = 'teacher'; // 'teacher' or 'student'
  String _loginType = 'email'; // 'email' or 'mobile'
  String _signupType = 'email'; // 'email' or 'mobile'

  // Loading indicator
  bool _isLoading = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Animation for Floating Logo
  late AnimationController _logoAnimationController;
  late Animation<double> _logoTranslateAnimation;

  @override
  void initState() {
    super.initState();
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _logoTranslateAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _classController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchView(int state) {
    setState(() {
      _viewState = state;
      // Clear inputs on view transition
      _nameController.clear();
      _emailController.clear();
      _mobileController.clear();
      _classController.clear();
      _passwordController.clear();
    });
  }

  Future<void> _handleLogin() async {
    final identifier = _loginType == 'email'
        ? _emailController.text.trim()
        : _mobileController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      widget.showToast("⚠️ Please fill all fields");
      return;
    }

    if (_selectedRole == 'teacher' && identifier != FirebaseService.teacherEmail) {
      widget.showToast("❌ Not a teacher account! Use Student tab.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final creds = await _firebaseService.signIn(identifier, password);
      
      // If student login, verify they are approved
      if (_selectedRole == 'student') {
        final isPending = await _firebaseService.isUidPending(creds.user!.uid);
        if (isPending) {
          widget.showToast("⏳ Account pending approval! Please wait.");
          await _firebaseService.logout();
          setState(() => _isLoading = false);
          return;
        }

        // Check if student profile exists in students collection
        final profile = await _firebaseService.loadStudentDataByUid(creds.user!.uid);
        if (profile == null) {
          widget.showToast("❌ Profile not set up by teacher yet.");
          await _firebaseService.logout();
          setState(() => _isLoading = false);
          return;
        }
      }

      widget.onLoginSuccess();
    } catch (e) {
      widget.showToast("❌ Wrong credentials or connection error!");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();
    final cls = _classController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || password.isEmpty || (email.isEmpty && mobile.isEmpty)) {
      widget.showToast("⚠️ Fill Name, Password, and Email/Mobile!");
      return;
    }

    if (password.length < 6) {
      widget.showToast("⚠️ Password min 6 characters!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firebaseService.signUpStudent(
        name: name,
        email: email,
        mobile: mobile,
        password: password,
        cls: cls,
      );
      widget.showToast("✅ Account created! Wait for teacher approval.");
      _switchView(1); // Go back to login
    } catch (e) {
      widget.showToast("❌ Signup failed. Identifier might be already registered!");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      widget.showToast("⚠️ Please enter your email first in the email field.");
      return;
    }

    if (email.endsWith("@tuition.app")) {
      widget.showToast("⚠️ Mobile accounts cannot receive reset links.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firebaseService.sendForgotPassword(email);
      widget.showToast("✅ Password reset email sent!");
    } catch (e) {
      widget.showToast("❌ Error sending reset link.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 600;

    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_viewState == 0) _buildLogoHeader(),
              const SizedBox(height: 30),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _buildAuthContent(isMobile),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.white)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _logoTranslateAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _logoTranslateAnimation.value),
              child: Container(
                width: 130,
                height: 130,
                decoration: AppTheme.glassDecoration(
                  context: context,
                  isDark: widget.isDark,
                  borderRadius: 36,
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.graduationCap,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        Text(
          Localization.get('appTitle'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          "Select your role to continue",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthContent(bool isMobile) {
    switch (_viewState) {
      case 0:
        return _buildRoleSelection();
      case 1:
        return _buildLoginBox();
      case 2:
        return _buildSignupBox();
      default:
        return _buildRoleSelection();
    }
  }

  Widget _buildRoleSelection() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _buildRoleCard(
          role: 'teacher',
          title: Localization.get('teacherLogin'),
          icon: FontAwesomeIcons.chalkboardUser,
        ),
        _buildRoleCard(
          role: 'student',
          title: Localization.get('studentLogin'),
          icon: FontAwesomeIcons.userGraduate,
        ),
      ],
    );
  }

  Widget _buildRoleCard({required String role, required String title, required IconData icon}) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _loginType = 'email'; // Reset type
        });
        _switchView(1);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginBox() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryDark = blend(primaryColor, Colors.black, 0.65);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark, borderRadius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => _switchView(0),
              ),
              const SizedBox(width: 5),
              Text(
                _selectedRole == 'teacher'
                    ? Localization.get('teacherLogin')
                    : Localization.get('studentLogin'),
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tabs (Only for Student Role)
          if (_selectedRole == 'student') ...[
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeTab(
                      active: _loginType == 'email',
                      label: "📧 ${Localization.get('email')}",
                      onTap: () => setState(() => _loginType = 'email'),
                    ),
                  ),
                  Expanded(
                    child: _buildTypeTab(
                      active: _loginType == 'mobile',
                      label: "📱 ${Localization.get('mobileNo')}",
                      onTap: () => setState(() => _loginType = 'mobile'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],

          // Form Groups
          if (_loginType == 'email')
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: Localization.get('email'),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                hintText: "Enter your email",
              ),
            )
          else
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: Localization.get('mobileNo'),
                prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white70),
                hintText: "10-digit mobile number",
              ),
            ),
          const SizedBox(height: 15),

          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: Localization.get('password'),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
              hintText: "Enter password",
            ),
          ),
          const SizedBox(height: 10),

          // Forgot Password (Only shown for Email logins)
          if (_loginType == 'email')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: Text(
                  Localization.get('forgotPassword'),
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 15),

          // Login Button
          ElevatedButton(
            onPressed: _handleLogin,
            style: ElevatedButtonStyleFrom.style(
              primaryColor: primaryColor,
              primaryDarkColor: primaryDark,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.login),
                const SizedBox(width: 10),
                Text(Localization.get('login')),
              ],
            ),
          ),

          // Sign up link for students
          if (_selectedRole == 'student') ...[
            const SizedBox(height: 15),
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    Localization.get('newStudent'),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12),
                  ),
                ),
                const Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () => _switchView(2),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.1),
                padding: const EdgeInsets.all(15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add),
                  const SizedBox(width: 10),
                  Text(Localization.get('createAccount')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignupBox() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryDark = blend(primaryColor, Colors.black, 0.65);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark, borderRadius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => _switchView(1),
              ),
              const SizedBox(width: 5),
              Text(
                Localization.get('createAccount'),
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Tabs
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTypeTab(
                    active: _signupType == 'email',
                    label: "📧 ${Localization.get('email')}",
                    onTap: () => setState(() => _signupType = 'email'),
                  ),
                ),
                Expanded(
                  child: _buildTypeTab(
                    active: _signupType == 'mobile',
                    label: "📱 ${Localization.get('mobileNo')}",
                    onTap: () => setState(() => _signupType = 'mobile'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: Localization.get('fullName'),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
              hintText: "Your full name",
            ),
          ),
          const SizedBox(height: 15),

          if (_signupType == 'email')
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: Localization.get('email'),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                hintText: "Your email address",
              ),
            )
          else
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: Localization.get('mobileNo'),
                prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white70),
                hintText: "10-digit mobile number",
              ),
            ),
          const SizedBox(height: 15),

          TextFormField(
            controller: _classController,
            decoration: InputDecoration(
              labelText: Localization.get('class'),
              prefixIcon: const Icon(Icons.school_outlined, color: Colors.white70),
              hintText: "E.g., Class 9",
            ),
          ),
          const SizedBox(height: 15),

          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: Localization.get('password'),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
              hintText: "Min 6 characters",
            ),
          ),
          const SizedBox(height: 25),

          ElevatedButton(
            onPressed: _handleSignup,
            style: ElevatedButtonStyleFrom.style(
              primaryColor: Theme.of(context).colorScheme.secondary,
              primaryDarkColor: primaryDark,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add),
                const SizedBox(width: 10),
                Text(Localization.get('createAccount')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({required bool active, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: active ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
