import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movekigali/utils/localization.dart';
import '../login/register/login.dart';
import '../login/register/register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<Color?> _color1;
  late Animation<Color?> _color2;
  String selectedLanguage = 'rw';

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);

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

  // ===================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 2, 81, 95),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _openLanguagePicker,
                    icon: const Icon(Icons.menu, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      supportedLanguages.firstWhere((item) => item['code'] == selectedLanguage)['name']!,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('seenOnboarding', true);
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => Login(languageCode: selectedLanguage)),
                      );
                    },
                    child: const Text(
                      "Skip",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Image.asset(
                            'assets/images/logo1.png',
                            width: 110,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildPage(
                                image: "assets/images/anywhere.png",
                                title: "Book Bus Tickets\nFrom Anywhere",
                                subtitle:
                                    "Book through moveKigali and get tickets delivered directly to your doorstep.",
                                screenWidth: screenWidth,
                                screenHeight: screenHeight,
                              ),
                              const SizedBox(height: 18),
                              buildPage(
                                image: "assets/images/track.png",
                                title: "Track Your Trip\nIn Real Time",
                                subtitle:
                                    "Monitor your location and trip status live. Never miss your destination again.",
                                screenWidth: screenWidth,
                                screenHeight: screenHeight,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Animated Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) => Container(
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
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => Login(languageCode: selectedLanguage)),
                                    );
                                  },
                                  child: const Center(
                                    child: Text(
                                      "Get Started",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Register
                        GestureDetector(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('seenOnboarding', true);
                            if (!mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => RegisterScreen(languageCode: selectedLanguage)),
                            );
                          },
                          child: const Text(
                            "Don't have an account? Register Account",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // Bottom handle
                        Container(
                          width: 100,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget buildPage({
    required String image,
    required String title,
    required String subtitle,
    required double screenWidth,
    required double screenHeight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.065,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.042,
              color: Colors.white70,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          Container(
            width: screenWidth * 0.72,
            height: screenHeight * 0.28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image.asset(
                image,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
