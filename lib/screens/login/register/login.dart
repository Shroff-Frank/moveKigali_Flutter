import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:movekigali/utils/localization.dart';
import 'login_screen.dart';

class Login extends StatefulWidget {
  final String languageCode;
  const Login({super.key, this.languageCode = 'rw'});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  bool isLoading = false;
  String selectedLanguage = 'rw';

  // Gradient Animation for Login Button
  late AnimationController _controller;
  late Animation<Color?> _color1;
  late Animation<Color?> _color2;

  @override
  void initState() {
    super.initState();
    selectedLanguage = widget.languageCode;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _color1 = ColorTween(
      begin: Colors.orangeAccent,
      end: Colors.deepOrange,
    ).animate(_controller);

    _color2 = ColorTween(
      begin: Colors.deepOrange,
      end: Colors.orangeAccent,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final languageCode = selectedLanguage;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              "assets/images/centre.png",
              fit: BoxFit.cover,
            ),
          ),

          // Blur Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),

          // Main UI
          SafeArea(
            child: SingleChildScrollView(
              child: SizedBox(
                height: screenHeight,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _openLanguagePicker,
                            icon: const Icon(Icons.menu, color: Colors.white),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'moveKigali Account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),

                    // Logo + App Name
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images/logo1.png",
                          width: screenWidth * 0.25,
                        ),
                        const SizedBox(width: 10),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.orangeAccent, Colors.deepOrange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(Rect.fromLTWH(
                              0, 0, bounds.width, bounds.height)),
                          child: Text(
                            "moveKigali",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 1),

                    // Main Text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        translate('safe_travel', languageCode),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: screenWidth * 0.06,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 4),
                    const Spacer(flex: 5),

                    // Animated Login Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) => Opacity(
                          opacity: isLoading ? 0.6 : 1,
                          child: Container(
                            height: 55,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [_color1.value!, _color2.value!],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                splashColor: Colors.white24,
                                onTap: isLoading ? null : _goToLogin,
                                child: Center(
                                  child: Text(
                                    translate('login', languageCode),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Navigate to LoginScreen
  void _goToLogin() {
    setState(() => isLoading = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(languageCode: selectedLanguage)),
      );
    });
  }

  void _openLanguagePicker() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Language selector',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.72,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0D1C22),
                borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    translate('language_title', selectedLanguage),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    translate('language_subtitle', selectedLanguage),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: ListView.separated(
                      itemCount: supportedLanguages.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                      itemBuilder: (context, index) {
                        final language = supportedLanguages[index];
                        final code = language['code']!;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${language['flag']} ${language['name']}',
                            style: TextStyle(
                              color: code == selectedLanguage ? Colors.orangeAccent : Colors.white,
                              fontSize: 16,
                              fontWeight: code == selectedLanguage ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            setState(() => selectedLanguage = code);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
