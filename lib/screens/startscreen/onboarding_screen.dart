import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movekigali/utils/localization.dart';
import '../login/register/login_screen.dart';
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
  int onboardingStep = 0;

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
                        MaterialPageRoute(builder: (_) => LoginScreen(languageCode: selectedLanguage)),
                      );
                    },
                    child: const Text(
                      "Taruka",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 10),
                                if (onboardingStep == 0) ...[
                                  buildPage(
                                    image: "assets/images/anywhere.png",
                                    title: "Gura itike ya bus aho uri hose",
                                    subtitle:
                                        "Gura itike yawe ukoresheje MoveKigali, uyigezweho aho utuye.",
                                    screenWidth: screenWidth,
                                    screenHeight: screenHeight,
                                  ),
                                  const SizedBox(height: 32),
                                  AnimatedBuilder(
                                    animation: _controller,
                                    builder: (context, child) {
                                      return Container(
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
                                            onTap: () => setState(() => onboardingStep = 1),
                                            child: const Center(
                                              child: Text(
                                                "Tangira",
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
                                      );
                                    },
                                  ),
                                ] else ...[
                                  buildPage(
                                    image: "assets/images/track.png",
                                    title: "Kurikirana urugendo rwawe mu gihe nyacyo.",
                                    subtitle:
                                        "Menya aho ugeze n' imiterere y'urugendo rwawe. Ntuzongera kurenga cyangwa kubura aho ugomba kugera.",
                                    screenWidth: screenWidth,
                                    screenHeight: screenHeight,
                                  ),
                                  const SizedBox(height: 32),
                                  AnimatedBuilder(
                                    animation: _controller,
                                    builder: (context, child) {
                                      return Container(
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
                                            onTap: () async {
                                              final prefs = await SharedPreferences.getInstance();
                                              await prefs.setBool('seenOnboarding', true);
                                              if (!mounted) return;
                                              Navigator.pushReplacement(
                                                context,
                                                MaterialPageRoute(builder: (_) => LoginScreen(languageCode: selectedLanguage)),
                                              );
                                            },
                                            child: const Center(
                                              child: Text(
                                                  "Komeza",
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
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
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
                                    child: Text(
                                      '${translate('dont_have_account', selectedLanguage)} ${translate('register', selectedLanguage)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                buildPageIndicator(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: onboardingStep == 0 ? 16 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: onboardingStep == 0 ? Colors.orangeAccent : Colors.white54,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: onboardingStep == 1 ? 16 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: onboardingStep == 1 ? Colors.orangeAccent : Colors.white54,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
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
