import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'phone_otp.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _kTeal      = Color(0xFF02515F);
// ignore: unused_element
const _kTealLight = Color(0xFF038A9B);
const _kBg        = Color(0xFFF7F9FB);

// ─────────────────────────────────────────────────────────────────────────────
// FORGOT PASSWORD SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  // ── Tab controller ──────────────────────────────────────────────────────────
  late final TabController _tabCtrl;

  // ── Controllers ─────────────────────────────────────────────────────────────
  final _emailCtrl  = TextEditingController();
  final _phoneCtrl  = TextEditingController();

  // ── Phone country ───────────────────────────────────────────────────────────
  String _phoneCode = '+250';
  String _flag      = '🇷🇼';

  static const List<Map<String, String>> _countries = [
    {'name': 'Rwanda',        'flag': '🇷🇼', 'code': '+250'},
    {'name': 'Kenya',         'flag': '🇰🇪', 'code': '+254'},
    {'name': 'Uganda',        'flag': '🇺🇬', 'code': '+256'},
    {'name': 'Tanzania',      'flag': '🇹🇿', 'code': '+255'},
    {'name': 'United States', 'flag': '🇺🇸', 'code': '+1'},
    {'name': 'France',        'flag': '🇫🇷', 'code': '+33'},
    {'name': 'South Africa',  'flag': '🇿🇦', 'code': '+27'},
    {'name': 'Nigeria',       'flag': '🇳🇬', 'code': '+234'},
    {'name': 'Germany',       'flag': '🇩🇪', 'code': '+49'},
    {'name': 'Australia',     'flag': '🇦🇺', 'code': '+61'},
    {'name': 'China',         'flag': '🇨🇳', 'code': '+86'},
    {'name': 'India',         'flag': '🇮🇳', 'code': '+91'},
  ];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Country picker ──────────────────────────────────────────────────────────
  void _pickCountry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountrySheet(
        countries: _countries,
        selected: _phoneCode,
        onSelect: (code, flag) {
          setState(() {
            _phoneCode = code;
            _flag      = flag;
          });
        },
      ),
    );
  }

  // ── Next ────────────────────────────────────────────────────────────────────
  Future<void> _onNext() async {
    final isEmail = _tabCtrl.index == 0;
    final input   = isEmail ? _emailCtrl.text.trim() : _phoneCtrl.text.trim();

    if (input.isEmpty) {
      _snack(isEmail
          ? 'Please enter your email address'
          : 'Please enter your phone number');
      return;
    }
    if (isEmail && !input.contains('@')) {
      _snack('Please enter a valid email address');
      return;
    }
    if (!isEmail && input.length < 6) {
      _snack('Please enter a valid phone number');
      return;
    }

    if (!isEmail) {
      // Start phone verification flow
      final raw = input.replaceAll(RegExp(r'[^0-9+]'), '');
      final phone = raw.startsWith('+') ? raw : '$_phoneCode$raw';

      setState(() => _loading = true);

      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-retrieval or instant verification on some devices
            try {
              await FirebaseAuth.instance.signInWithCredential(credential);
              if (!mounted) return;
              Navigator.of(context).pushNamed('/create_new_password');
            } catch (e) {
              _snack('Phone sign-in failed');
            }
          },
          verificationFailed: (e) {
            _snack(e.message ?? 'Phone verification failed');
          },
          codeSent: (verificationId, resendToken) {
            if (!mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PhoneOtpScreen(verificationId: verificationId, phone: phone),
            ));
          },
          codeAutoRetrievalTimeout: (verificationId) {},
        );
      } catch (e) {
        _snack('Failed to start phone verification');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: input);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Reset link sent'),
          content: Text(
            'A password reset link has been sent to $input. Please check your inbox and follow the instructions to update your password.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found for that email address.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;
        default:
          message = 'Unable to send reset email: ${e.message}';
      }
      _snack(message);
    } catch (e) {
      _snack('Unable to send reset email. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts[0].length <= 2) return email;
    return '${parts[0].substring(0, 2)}****@${parts[1]}';
  }

  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    return '${phone.substring(0, 2)}****${phone.substring(phone.length - 2)}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kTeal,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(children: [
            // ── Top bar ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 22, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 48 : 28,
                  vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const SizedBox(height: 16),

                  // ── Title ───────────────────────────────────────────────────
                  const Text(
                    'Forgot your\npassword?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'If you need help resetting your password we can help by sending you a link to reset it.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black45,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Tab switcher ────────────────────────────────────────────
                  _buildTabBar(),
                  const SizedBox(height: 28),

                  // ── Tab content ─────────────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _tabCtrl.index == 0
                        ? _buildEmailField()
                        : _buildPhoneField(),
                  ),
                  const SizedBox(height: 36),

                  // ── Next button ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kTeal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _kTeal.withAlpha(120),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                          : const Text(
                              'Next',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                            ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: _kTeal,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black54,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [
          Tab(text: 'Email'),
          Tab(text: 'Phone Number'),
        ],
      ),
    );
  }

  // ── Email field ─────────────────────────────────────────────────────────────
  Widget _buildEmailField() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Email Address',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'youremail@example.com',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.email_outlined,
                  color: _kTeal, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Phone field ─────────────────────────────────────────────────────────────
  Widget _buildPhoneField() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Number',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            // Country flag + code
            GestureDetector(
              onTap: _pickCountry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                      right: BorderSide(
                          color: Colors.grey.shade200, width: 1.5)),
                ),
                child: Row(children: [
                  Text(_flag,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 6),
                  Text(
                    _phoneCode,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.black38, size: 18),
                ]),
              ),
            ),
            // Number input
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                    fontSize: 15, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: '12 345 678',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTRY SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _CountrySheet extends StatelessWidget {
  final List<Map<String, String>> countries;
  final String selected;
  final void Function(String code, String flag) onSelect;

  const _CountrySheet({
    required this.countries,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Country',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close,
                      color: _kTeal, size: 18),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: countries.length,
            itemBuilder: (_, i) {
              final c     = countries[i];
              final isSel = selected == c['code'];
              return GestureDetector(
                onTap: () {
                  onSelect(c['code']!, c['flag']!);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: isSel ? _kTeal : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSel
                            ? _kTeal
                            : Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Text(c['flag']!,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(c['name']!,
                          style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 14)),
                    ),
                    Text(c['code']!,
                        style: TextStyle(
                            color: isSel
                                ? Colors.white70
                                : Colors.grey.shade500,
                            fontSize: 13)),
                    if (isSel) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 18),
                    ],
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}