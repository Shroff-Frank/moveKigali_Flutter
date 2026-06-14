import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'createnewpass.dart';

const _kTeal = Color(0xFF02515F);
const _kBg = Color(0xFFF7F9FB);

class PhoneOtpScreen extends StatefulWidget {
  final String verificationId;
  final String phone;

  const PhoneOtpScreen({super.key, required this.verificationId, required this.phone});

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _snack('Please enter the SMS code');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);

      if (!mounted) return;

      // Navigate to create new password screen where password will be updated for the signed in user
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CreateNewPasswordScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Failed to verify code');
    } catch (e) {
      _snack('Failed to verify code');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kTeal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Enter SMS code', style: TextStyle(color: Colors.black87)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('We sent an SMS code to ${widget.phone}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 18),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '123456',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: _kTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
