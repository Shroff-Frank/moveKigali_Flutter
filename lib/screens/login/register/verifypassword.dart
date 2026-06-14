import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'createnewpass.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _kTeal      = Color(0xFF02515F);
const _kTealLight = Color(0xFF038A9B);
const _kBg        = Color(0xFFF7F9FB);

// ─────────────────────────────────────────────────────────────────────────────
// VERIFY PASSWORD SCREEN  (OTP entry + custom numpad)
// ─────────────────────────────────────────────────────────────────────────────
class VerifyPasswordScreen extends StatefulWidget {
  final bool   isEmail;
  final String contact;       // raw contact (for resend logic)
  final String maskedContact; // display string

  const VerifyPasswordScreen({
    super.key,
    this.isEmail      = false,
    this.contact      = '',
    this.maskedContact = '',
  });

  @override
  State<VerifyPasswordScreen> createState() => _VerifyPasswordScreenState();
}

class _VerifyPasswordScreenState extends State<VerifyPasswordScreen>
    with SingleTickerProviderStateMixin {
  // ── OTP state ───────────────────────────────────────────────────────────────
  static const int _otpLength = 4;
  final List<String> _digits = List.filled(_otpLength, '');
  int _focusedIndex = 0;

  // ── Resend timer ────────────────────────────────────────────────────────────
  static const int _resendSeconds = 60;
  int  _countdown  = _resendSeconds;
  bool _canResend  = false;
  Timer? _timer;

  // ── Verify loading ──────────────────────────────────────────────────────────
  bool _verifying = false;

  // ── Animation ───────────────────────────────────────────────────────────────
  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _startTimer();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Timer ───────────────────────────────────────────────────────────────────
  void _startTimer() {
    _countdown = _resendSeconds;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _canResend = true;
          _timer?.cancel();
        }
      });
    });
  }

  void _resend() {
    if (!_canResend) return;
    setState(() {
      _digits.fillRange(0, _otpLength, '');
      _focusedIndex = 0;
    });
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('A new code has been sent'),
      backgroundColor: _kTeal,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  // ── Numpad input ─────────────────────────────────────────────────────────────
  void _onDigit(String d) {
    if (_focusedIndex >= _otpLength) return;
    setState(() {
      _digits[_focusedIndex] = d;
      if (_focusedIndex < _otpLength - 1) _focusedIndex++;
    });
    if (_digits.every((c) => c.isNotEmpty)) {
      _verify();
    }
  }

  void _onBackspace() {
    setState(() {
      if (_digits[_focusedIndex].isNotEmpty) {
        _digits[_focusedIndex] = '';
      } else if (_focusedIndex > 0) {
        _focusedIndex--;
        _digits[_focusedIndex] = '';
      }
    });
  }

  // ── Verify ───────────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    final code = _digits.join();
    if (code.length < _otpLength) return;

    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _verifying = false);

    // Demo: any 4-digit code is accepted. Replace with real validation.
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const CreateNewPasswordScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
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
        body: Column(children: [
          // ── Top safe area + bar ─────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
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
                    onPressed: () =>
                        Navigator.of(context).popUntil(
                            (r) => r.isFirst),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const SizedBox(height: 16),

                // Icon badge
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kTeal, _kTealLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: _kTeal.withAlpha(60),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Icon(
                    widget.isEmail
                        ? Icons.mark_email_read_outlined
                        : Icons.phone_android_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  widget.isEmail
                      ? 'Email Verification'
                      : 'Phone Verification',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black45,
                        height: 1.6),
                    children: [
                      const TextSpan(
                          text:
                              'Please enter the 4-digit code sent to you at\n'),
                      TextSpan(
                        text: widget.maskedContact,
                        style: const TextStyle(
                            color: _kTeal,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── OTP circles ──────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(_otpLength, (i) {
                      final filled  = _digits[i].isNotEmpty;
                      final focused = i == _focusedIndex && !_verifying;
                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _focusedIndex = i),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 180),
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: filled
                                  ? _kTeal.withAlpha(15)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: focused
                                    ? _kTeal
                                    : filled
                                    ? _kTeal.withAlpha(80)
                                    : Colors.grey.shade300,
                                width: focused ? 2.5 : 1.5,
                              ),
                              boxShadow: focused
                                  ? [
                                      BoxShadow(
                                          color:
                                              _kTeal.withAlpha(40),
                                          blurRadius: 10,
                                          offset:
                                              const Offset(0, 4)),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: _verifying && filled
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child:
                                          CircularProgressIndicator(
                                        color: _kTeal,
                                        strokeWidth: 2,
                                      ))
                                  : Text(
                                      filled ? _digits[i] : '',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: _kTeal,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Resend ────────────────────────────────────────────────────
                GestureDetector(
                  onTap: _resend,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14),
                      children: [
                        const TextSpan(
                            text: 'Resend Code  ',
                            style: TextStyle(
                                color: Colors.black45,
                                fontWeight: FontWeight.w500)),
                        if (!_canResend)
                          TextSpan(
                            text: '(${_countdown}s)',
                            style: const TextStyle(
                                color: Colors.black38,
                                fontWeight: FontWeight.w500),
                          )
                        else
                          const TextSpan(
                            text: 'Resend now',
                            style: TextStyle(
                              color: _kTeal,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Custom numpad ───────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: _buildNumpad(),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Numpad ──────────────────────────────────────────────────────────────────
  Widget _buildNumpad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          children: row.map((key) {
            if (key.isEmpty) {
              return const Expanded(child: SizedBox(height: 68));
            }
            if (key == 'del') {
              return Expanded(
                child: _NumKey(
                  onTap: _onBackspace,
                  child: const Icon(
                      Icons.backspace_outlined,
                      color: Colors.black54,
                      size: 22),
                ),
              );
            }
            return Expanded(
              child: _NumKey(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(key,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87)),
                    if (_numpadSub(key).isNotEmpty)
                      Text(_numpadSub(key),
                          style: const TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.2,
                              color: Colors.black45)),
                  ],
                ),
                onTap: () => _onDigit(key),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  String _numpadSub(String key) {
    const subs = {
      '2': 'ABC', '3': 'DEF', '4': 'GHI',
      '5': 'JKL', '6': 'MNO', '7': 'PQRS',
      '8': 'TUV', '9': 'WXYZ',
    };
    return subs[key] ?? '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NUMPAD KEY
// ─────────────────────────────────────────────────────────────────────────────
class _NumKey extends StatelessWidget {
  final Widget    child;
  final VoidCallback onTap;
  const _NumKey({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 68,
          child: Center(child: child),
        ),
      ),
    );
  }
}