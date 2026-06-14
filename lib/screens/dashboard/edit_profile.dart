import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:movekigali/services/firestore_service.dart';
import 'package:movekigali/user_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _kTeal      = Color(0xFF02515F);
const _kTealLight = Color(0xFF038A9B);

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
class ProfileData {
  final String fullName;
  final String nickName;
  final String email;
  final String? phone;
  final String? imagePath;

  ProfileData({
    required this.fullName,
    required this.nickName,
    required this.email,
    this.phone,
    this.imagePath,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  final bool isDark;
  final String username;
  final String? currentImagePath;
  final String? currentEmail;
  final String? currentNickName;
  final String? currentPhone;
  final void Function(ProfileData) onSave;

  const EditProfileScreen({
    super.key,
    this.isDark = false,
    this.username = 'User',
    this.currentImagePath,
    this.currentEmail,
    this.currentNickName,
    this.currentPhone,
    required this.onSave,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _nickCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  // ── State ─────────────────────────────────────────────────────────────────
  String?   _imagePath;
  Uint8List? _webImageBytes;
  String _country      = 'Rwanda';
  String _gender       = 'Male';
  String _phoneCode    = '+250';
  bool   _saving       = false;
  bool   _isPickingImage = false;
  bool   _imageRemoved = false;

  static const List<Map<String, String>> _countries = [
    {'name': 'Rwanda',        'flag': '🇷🇼', 'code': '+250'},
    {'name': 'United States', 'flag': '🇺🇸', 'code': '+1'},
    {'name': 'Kenya',         'flag': '🇰🇪', 'code': '+254'},
    {'name': 'France',        'flag': '🇫🇷', 'code': '+33'},
    {'name': 'Uganda',        'flag': '🇺🇬', 'code': '+256'},
    {'name': 'Tanzania',      'flag': '🇹🇿', 'code': '+255'},
    {'name': 'South Africa',  'flag': '🇿🇦', 'code': '+27'},
    {'name': 'Nigeria',       'flag': '🇳🇬', 'code': '+234'},
    {'name': 'Germany',       'flag': '🇩🇪', 'code': '+49'},
    {'name': 'China',         'flag': '🇨🇳', 'code': '+86'},
    {'name': 'United Kingdom','flag': '🇬🇧', 'code': '+44'},
    {'name': 'Canada',        'flag': '🇨🇦', 'code': '+1'},
    {'name': 'India',         'flag': '🇮🇳', 'code': '+91'},
    {'name': 'Australia',     'flag': '🇦🇺', 'code': '+61'},
    {'name': 'Japan',         'flag': '🇯🇵', 'code': '+81'},
    {'name': 'Brazil',        'flag': '🇧🇷', 'code': '+55'},
    {'name': 'Mexico',        'flag': '🇲🇽', 'code': '+52'},
    {'name': 'Egypt',         'flag': '🇪🇬', 'code': '+20'},
    {'name': 'Russia',        'flag': '🇷🇺', 'code': '+7'},
    {'name': 'Italy',         'flag': '🇮🇹', 'code': '+39'},
  ];

  static const List<String> _genders = ['Male', 'Female', 'Other'];

  String _currentPhoneLocale(String? phone) {
    if (phone == null || phone.isEmpty) return '123456789';
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    for (final country in _countries) {
      final code = country['code']!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.startsWith(code) && digits.length > code.length) {
        _phoneCode = '+${code}';
        return digits.substring(code.length);
      }
    }
    return digits;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController(text: widget.username);
    _nickCtrl     = TextEditingController(
        text: widget.currentNickName ??
            widget.username.toLowerCase().replaceAll(' ', '.'));
    _emailCtrl   = TextEditingController(
        text: widget.currentEmail ?? 'john.doe@email.com');
    _phoneCtrl   = TextEditingController(text: _currentPhoneLocale(widget.currentPhone));
    _addressCtrl = TextEditingController(text: '45 New Avenue, Kigali');
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _nickCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Colour helpers ────────────────────────────────────────────────────────
  bool  get _d         => widget.isDark;
  Color get _bg        => _d ? const Color(0xFF0D1C22) : const Color(0xFFF5F7F9);
  Color get _appBarBg  => _d ? const Color(0xFF111C22) : Colors.white;
  Color get _appBarFg  => _d ? Colors.white             : Colors.black87;
  Color get _cardBg    => _d ? const Color(0xFF1A2830) : Colors.white;
  Color get _inputBg   => _d ? const Color(0xFF1E2E38) : Colors.white;
  Color get _borderCol => _d ? const Color(0xFF2E4250) : const Color(0xFFDDE3EA);
  Color get _labelCol  => _d ? const Color(0xFFABCBD8) : const Color(0xFF8A9BB0);
  Color get _textCol   => _d ? const Color(0xFFF5FAFF) : Colors.black87;
  Color get _subCol    => _d ? const Color(0xFFB0D6E1) : Colors.grey.shade500;
  Color get _divider   => _d ? const Color(0xFF1E2E38) : const Color(0xFFEBF0F5);

  // ── Avatar builder ────────────────────────────────────────────────────────
  Widget _buildAvatar() {
    if (kIsWeb && _webImageBytes != null) {
      return Image.memory(_webImageBytes!, fit: BoxFit.cover,
          width: 100, height: 100);
    }
    if (!kIsWeb && _imagePath != null) {
      return Image.file(File(_imagePath!), fit: BoxFit.cover,
          width: 100, height: 100,
          errorBuilder: (_, _, _) => _buildInitialsAvatar());
    }
    if (!_imageRemoved) {
      final path = widget.currentImagePath;
      if (path != null && path.isNotEmpty) {
        if (path.startsWith('data:image')) {
          try {
            final bytes = base64Decode(path.split(',').last);
            return Image.memory(bytes, fit: BoxFit.cover,
                width: 100, height: 100,
                errorBuilder: (_, _, _) => _buildInitialsAvatar());
          } catch (_) {
            return _buildInitialsAvatar();
          }
        }
        if (kIsWeb) {
          return Image.network(path, fit: BoxFit.cover,
              width: 100, height: 100,
              errorBuilder: (_, _, _) => _buildInitialsAvatar());
        }
        return Image.file(File(path), fit: BoxFit.cover,
            width: 100, height: 100,
            errorBuilder: (_, _, _) => _buildInitialsAvatar());
      }
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final initial = _fullNameCtrl.text.isNotEmpty
        ? _fullNameCtrl.text[0].toUpperCase()
        : 'U';
    return Container(
      width: 100, height: 100,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [_kTeal, _kTealLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text(initial,
          style: const TextStyle(color: Colors.white, fontSize: 40,
              fontWeight: FontWeight.bold))),
    );
  }

  // ── Image picker ──────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      if (kIsWeb) {
        final bytes = await ImagePickerWeb.getImageAsBytes();
        if (bytes != null && mounted) {
          setState(() {
            _webImageBytes = bytes;
            _imagePath     = null;
            _imageRemoved  = false;
          });
        }
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
            source: source, imageQuality: 85, maxWidth: 800);
        if (picked != null && mounted) {
          setState(() {
            _imagePath     = picked.path;
            _webImageBytes = null;
            _imageRemoved  = false;
          });
        }
      }
    } catch (e) {
      _snack('Error picking image: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  bool get _hasPickedOrExistingImage =>
      _webImageBytes != null ||
      _imagePath != null ||
      (!_imageRemoved && (widget.currentImagePath?.isNotEmpty ?? false));

  void _showImageSourceSheet() {
    if (_isPickingImage) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: _d ? const Color(0xFF3A5060) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Text('Profile Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: _textCol)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _sourceBtn(Icons.camera_alt_rounded, 'Camera', () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            }),
            _sourceBtn(Icons.photo_library_rounded, 'Gallery', () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            }),
            if (_hasPickedOrExistingImage)
              _sourceBtn(Icons.delete_rounded, 'Remove', () {
                Navigator.pop(context);
                setState(() {
                  _imagePath     = null;
                  _webImageBytes = null;
                  _imageRemoved  = true;
                });
              }, color: Colors.red),
          ]),
        ]),
      ),
    );
  }

  Widget _sourceBtn(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? _kTeal;
    return GestureDetector(
      onTap: _isPickingImage ? null : onTap,
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: _isPickingImage
                ? Colors.grey.withAlpha(22)
                : c.withAlpha(22),
            shape: BoxShape.circle,
            border: Border.all(
                color: _isPickingImage
                    ? Colors.grey.withAlpha(60)
                    : c.withAlpha(60),
                width: 1.5),
          ),
          child: _isPickingImage
              ? const SizedBox(width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, color: c, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(fontSize: 13,
                color: _isPickingImage ? Colors.grey : _textCol,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── Country picker ────────────────────────────────────────────────────────
  void _pickCountry() {
    final searchController = TextEditingController();
    final filteredCountries = ValueNotifier<List<Map<String, String>>>(_countries);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: _d ? const Color(0xFF3A5060) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Country',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold, color: _textCol)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: _inputBg, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: _kTeal, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: searchController,
                onChanged: (query) {
                  setModalState(() {
                    final lower = query.toLowerCase();
                    filteredCountries.value = _countries.where((c) {
                      return c['name']!.toLowerCase().contains(lower) ||
                          c['code']!.contains(query);
                    }).toList();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  hintStyle: TextStyle(color: _subCol),
                  prefixIcon: Icon(Icons.search, color: _subCol),
                  filled: true,
                  fillColor: _inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _kTeal),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<List<Map<String, String>>>(
                valueListenable: filteredCountries,
                builder: (context, filtered, _) {
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('No countries found',
                          style: TextStyle(color: _subCol)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c     = filtered[i];
                      final isSel = _country == c['name'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _country   = c['name']!;
                            _phoneCode = c['code']!;
                          });
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSel ? _kTeal : _inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSel ? _kTeal : _borderCol),
                          ),
                          child: Row(children: [
                            Text(c['flag']!, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(c['name']!,
                                style: TextStyle(
                                    color: isSel ? Colors.white : _textCol,
                                    fontWeight: FontWeight.w500, fontSize: 14))),
                            Text(c['code']!,
                                style: TextStyle(
                                    color: isSel ? Colors.white : _subCol,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAVE — updates Firebase Auth + Firestore + local state
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _save() async {
    if (_saving) return;

    final fullName = _fullNameCtrl.text.trim();
    final nickName = _nickCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    // ── Validation ───────────────────────────────────────────────────────────
    if (fullName.isEmpty) {
      _snack('Full name is required', Colors.red);
      return;
    }
    if (fullName.length < 3) {
      _snack('Full name must be at least 3 characters', Colors.red);
      return;
    }
    if (nickName.isEmpty) {
      _snack('Nick name is required', Colors.red);
      return;
    }
    if (email.isEmpty || !_isValidEmail(email)) {
      _snack('Enter a valid email', Colors.red);
      return;
    }
    if (phone.isEmpty || !_isValidPhone(phone)) {
      _snack('Enter a valid phone number', Colors.red);
      return;
    }

    setState(() => _saving = true);

    try {
      // ── Resolve final image path ─────────────────────────────────────────
      String? finalImagePath;
      if (kIsWeb && _webImageBytes != null) {
        finalImagePath =
            'data:image/png;base64,${base64Encode(_webImageBytes!)}';
      } else if (!kIsWeb && _imagePath != null) {
        finalImagePath = _imagePath;
      } else if (!_imageRemoved) {
        finalImagePath = widget.currentImagePath;
      }

      final fullPhone = '$_phoneCode${phone.replaceAll(RegExp(r'[^0-9]'), '')}';

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('No authenticated user');
      }

      await user.updateDisplayName(fullName);
      await FirestoreService.saveUserData(UserData(
        uid:          user.uid,
        name:         fullName,
        email:        email,
        phone:        fullPhone,
        nickName:     nickName,
        profileImage: finalImagePath ?? '',
      ));

      if (!mounted) return;
      final profileData = ProfileData(
        fullName:  fullName,
        nickName:  nickName,
        email:     email,
        phone:     fullPhone,
        imagePath: finalImagePath,
      );
      widget.onSave(profileData);

      _snack('Profile updated successfully! ✅', Colors.green);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Failed to save profile. Please try again.', Colors.red);
      debugPrint('Profile save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD — UI stays exactly the same
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _d ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _appBarBg,
          foregroundColor: _appBarFg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text('Edit profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: _appBarFg)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _appBarFg),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: _divider),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 900
                ? 80
                : (MediaQuery.of(context).size.width > 600 ? 40 : 20),
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(children: [
                _buildAvatarPicker(),
                const SizedBox(height: 28),

                _inputField(label: 'Full Name', controller: _fullNameCtrl,
                    hint: 'Enter full name', icon: Icons.person_outline_rounded),
                const SizedBox(height: 14),

                _inputField(label: 'Nick name', controller: _nickCtrl,
                    hint: 'Enter nick name', icon: Icons.badge_outlined),
                const SizedBox(height: 14),

                _inputField(label: 'Email', controller: _emailCtrl,
                    hint: 'youremail@domain.com', icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),

                _buildPhoneField(),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(child: _buildCountryField()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildGenderField()),
                ]),
                const SizedBox(height: 14),

                _inputField(label: 'Address', controller: _addressCtrl,
                    hint: '45 New Avenue, Kigali',
                    icon: Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 24),
                _buildHelpSupportSection(),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kTeal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kTeal.withAlpha(120),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('SAVE',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets (unchanged) ───────────────────────────────────────────────────
  Widget _buildAvatarPicker() {
    return Center(
      child: GestureDetector(
        onTap: _showImageSourceSheet,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _inputBg,
                border: Border.all(color: _kTeal, width: 2.5),
                boxShadow: [BoxShadow(color: _kTeal.withAlpha(40),
                    blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: ClipOval(child: SizedBox(width: 100, height: 100,
                  child: FittedBox(fit: BoxFit.cover,
                      child: _buildAvatar()))),
            ),
            Positioned(
              right: -2, bottom: -2,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange, shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      const SizedBox(height: 6),
      Container(
        decoration: _boxDeco(),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(fontSize: 14, color: _textCol),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _subCol, fontSize: 14),
            prefixIcon: icon != null
                ? Icon(icon, color: _d ? _kTealLight : _kTeal, size: 20)
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
                horizontal: icon == null ? 16 : 4,
                vertical: maxLines > 1 ? 12 : 0),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPhoneField() {
    final countryData = _countries.firstWhere(
        (c) => c['name'] == _country,
        orElse: () => _countries.first);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Phone number'),
      const SizedBox(height: 6),
      Container(
        decoration: _boxDeco(),
        child: Row(children: [
          GestureDetector(
            onTap: _pickCountry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: _borderCol, width: 1))),
              child: Row(children: [
                Text(countryData['flag']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(_phoneCode, style: TextStyle(fontSize: 13,
                    color: _textCol, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: _subCol, size: 18),
              ]),
            ),
          ),
          Expanded(child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.number,
            maxLength: 9,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(fontSize: 14, color: _textCol),
            decoration: InputDecoration(
              hintText: 'Enter 9 digits',
              hintStyle: TextStyle(color: _subCol, fontSize: 14),
              counterText: '',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 0)),
          )),
        ]),
      ),
    ]);
  }

  Widget _buildCountryField() {
    final countryData = _countries.firstWhere(
        (c) => c['name'] == _country,
        orElse: () => _countries.first);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Country'),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: _pickCountry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: _boxDeco(),
          child: Row(children: [
            Text(countryData['flag']!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text(_country,
                style: TextStyle(fontSize: 13, color: _textCol,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis)),
            Icon(Icons.keyboard_arrow_down_rounded, color: _subCol, size: 18),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildGenderField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Gender'),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: _boxDeco(),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _gender,
            isExpanded: true,
            dropdownColor: _cardBg,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: _subCol, size: 18),
            style: TextStyle(fontSize: 13, color: _textCol,
                fontWeight: FontWeight.w500),
            items: _genders.map((g) => DropdownMenuItem(
              value: g,
              child: Text(g, style: TextStyle(color: _textCol, fontSize: 13)),
            )).toList(),
            onChanged: (v) { if (v != null) setState(() => _gender = v); },
          ),
        ),
      ),
    ]);
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: _labelCol, letterSpacing: 0.3));

  BoxDecoration _boxDeco() => BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderCol),
      );

  bool _isValidEmail(String value) {
    final emailPattern = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    return emailPattern.hasMatch(value);
  }

  bool _isValidPhone(String value) {
    final normalized = value.replaceAll(RegExp(r'[\s\-()]+'), '');
    return RegExp(r'^[0-9]{9}$').hasMatch(normalized);
  }

  Widget _buildHelpSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Help & support',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: _textCol)),
        const SizedBox(height: 12),
        _buildFeatureTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'View our data privacy and transport app commitment.',
          onTap: _showPrivacyPolicy,
        ),
        const SizedBox(height: 10),
        _buildFeatureTile(
          icon: Icons.contact_support_outlined,
          title: 'Contact Us',
          subtitle: 'Reach support for account and booking help.',
          onTap: _showContactUs,
        ),
        const SizedBox(height: 10),
        _buildFeatureTile(
          icon: Icons.security_outlined,
          title: 'Security',
          subtitle: 'Manage MFA, verification, and account security.',
          onTap: _showSecuritySettings,
        ),
      ],
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _inputBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _d ? _kTeal.withAlpha(30) : _kTeal.withAlpha(16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _kTeal, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: _textCol,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: _subCol, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _subCol),
          ]),
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'We collect only the information required to manage bookings, contact you when necessary, and keep transport services safe. '
            'Your personal data is protected with standard security measures and is not shared with third parties without your consent. '
            'This privacy approach follows recommended bus transport app guidelines for transparency, data minimisation, and user control.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showContactUs() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Contact Us'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Reach us on any of the channels below:'),
            SizedBox(height: 12),
            Text('Email: support@movekigali.com'),
            SizedBox(height: 6),
            Text('Phone: +250 793 035 988'),
            SizedBox(height: 6),
            Text('Instagram: @moveKigali'),
            SizedBox(height: 6),
            Text('Facebook: /moveKigaliApp'),
            SizedBox(height: 6),
            Text('X: @moveKigaliRW'),
            SizedBox(height: 12),
            Text('We are available for account, booking, and app support.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showSecuritySettings() {
    bool mfaEnabled = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _d ? const Color(0xFF3A5060) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Security Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: _textCol)),
            const SizedBox(height: 18),
            SwitchListTile(
              value: mfaEnabled,
              activeColor: _kTeal,
              title: Text('Multi-factor authentication',
                  style: TextStyle(color: _textCol, fontWeight: FontWeight.w600)),
              subtitle: Text('Add an extra verification step for login.',
                  style: TextStyle(color: _subCol)),
              onChanged: (value) => setState(() => mfaEnabled = value),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              leading: Icon(Icons.password, color: _kTeal),
              title: Text('Update password', style: TextStyle(color: _textCol)),
              subtitle: Text('Change your account password securely.',
                  style: TextStyle(color: _subCol)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/create_new_password');
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              leading: Icon(Icons.phonelink_lock, color: _kTeal),
              title: Text('Edit verification method', style: TextStyle(color: _textCol)),
              subtitle: Text('Update your phone or email verification.',
                  style: TextStyle(color: _subCol)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/verify_password');
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
