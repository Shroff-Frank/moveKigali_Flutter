import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _kTeal      = Color(0xFF02515F);
const _kTealLight = Color(0xFF038A9B);
const _kBg        = Color(0xFFF7F9FB);

// ─────────────────────────────────────────────────────────────────────────────
// CREATE NEW PASSWORD SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key});

  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  // ── Controllers ─────────────────────────────────────────────────────────────
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // ── Visibility ───────────────────────────────────────────────────────────────
  bool _showPass    = false;
  bool _showConfirm = false;
  bool _saving      = false;

  // ── Strength ─────────────────────────────────────────────────────────────────
  double _strength   = 0.0;
  String _strengthLbl = '';
  Color  _strengthCol = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(_evalStrength);
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Password strength ─────────────────────────────────────────────────────────
  void _evalStrength() {
    final p = _passCtrl.text;
    double s = 0;
    if (p.length >= 8) s += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s += 0.25;

    String lbl = '';
    Color  col  = Colors.transparent;
    if (p.isEmpty) {
      s = 0;
    } else if (s <= 0.25) {
      lbl = 'Weak'; col = Colors.red;
    } else if (s <= 0.5) {
      lbl = 'Fair'; col = Colors.orange;
    } else if (s <= 0.75) {
      lbl = 'Good'; col = const Color(0xFF1ABC9C);
    } else {
      lbl = 'Strong'; col = Colors.green;
    }

    setState(() {
      _strength    = s;
      _strengthLbl = lbl;
      _strengthCol = col;
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pass.isEmpty) {
      _snack('Please enter a new password', isError: true);
      return;
    }
    if (pass.length < 8) {
      _snack('Password must be at least 8 characters', isError: true);
      return;
    }
    if (pass != confirm) {
      _snack('Passwords do not match', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(pass);
      }

      if (!mounted) return;

      setState(() => _saving = false);

      // Show success dialog then navigate to login
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SuccessDialog(
          onContinue: () {
            Navigator.of(context).pop(); // close dialog
            // Navigate to login and clear the entire stack
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          },
        ),
      );
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Failed to update password', isError: true);
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      _snack('Failed to update password', isError: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
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
                    onPressed: () =>
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        ),
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

                  // ── Icon ────────────────────────────────────────────────────
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
                    child: const Icon(Icons.lock_reset_rounded,
                        color: Colors.white, size: 30),
                  ),

                  const SizedBox(height: 24),

                  // ── Title ───────────────────────────────────────────────────
                  const Text(
                    'Create new\npassword',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your new password must be different from previously used passwords. Make it strong!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black45,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── New password ─────────────────────────────────────────────
                  _buildPasswordField(
                    label:      'New Password',
                    controller: _passCtrl,
                    show:       _showPass,
                    onToggle:   () =>
                        setState(() => _showPass = !_showPass),
                  ),

                  // ── Strength bar ─────────────────────────────────────────────
                  if (_passCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildStrengthBar(),
                  ],

                  const SizedBox(height: 20),

                  // ── Confirm password ─────────────────────────────────────────
                  _buildPasswordField(
                    label:      'Confirm Password',
                    controller: _confirmCtrl,
                    show:       _showConfirm,
                    onToggle:   () =>
                        setState(() => _showConfirm = !_showConfirm),
                    confirmAgainst: _passCtrl.text,
                  ),

                  const SizedBox(height: 14),

                  // ── Requirements ─────────────────────────────────────────────
                  _buildRequirements(),
                  const SizedBox(height: 36),

                  // ── Submit button ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
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
                      child: _saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                          : const Text(
                              'Save Password',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Password input field ──────────────────────────────────────────────────────
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool show,
    required VoidCallback onToggle,
    String? confirmAgainst,
  }) {
    final isConfirm = confirmAgainst != null;
    final mismatch  = isConfirm &&
        controller.text.isNotEmpty &&
        controller.text != confirmAgainst;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54)),
      const SizedBox(height: 8),
      StatefulBuilder(builder: (_, setLocal) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: mismatch
                    ? Colors.red.shade300
                    : Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: !show,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
                fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              hintText: isConfirm
                  ? 'Re-enter your password'
                  : 'Enter password',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.lock_outline,
                  color: _kTeal, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: onToggle,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 14),
            ),
          ),
        );
      }),
      if (mismatch) ...[
        const SizedBox(height: 6),
        const Row(children: [
          Icon(Icons.cancel_outlined,
              color: Colors.red, size: 14),
          SizedBox(width: 4),
          Text('Passwords do not match',
              style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),
      ],
    ]);
  }

  // ── Strength bar ──────────────────────────────────────────────────────────────
  Widget _buildStrengthBar() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _strength,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(_strengthCol),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _strengthLbl,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _strengthCol),
          ),
        ],
      ),
    ]);
  }

  // ── Requirements list ─────────────────────────────────────────────────────────
  Widget _buildRequirements() {
    final p = _passCtrl.text;
    return Column(children: [
      _req('At least 8 characters', p.length >= 8),
      _req('At least one uppercase letter',
          p.contains(RegExp(r'[A-Z]'))),
      _req('At least one number',
          p.contains(RegExp(r'[0-9]'))),
      _req('At least one special character',
          p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))),
    ]);
  }

  Widget _req(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 16, height: 16,
          decoration: BoxDecoration(
            color: met ? _kTeal : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
                color: met ? _kTeal : Colors.grey.shade400,
                width: 1.5),
          ),
          child: met
              ? const Icon(Icons.check,
                  color: Colors.white, size: 10)
              : null,
        ),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
              fontSize: 13,
              color: met ? _kTeal : Colors.black38,
              fontWeight: met
                  ? FontWeight.w600
                  : FontWeight.normal,
            )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final VoidCallback onContinue;
  const _SuccessDialog({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Animated check icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_kTeal, _kTealLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _kTeal.withAlpha(70),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Password Changed!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your password has been updated successfully. You can now sign in with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black45,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Back to Login',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}