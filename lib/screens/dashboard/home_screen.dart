import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movekigali/models/booking.dart';
import 'package:movekigali/screens/dashboard/edit_profile.dart';
import 'package:movekigali/screens/dashboard/notification.dart';
import 'package:movekigali/services/firestore_service.dart';
import 'package:movekigali/utils/download_utils.dart';
import 'package:movekigali/utils/localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _kTeal      = Color(0xFF02515F);
const _kTealLight = Color(0xFF038A9B);
// ignore: unused_element
const _kOrange    = Colors.orange;

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORTED LANGUAGES
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, String>> _kLanguages = [
  {'code': 'en', 'name': 'English',     'flag': '🇺🇸'},
  {'code': 'rw', 'name': 'Kinyarwanda', 'flag': '🇷🇼'},
  {'code': 'fr', 'name': 'French',      'flag': '🇫🇷'},
  {'code': 'sw', 'name': 'Swahili',     'flag': '🇰🇪'},
];

// ─────────────────────────────────────────────────────────────────────────────
// DRAWER ITEM MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _DrawerItemData {
  final IconData icon;
  final Color    iconColor;
  final String   titleKey;
  final bool     isLogout;
  final bool     isDarkToggle;
  final bool     isLanguage;
  const _DrawerItemData({
    required this.icon,
    required this.iconColor,
    required this.titleKey,
    this.isLogout     = false,
    this.isDarkToggle = false,
    this.isLanguage   = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final String  username;
  final String? profileImagePath;
  final String? userEmail;
  final String? nickName;
  final String? phoneNumber;

  const HomeScreen({
    super.key,
    required this.username,
    this.profileImagePath,
    this.userEmail,
    this.nickName,
    this.phoneNumber,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

Future<void> _shareText(String content) async {
  try {
    await Share.share(content);
  } catch (e) {
    debugPrint('Share failed: $e');
  }
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showBrandLabel = false;

  // ── Profile image builder ──────────────────────────────────────────────────
  Widget _buildProfileImage() {
    if (_profileImagePath != null) {
      try {
        if (_profileImagePath!.startsWith('data:image')) {
          return Image.memory(
            base64Decode(_profileImagePath!.split(',').last),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildInitialsAvatar(),
          );
        } else if (kIsWeb) {
          return Image.network(
            _profileImagePath!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildInitialsAvatar(),
          );
        } else {
          return Image.file(
            File(_profileImagePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildInitialsAvatar(),
          );
        }
      } catch (_) {
        return _buildInitialsAvatar();
      }
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final name = _userName?.isNotEmpty == true ? _userName! : widget.username;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kTeal, _kTealLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Controllers ────────────────────────────────────────────────────────────
  final _departureCtrl    = TextEditingController();
  final _destinationCtrl  = TextEditingController();
  final _depSearchCtrl    = TextEditingController();
  final _destSearchCtrl   = TextEditingController();
  final _scrollCtrl       = ScrollController();
  final _pageCtrl         = PageController();

  // ── State ──────────────────────────────────────────────────────────────────
  DateTime? _selectedDate;
  int _people = 1;
  // Dynamic buspoints: +1 per confirmed booking
  int _buspoints = 0;

  String _busNumber = 'RAB 456 C';
  static const String _busType = 'Medium';
  String _depTime   = '08:30';
  String _arrTime   = '10:45';
  String _currentLoc = 'Nyabugogo Park';
  String _destLoc    = 'Kimironko Park';
  int    _timeLeft   = 25;

  int  _navIndex    = 0;
  bool _showNav     = true;
  bool _drawerOpen  = false;
  int  _drawerHover = -1;
  int  _activeField = -1;

  bool   _isDarkMode = false;
  String _language   = 'rw';

  // Profile state
  String? _userName;
  String? _profileImagePath;
  String? _userEmail;
  String? _nickName;
  String? _phoneNumber;

  // ── Notification badge counter ─────────────────────────────────────────────
  // Starts at 3 (matching the 3 system events already present).
  // Incremented by in-app actions; cleared when user visits notification page.
  int _unreadCount = 3;

  List<String> _depList  = [];
  List<String> _destList = [];

  // ── Rwanda stations ────────────────────────────────────────────────────────
  static const List<Map<String, String>> _stations = [
    {'name': 'Nyabugogo Park',      'detail': 'Central Bus Station'},
    {'name': 'Gisimenti',           'detail': 'Gisimenti Bus Stop'},
    {'name': 'Kimironko Park',      'detail': 'Kimironko Bus Terminal'},
    {'name': 'Kinyinya Park',       'detail': 'Kinyinya Station'},
    {'name': 'Gasanze Park',        'detail': 'Gasanze Terminal'},
    {'name': 'Kagugu Park',         'detail': 'Kagugu Bus Stop'},
    {'name': 'Nyacyongo Park',      'detail': 'Nyacyongo Station'},
    {'name': 'Batsinda Park',       'detail': 'Batsinda Terminal'},
    {'name': 'Nyamirambo Park',     'detail': 'Nyamirambo Station'},
    {'name': 'Chez Lando',          'detail': 'Chez Lando Bus Stop'},
    {'name': 'Remera Park',         'detail': 'Remera Terminal'},
    {'name': 'Jabana Park',         'detail': 'Jabana Station'},
    {'name': 'Zindiro',             'detail': 'Zindiro Bus Stop'},
    {'name': 'Kabuga Park',         'detail': 'Kabuga Terminal'},
    {'name': 'Kanyinya Park',       'detail': 'Kanyinya Station'},
    {'name': 'Kicukiro Park',       'detail': 'Kicukiro Terminal'},
    {'name': 'Kibagabaga Park',     'detail': 'Kibagabaga Station'},
    {'name': 'DownTown Kigali Park','detail': 'Downtown Terminal'},
    {'name': 'Sonatubes Park',      'detail': 'Sonatubes Station'},
    {'name': 'Masaka Park',         'detail': 'Masaka Terminal'},
    {'name': 'Gikondo Park',        'detail': 'Gikondo Station'},
    {'name': 'Kanombe Park',        'detail': 'Kanombe Terminal'},
    {'name': 'Gishushu Park',       'detail': 'Gishushu Bus Stop'},
    {'name': 'Kinamba',             'detail': 'Kinamba Station'},
    {'name': 'Rwandex',             'detail': 'Rwandex Bus Stop'},
    {'name': 'Mulindi',             'detail': 'Mulindi Terminal'},
    {'name': 'Nyanza Park',         'detail': 'Nyanza Station'},
    {'name': 'Ndera Park',          'detail': 'Ndera Terminal'},
    {'name': 'Kigali CBD',          'detail': 'City Centre Stop'},
    {'name': 'Rebero Park',         'detail': 'Rebero Terminal'},
    {'name': 'Gahanga Park',        'detail': 'Gahanga Station'},
    {'name': 'Bugesera Park',       'detail': 'Bugesera Terminal'},
    {'name': 'Shyorongi Park',      'detail': 'Shyorongi Station'},
    {'name': 'Masizi Park',         'detail': 'Masizi Station'},
    {'name': 'Kacyiru Park',        'detail': 'Kacyiru Station'},
    {'name': 'CBD',                 'detail': 'Business District'},
    {'name': 'Bwerankoli',          'detail': 'Bus Terminal'},
    {'name': 'Rubilizi',            'detail': 'Bus Terminal'},
    {'name': 'Kibaya',              'detail': 'Bus Terminal'},
    {'name': 'Musave',              'detail': 'Bus Terminal'},
    {'name': 'Kimihurura',          'detail': 'Bus Terminal'},
    {'name': 'Busanza',             'detail': 'Bus Terminal'},
    {'name': 'Kabeza',              'detail': 'Bus Terminal'},
    {'name': 'SEZ',                 'detail': 'Bus Terminal'},
    {'name': 'Masoro',              'detail': 'Bus Terminal'},
    {'name': 'Gasogi',              'detail': 'Bus Terminal'},
    {'name': 'Muyange',             'detail': 'Bus Terminal'},
    {'name': 'Zinia MKT',           'detail': 'Bus Terminal'},
    {'name': 'Saint Joseph',        'detail': 'Bus Terminal'},
    {'name': 'Birembo',             'detail': 'Bus Terminal'},
    {'name': 'Nyarutarama',         'detail': 'Bus Terminal'},
    {'name': 'Agakiriro ka Gisozi', 'detail': 'Bus Terminal'},
    {'name': 'UTEXRWA',             'detail': 'Bus Terminal'},
    {'name': 'ULK',                 'detail': 'Bus Terminal'},
    {'name': 'CYUMBATI',            'detail': 'Bus Terminal'},
    {'name': 'MAGERAGERE',          'detail': 'Bus Terminal'},
    {'name': 'GIHARA',              'detail': 'Bus Terminal'},
    {'name': 'KARAMA',              'detail': 'Bus Terminal'},
    {'name': 'ERP NYAMIRAMBO',      'detail': 'Bus Terminal'},
    {'name': 'BISHENYI',            'detail': 'Bus Terminal'},
    {'name': 'RYANYUMA',            'detail': 'Bus Terminal'},
    {'name': 'KIMISAGARA',          'detail': 'Bus Terminal'},
    {'name': 'BWERAMVURA',          'detail': 'Bus Terminal'},
    {'name': 'Musanze Park',        'detail': 'Northern Province'},
    {'name': 'Huye Park',           'detail': 'Southern Province'},
    {'name': 'Rubavu Park',         'detail': 'Western Province'},
    {'name': 'Rusizi Park',         'detail': 'Western Province'},
    {'name': 'Kayonza Park',        'detail': 'Eastern Province'},
    {'name': 'Rwamagana Park',      'detail': 'Eastern Province'},
    {'name': 'Muhanga Park',        'detail': 'Southern Province'},
    {'name': 'Karongi Park',        'detail': 'Western Province'},
  ];

  static final List<String> _stationNames =
      _stations.map((s) => s['name']!).toList();

  // ── History — starts empty; entries added only when user books a ticket ────
  final List<Map<String, dynamic>> _history = [];

  // ── Dark-mode colour helpers ────────────────────────────────────────────────
  Color get _dmCard    => _isDarkMode ? const Color(0xFF1A2830) : Colors.white;
  Color get _dmCardAlt => _isDarkMode ? const Color(0xFF223038) : Colors.grey.shade100;
  Color get _dmInput   => _isDarkMode ? const Color(0xFF1E2E36) : Colors.grey.shade50;
  Color get _dmText    => _isDarkMode ? const Color(0xFFF0F4F6) : Colors.black87;
  Color get _dmSubText => _isDarkMode ? Colors.white70 : Colors.grey.shade600;
  Color get _dmBorder  => _isDarkMode ? const Color(0xFF3A5060) : Colors.grey.shade200;
  Color get _dmScaffold=> _isDarkMode ? const Color(0xFF0D1C22) : _kTeal;
  Color get _dmHandle  => _isDarkMode ? const Color(0xFF4A6070) : Colors.grey.shade300;
  Color get _dmNavBg   => _isDarkMode ? const Color(0xFF152028) : Colors.white;
  Color get _dmNavSel  => _isDarkMode ? _kTealLight : _kTeal;
  Color get _dmNavUnsel=> _isDarkMode ? const Color(0xFF4A6070) : Colors.grey.shade400;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _depList  = List.from(_stationNames);
    _destList = List.from(_stationNames);
    _scrollCtrl.addListener(_onScroll);
    _userName         = widget.username;
    _profileImagePath = widget.profileImagePath;
    _userEmail        = widget.userEmail;
    _nickName         = widget.nickName;
    _phoneNumber      = widget.phoneNumber;
    _loadBookingHistory();
    _loadThemePreference();
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _showBrandLabel = true);
    });
  }

  Future<void> _loadBookingHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final bookings = await FirestoreService.getBookingsForUser(uid);
      final userData = await FirestoreService.getUserData(uid);
      final buspoints = userData?.buspoints ?? 0;
      if (!mounted) return;
      setState(() {
        _history.clear();
        _history.addAll(bookings.map((b) => {
          'id': b.id,
          'from': b.from,
          'to': b.to,
          'date': b.date,
          'time': b.time,
          'price': b.price,
          'paymentMethod': b.paymentMethod,
          'status': 'Not yet Scanned',
        }));
        _buspoints = buspoints;
        if (userData != null) {
          if (userData.name.isNotEmpty) _userName = userData.name;
          if (userData.email.isNotEmpty) _userEmail = userData.email;
          if (userData.nickName.isNotEmpty) _nickName = userData.nickName;
          if (userData.profileImage.isNotEmpty) _profileImagePath = userData.profileImage;
          if (userData.phone.isNotEmpty) _phoneNumber = userData.phone;
        }
      });
    } catch (e) {
      debugPrint('Failed to load booking history: $e');
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username          != widget.username ||
        oldWidget.profileImagePath  != widget.profileImagePath ||
        oldWidget.userEmail         != widget.userEmail ||
        oldWidget.nickName          != widget.nickName ||
        oldWidget.phoneNumber       != widget.phoneNumber) {
      setState(() {
        _userName         = widget.username;
        _profileImagePath = widget.profileImagePath;
        _userEmail        = widget.userEmail;
        _nickName         = widget.nickName;
        _phoneNumber      = widget.phoneNumber;
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    _pageCtrl.dispose();
    _departureCtrl.dispose();
    _destinationCtrl.dispose();
    _depSearchCtrl.dispose();
    _destSearchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final show = _scrollCtrl.position.pixels <= 50;
    if (show != _showNav) setState(() => _showNav = show);
  }

  String _t(String key) => translate(key, _language);
  String _languageName() => languageName(_language);

  // ── Drawer ─────────────────────────────────────────────────────────────────
  void _toggleDrawer() => setState(() => _drawerOpen = !_drawerOpen);
  void _closeDrawer()  => setState(() => _drawerOpen = false);

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('moveKigali_dark_mode');
    if (saved != null && mounted) {
      setState(() => _isDarkMode = saved);
    }
  }

  Future<void> _saveThemePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('moveKigali_dark_mode', value);
  }

  // ── Route helper ───────────────────────────────────────────────────────────
  static Route<void> _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 220),
  );

  // ── Swap ───────────────────────────────────────────────────────────────────
  void _swap() {
    if (_departureCtrl.text.isEmpty && _destinationCtrl.text.isEmpty) {
      _snack(_t('please_select_departure_and_destination_first'), Colors.orange);
      return;
    }
    setState(() {
      final tmp = _departureCtrl.text;
      _departureCtrl.text  = _destinationCtrl.text;
      _destinationCtrl.text = tmp;
      _depSearchCtrl.text  = _departureCtrl.text;
      _destSearchCtrl.text = _destinationCtrl.text;
      _updateBusTimes();
    });
    _snack(_t('departure_destination_switched'), _kTeal);
  }

  void _updateBusTimes() {
    if (_departureCtrl.text.isEmpty || _destinationCtrl.text.isEmpty) return;
    final h = (_departureCtrl.text.hashCode + _destinationCtrl.text.hashCode).abs();
    _busNumber = 'RAB ${45 + (h % 100)} ${String.fromCharCode(65 + (h % 26))}';
    _depTime   = '${8 + (h % 4)}:${(30 + (h % 20)).toString().padLeft(2, '0')}';
    _arrTime   = '${10 + (h % 6)}:${(15 + (h % 30)).toString().padLeft(2, '0')}';
    _timeLeft  = 15 + (h % 45);
  }

  // ── Station filter ─────────────────────────────────────────────────────────
  void _filterDep() {
    final q = _depSearchCtrl.text.toLowerCase();
    setState(() {
      _depList = q.isEmpty
          ? List.from(_stationNames)
          : _stationNames.where((s) => s.toLowerCase().contains(q)).toList();
    });
  }

  void _filterDest() {
    final q = _destSearchCtrl.text.toLowerCase();
    setState(() {
      _destList = q.isEmpty
          ? List.from(_stationNames)
          : _stationNames.where((s) => s.toLowerCase().contains(q)).toList();
    });
  }

  // ── Pickers ────────────────────────────────────────────────────────────────
  void _openDepPicker() {
    _depList = List.from(_stationNames);
    _depSearchCtrl.clear();
    setState(() => _activeField = 0);
    _showStationSheet(
      title: _t('select_departure'),
      ctrl: _depSearchCtrl,
      getList: () => _depList,
      onFilter: _filterDep,
      onSelect: (s) => setState(() {
        _departureCtrl.text = s;
        _depSearchCtrl.text = s;
        _activeField = -1;
      }),
    ).whenComplete(() => setState(() => _activeField = -1));
  }

  void _openDestPicker() {
    _destList = List.from(_stationNames);
    _destSearchCtrl.clear();
    setState(() => _activeField = 1);
    _showStationSheet(
      title: _t('select_destination'),
      ctrl: _destSearchCtrl,
      getList: () => _destList,
      onFilter: _filterDest,
      onSelect: (s) => setState(() {
        _destinationCtrl.text = s;
        _destSearchCtrl.text  = s;
        _activeField = -1;
      }),
    ).whenComplete(() => setState(() => _activeField = -1));
  }

  void _openPassPicker() {
    setState(() => _activeField = 2);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PassengerSheet(
        current: _people,
        isDark: _isDarkMode,
        languageCode: _language,
        onSelect: (v) => setState(() => _people = v),
      ),
    ).whenComplete(() => setState(() => _activeField = -1));
  }

  Future<void> _openDatePicker() async {
    setState(() => _activeField = 3);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DatePickerSheet(
        initial: _selectedDate,
        isDark: _isDarkMode,
        languageCode: _language,
        onSave: (d) => setState(() => _selectedDate = d),
      ),
    );
    setState(() => _activeField = -1);
  }

  Future<void> _showStationSheet({
    required String title,
    required TextEditingController ctrl,
    required List<String> Function() getList,
    required VoidCallback onFilter,
    required void Function(String) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StationSheet(
        title: title,
        searchCtrl: ctrl,
        getList: getList,
        onFilter: onFilter,
        onSelect: onSelect,
        stations: _stations,
        languageCode: _language,
        isDark: _isDarkMode,
      ),
    );
  }

  // ── Language picker ────────────────────────────────────────────────────────
  void _openLanguagePicker() {
    _closeDrawer();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(
        current: _language,
        isDark: _isDarkMode,
        onSelect: (lang) => setState(() => _language = lang),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  void _searchTicket() {
    // Validate departure
    if (_departureCtrl.text.isEmpty) {
      _snack(_t('please_select_a_departure_point'), Colors.orange);
      return;
    }
    // Validate destination
    if (_destinationCtrl.text.isEmpty) {
      _snack(_t('please_select_a_destination'), Colors.orange);
      return;
    }
    // Validate same station
    if (_departureCtrl.text == _destinationCtrl.text) {
      _snack(_t('depart_same_warning'), Colors.orange);
      return;
    }
    // Validate date
    if (_selectedDate == null) {
      _snack(_t('please_select_a_travel_date'), Colors.orange);
      return;
    }

    setState(() {
      _currentLoc = _departureCtrl.text;
      _destLoc    = _destinationCtrl.text;
      _updateBusTimes();
      _unreadCount++;
    });

    // Navigate to schedule results screen
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ScheduleResultScreen(
          from:         _departureCtrl.text,
          to:           _destinationCtrl.text,
          date:         _selectedDate!,
          passengers:   _people,
          isDark:       _isDarkMode,
          buspoints:    _buspoints,
          languageCode: _language,
          onBookingConfirmed: (entry) async {
            final id = entry['id'] as String? ?? 'local-${DateTime.now().millisecondsSinceEpoch}';
            setState(() {
              _history.add({
                'id':            id,
                'from':          entry['from'],
                'to':            entry['to'],
                'date':          entry['date'],
                'time':          entry['time'],
                'price':         entry['price'],
                'paymentMethod': entry['paymentMethod'],
                'transactionId': entry['transactionId'],
                'status':        'Not yet Scanned',
              });
              _buspoints++; // +1 point per confirmed booking
              _unreadCount++;
            });
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null && id.startsWith('local-')) {
              try {
                final booking = Booking(
                  id: '',
                  uid: uid,
                  from: entry['from'] as String,
                  to: entry['to'] as String,
                  date: entry['date'] as String,
                  time: entry['time'] as String,
                  passengers: entry['passengers'] as int,
                  price: entry['price'] as int,
                  passengerName: entry['passengerName'] as String,
                  phoneNumber: entry['phoneNumber'] as String,
                  paymentMethod: entry['paymentMethod'] as String,
                  busNumber: entry['busNumber'] as String,
                  routeType: entry['routeType'] as String,
                  transactionId: entry['transactionId'] as String? ?? 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}',
                  createdAt: DateTime.now(),
                );
                final savedId = await FirestoreService.createBooking(booking);
                setState(() {
                  final idx = _history.indexWhere((e) => e['id'] == id);
                  if (idx != -1) {
                    _history[idx]['id'] = savedId;
                  }
                });
              } catch (e) {
                debugPrint('Failed to save booking: $e');
              }
            }
          },
          // Allow user to change selections → returns with updated data
          onChangeRequested: (from, to, date, passengers) {
            setState(() {
              _departureCtrl.text   = from;
              _destinationCtrl.text = to;
              _selectedDate         = date;
              _people               = passengers;
            });
          },
        ),
        transitionsBuilder: (_, anim, _, child) =>
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  // Indices: 0=Home  1=Activity  2=LiveMap  3=Profile
  void _onNavTap(int i) {
    if (i == 0) {
      setState(() => _navIndex = 0);
      return;
    }
    setState(() => _navIndex = i);

    Widget? dest;
    switch (i) {
      case 1:
        dest = ActivityScreen(
          isDark: _isDarkMode,
          languageCode: _language,
          history: _history,
          onDelete: _deleteHistory,
        );
        break;
      case 2:
        dest = LiveMapScreen(isDark: _isDarkMode, languageCode: _language);
        break;
      case 3:
        dest = EditProfileScreen(
          isDark: _isDarkMode,
          username: _userName ?? widget.username,
          currentImagePath: _profileImagePath,
          currentEmail: _userEmail,
          currentNickName: _nickName,
          currentPhone: _phoneNumber,
          onSave: (profileData) {
            setState(() {
              _userName         = profileData.fullName;
              _profileImagePath = profileData.imagePath;
              _userEmail        = profileData.email;
              _nickName         = profileData.nickName;
              if (profileData.phone != null) _phoneNumber = profileData.phone;
            });
          },
        );
        break;
    }
    if (dest != null) {
      Navigator.push(context, _fade(dest))
          .then((_) => setState(() => _navIndex = 0));
    }
  }

  // ── Notifications bell (top nav) ───────────────────────────────────────────
  void _notifs() {
    // Clear badge before entering the screen
    setState(() => _unreadCount = 0);
    Navigator.push(context, _fade(NotificationScreen(isDark: _isDarkMode)));
  }

  // ── Snackbar ───────────────────────────────────────────────────────────────
  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Delete history ─────────────────────────────────────────────────────────
  void _deleteHistory(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _dmCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   Text(translate('delete_trip', _language), style: TextStyle(color: _dmText)),
        content: Text(translate('remove_history_confirmation', _language),
            style: TextStyle(color: _dmSubText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(translate('cancel', _language))),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirestoreService.deleteBooking(id);
              } catch (_) {
                // Ignore missing document or offline state.
              }
              if (!mounted) return;
              setState(() => _history.removeWhere((e) => e['id'] == id));
              Navigator.pop(context);
              _snack(translate('trip_removed', _language), Colors.green);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(translate('delete', _language)),
          ),
        ],
      ),
    );
  }

  // ── Redeem ─────────────────────────────────────────────────────────────────
  void _redeem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RedeemSheet(
        isDark: _isDarkMode,
        languageCode: _language,
        buspoints: _buspoints,
        onConfirm: () {
          // Redemption triggers a new notification
          setState(() => _unreadCount++);
          _snack(translate('points_redeemed_successfully', _language), Colors.green);
        },
      ),
    );
  }

  // ── Bus detail ─────────────────────────────────────────────────────────────
  void _busDetail() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _dmCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: _dmHandle,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(translate('bus_details', _language),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _dmText)),
          const SizedBox(height: 16),
          _row(translate('bus_number', _language),  _busNumber),
          _row(translate('bus_type', _language),    _busType),
          _row(translate('departure', _language),   _depTime),
          _row(translate('arrival', _language),     _arrTime),
          _row(translate('duration', _language),    '$_timeLeft min'),
          _row(translate('from', _language),        _currentLoc),
          _row(translate('to', _language),          _destLoc),
          _row(translate('passengers', _language),  '$_people'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(translate('close', _language)),
          ),
        ]),
      ),
    );
    _closeDrawer();
  }

  Widget _row(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: _dmSubText)),
        Text(val,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: _dmText)),
      ],
    ),
  );

  // ── View all history ───────────────────────────────────────────────────────
  void _viewAll() {
    _closeDrawer();
    Navigator.push(
      context,
      _fade(ActivityScreen(
          isDark: _isDarkMode,
          languageCode: _language,
          history: _history,
          onDelete: _deleteHistory)),
    );
  }

  // ── Greeting ───────────────────────────────────────────────────────────────
  String get _greeting {
    if (_language == 'rw') return 'Muraho';
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ── Drawer nav helpers ─────────────────────────────────────────────────────
  void _qrScan() {
    _closeDrawer();
    Navigator.push(context, _fade(QRScanScreen(isDark: _isDarkMode, languageCode: _language)));
  }

  void _profile() {
    _closeDrawer();
    Navigator.push(
      context,
      _fade(EditProfileScreen(
        isDark: _isDarkMode,
        username: _userName ?? widget.username,
        currentImagePath: _profileImagePath,
        currentEmail: _userEmail,
        currentNickName: _nickName,
        currentPhone: _phoneNumber,
        onSave: (profileData) {
          setState(() {
            _userName         = profileData.fullName;
            _profileImagePath = profileData.imagePath;
            _userEmail        = profileData.email;
            _nickName         = profileData.nickName;
            if (profileData.phone != null) _phoneNumber = profileData.phone;
          });
        },
      )),
    );
  }

  void _payments() {
    _closeDrawer();
    Navigator.push(
        context, _fade(PaymentMethodsScreen(isDark: _isDarkMode, languageCode: _language)));
  }

  void _help() {
    _closeDrawer();
    Navigator.push(context, _fade(HelpCenterScreen(isDark: _isDarkMode, languageCode: _language)));
  }

  void _about() {
    _closeDrawer();
    Navigator.push(context, _fade(AboutScreen(isDark: _isDarkMode, languageCode: _language)));
  }

  void _terms() {
    _closeDrawer();
    Navigator.push(context, _fade(TermsScreen(isDark: _isDarkMode, languageCode: _language)));
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _dmCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   Text(translate('logout', _language), style: TextStyle(color: _dmText)),
        content: Text(translate('logout_confirmation', _language),
            style: TextStyle(color: _dmSubText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(translate('cancel', _language))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              _closeDrawer();
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(translate('logout', _language)),
          ),
        ],
      ),
    );
  }

  // ── Field decoration ───────────────────────────────────────────────────────
  BoxDecoration _fieldDeco(int idx) {
    final active = _activeField == idx;
    return BoxDecoration(
      color: active ? _kTeal.withAlpha(18) : _dmInput,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: active ? _kTeal : _dmBorder,
          width: active ? 1.8 : 1.0),
    );
  }

  Widget _field({
    required int      idx,
    required IconData icon,
    required String   hint,
    required String   value,
    required bool     hasVal,
    required VoidCallback onTap,
  }) {
    final active = _activeField == idx;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _fieldDeco(idx),
        child: Row(children: [
          Icon(icon,
              color: active || hasVal ? _kTeal : _dmSubText, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasVal ? value : hint,
              style: TextStyle(
                  color: hasVal ? _dmText : _dmSubText,
                  fontSize: 15,
                  fontWeight:
                      hasVal ? FontWeight.w500 : FontWeight.normal),
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: active ? _kTeal : _dmSubText, size: 22),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _dmScaffold,
        body: Stack(children: [
          Positioned.fill(
              child: _BackgroundGradient(isDark: _isDarkMode)),

          SafeArea(
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildHeader(sw),
                          const SizedBox(height: 24),
                          _buildGreeting(),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _t('safe_travel'),
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildFormCard(sw),
                          const SizedBox(height: 20),
                          _buildBuspointCard(),
                          const SizedBox(height: 20),
                          _buildHistorySection(),
                        ]),
                  ),
                ),
              ],
            ),
          ),

          // Blur overlay
          if (_drawerOpen)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: ColoredBox(color: Colors.black.withAlpha(60)),
              ),
            ),

          // Bottom nav (4 items – no Notifications tab)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            left: 0, right: 0,
            bottom: _showNav ? 0 : -84,
            child: RepaintBoundary(child: _buildBottomNav()),
          ),

          // Drawer
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            right: _drawerOpen ? 0 : -sw * 0.82,
            top: 0, bottom: 0,
            width: sw * 0.82,
            child: RepaintBoundary(child: _buildDrawer()),
          ),

          // Tap outside to close drawer
          if (_drawerOpen)
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: sw * 0.18,
              child: GestureDetector(
                onTap: _closeDrawer,
                child:
                    const ColoredBox(color: Colors.transparent),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(double sw) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Image.asset(
          'assets/images/logo1.png',
          width: sw * 0.18, height: 44,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        AnimatedOpacity(
          opacity: _showBrandLabel ? 1 : 0,
          duration: const Duration(milliseconds: 420),
          child: Text(
            'moveKigali',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
        ),
        const Spacer(),
        Row(children: [
          _iconBtn(FontAwesomeIcons.qrcode, _qrScan),
          const SizedBox(width: 8),
          // ── Bell with red badge ──────────────────────────────────────────
          _bellBtn(),
          const SizedBox(width: 8),
          _iconBtn(FontAwesomeIcons.gear, _toggleDrawer),
        ]),
      ]),
    );
  }

  /// Bell icon button with unread-count badge.
  Widget _bellBtn() {
    return GestureDetector(
      onTap: _notifs,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: FaIcon(FontAwesomeIcons.bell,
              size: 40 * 0.44, color: Colors.white),
          ),
          if (_unreadCount > 0)
            Positioned(
              top: -2, right: -2,
              child: Container(
                padding: EdgeInsets.all(_unreadCount > 9 ? 3 : 4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconBtn(dynamic icon, VoidCallback onTap,
      {double size = 40, Color? bg, Color? fg}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: bg ?? Colors.white.withAlpha(30),
          shape: BoxShape.circle,
        ),
        child: icon is FaIconData
            ? FaIcon(icon, size: size * 0.44, color: fg ?? Colors.white)
            : Icon(icon, size: size * 0.44, color: fg ?? Colors.white),
      ),
    );
  }

  // ── Greeting ───────────────────────────────────────────────────────────────
  Widget _buildGreeting() {
    final displayName = (_userName ?? widget.username).split(' ').first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
          child: Text(
            '$_greeting, $displayName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
      ]),
    );
  }

  // ── Form card ──────────────────────────────────────────────────────────────
  Widget _buildFormCard(double sw) {
    return Container(
      margin:  EdgeInsets.symmetric(horizontal: sw > 900 ? 64 : (sw > 600 ? 32 : 16)),
      padding: const EdgeInsets.fromLTRB(20, 20, 38, 24),
      decoration: BoxDecoration(
        color: _dmCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(36),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _t('complete_form'),
          style: TextStyle(fontSize: 13, color: _dmSubText),
        ),
        const SizedBox(height: 18),

        Stack(clipBehavior: Clip.none, children: [
          Column(children: [
            _FieldLabel(_t('departure'), isDark: _isDarkMode),
            const SizedBox(height: 7),
            _field(
              idx: 0,
              icon: Icons.trip_origin_rounded,
              hint: _t('select_departure'),
              value: _departureCtrl.text,
              hasVal: _departureCtrl.text.isNotEmpty,
              onTap: _openDepPicker,
            ),
            const SizedBox(height: 12),
            _FieldLabel(_t('destination'), isDark: _isDarkMode),
            const SizedBox(height: 7),
            _field(
              idx: 1,
              icon: Icons.location_on_rounded,
              hint: _t('select_destination'),
              value: _destinationCtrl.text,
              hasVal: _destinationCtrl.text.isNotEmpty,
              onTap: _openDestPicker,
            ),
          ]),
          Positioned(
            right: -19, top: 58,
            child: GestureDetector(
              onTap: _swap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.orange.shade400, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.orange.withAlpha(40),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 3)),
                    BoxShadow(
                        color: Colors.black.withAlpha(18),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.swap_vert_rounded,
                    color: Colors.orange, size: 22),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 14),
        _FieldLabel(_t('passengers'), isDark: _isDarkMode),
        const SizedBox(height: 7),
        _field(
          idx: 2,
          icon: Icons.person_rounded,
          hint: _t('select_passengers'),
          value: '$_people ${_t('passengers')}',
          hasVal: true,
          onTap: _openPassPicker,
        ),

        const SizedBox(height: 14),
        _FieldLabel(_t('travel_date'), isDark: _isDarkMode),
        const SizedBox(height: 7),
        _field(
          idx: 3,
          icon: Icons.calendar_today_rounded,
          hint: _t('select_travel_date'),
          value: _selectedDate != null
              ? DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate!)
              : '',
          hasVal: _selectedDate != null,
          onTap: _openDatePicker,
        ),

        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _searchTicket,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _t('search_ticket'),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Buspoint card ──────────────────────────────────────────────────────────
  Widget _buildBuspointCard() {
    final sw = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: sw > 900 ? 64 : (sw > 600 ? 32 : 16)),
      decoration: BoxDecoration(
        color: _dmCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(24),
              blurRadius: 18,
              offset: const Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: [
          // Teal header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [_kTeal, _kTealLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Row(children: [
              const Icon(Icons.card_giftcard,
                  color: Colors.white, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_t('buspoints'),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('$_buspoints pt',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22)),
                ]),
              ),
              _iconBtn(FontAwesomeIcons.qrcode, _qrScan,
                  size: 40,
                  bg: Colors.white.withAlpha(40),
                  fg: Colors.white),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _redeem,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(_t('redeem'),
                      style: const TextStyle(
                          color: _kTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
            ]),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(24),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_bus,
                        color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(translate('bus_number', _language),
                        style: TextStyle(
                            color: _dmSubText, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(_busNumber,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _dmText)),
                  ]),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: _dmCardAlt,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    const Icon(Icons.schedule,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(_busType,
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: _dmText)),
                  ]),
                ),
              ]),

              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_depTime,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _dmText)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_currentLoc,
                            style: TextStyle(
                                color: _dmText,
                                fontWeight: FontWeight.w500,
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ]),
                ),
                Expanded(
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8),
                        color: _dmBorder),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _dmCard,
                        border: Border.all(
                            color: Colors.orange.shade300, width: 1.5),
                        shape: BoxShape.circle,
                      ),
                      child: Text('$_timeLeft',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ),
                  ]),
                ),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                    Text(_arrTime,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _dmText)),
                    const SizedBox(height: 4),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                      Expanded(
                        child: Text(_destLoc,
                            style: TextStyle(
                                color: _dmText,
                                fontWeight: FontWeight.w500,
                                fontSize: 12),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle)),
                    ]),
                  ]),
                ),
              ]),

              const SizedBox(height: 14),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Row(children: [
                  _chip(Icons.restaurant, '1 ${_t('meal')}', Colors.orange),
                  const SizedBox(width: 8),
                  _chip(Icons.person,
                      '$_people Passenger${_people > 1 ? 's' : ''}',
                      _kTeal),
                ]),
                GestureDetector(
                  onTap: _busDetail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(25)),
                    child: Row(children: [
                      Text(_t('detail'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 14),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(24),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(50)),
    ),
    child: Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: _dmText,
              fontWeight: FontWeight.w500,
              fontSize: 12)),
    ]),
  );

  // ── History section ────────────────────────────────────────────────────────
  Widget _buildHistorySection() {
    final hasHistory = _history.isNotEmpty;
    final sw = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: sw > 900 ? 64 : (sw > 600 ? 32 : 16)),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
      decoration: BoxDecoration(
        color: _dmCard,
        borderRadius: const BorderRadius.all(Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(_t('history'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _dmText)),
          const SizedBox(width: 8),
          if (hasHistory)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_history.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          const Spacer(),
          if (hasHistory)
            TextButton(
              onPressed: _viewAll,
              style: TextButton.styleFrom(foregroundColor: _kTeal),
              child: Row(children: [
                Text(translate('view_all', _language),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 13),
              ]),
            ),
        ]),
        const SizedBox(height: 14),

        if (!hasHistory) ...[
          // Empty state — shown until first booking is made
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: _kTeal.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.history_rounded,
                    size: 36,
                    color: _isDarkMode
                        ? const Color(0xFF3A6070)
                        : Colors.grey.shade400),
              ),
              const SizedBox(height: 14),
              Text(translate('no_trips_headline', _language),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _dmText)),
              const SizedBox(height: 6),
              Text(
                translate('no_trips_subtitle', _language),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: _dmSubText,
                    height: 1.55),
              ),
            ]),
          ),
        ] else ...[
          ..._history.take(3).map((e) => _HistoryTile(
                from: e['from']!, to: e['to']!,
                date: e['date']!, time: e['time']!,
                price: e['price'] as int,
                paymentMethod: e['paymentMethod'] as String? ?? 'Unknown',
                status: e['status'] as String? ?? 'Not yet Scanned',
                languageCode: _language,
                id: e['id'] as String,
                onDelete: _deleteHistory, isDark: _isDarkMode,
              )),
        ],
      ]),
    );
  }

  // ── Bottom nav (4 items) ───────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _dmNavBg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin:
              const EdgeInsets.only(top: 8, bottom: 2),
          width: 34, height: 4,
          decoration: BoxDecoration(
              color: _dmHandle,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded,    _t('home'),      0),
              _navItem(Icons.history_rounded, _t('activity'),  1),
              _navItem(Icons.map_rounded,     _t('live_map'),  2),
              _navItem(Icons.person_rounded,  _t('profile'),   3),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final sel = _navIndex == idx;
    return GestureDetector(
      onTap: () => _onNavTap(idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel
              ? _dmNavSel.withAlpha(20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: sel ? _dmNavSel : _dmNavUnsel, size: 22),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: sel ? _dmNavSel : _dmNavUnsel,
                  fontSize: 10,
                  fontWeight: sel
                      ? FontWeight.w700
                      : FontWeight.normal)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS DRAWER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDrawer() {
    final drawerBg  = _isDarkMode ? const Color(0xFF111C22) : Colors.white;
    final dividerCol = _isDarkMode
        ? const Color(0xFF1E2E38)
        : Colors.grey.shade100;
    final headerBg  = _isDarkMode ? const Color(0xFF162028) : Colors.white;

    final items = <_DrawerItemData>[
      const _DrawerItemData(icon: Icons.person_outline,  iconColor: Color(0xFF4A90D9), titleKey: 'profile'),
      const _DrawerItemData(icon: Icons.history,         iconColor: Color(0xFF7B61FF), titleKey: 'trip_history'),
      const _DrawerItemData(icon: Icons.payment,         iconColor: Color(0xFF27AE60), titleKey: 'payment_methods'),
      const _DrawerItemData(icon: Icons.card_giftcard,   iconColor: Color(0xFFE67E22), titleKey: 'buspoints'),
      const _DrawerItemData(icon: Icons.notifications_outlined, iconColor: Color(0xFFE74C3C), titleKey: 'notifications'),
      const _DrawerItemData(icon: Icons.language,        iconColor: Color(0xFF1ABC9C), titleKey: 'language', isLanguage: true),
      const _DrawerItemData(icon: Icons.help_outline,    iconColor: Color(0xFF3498DB), titleKey: 'help_center'),
      const _DrawerItemData(icon: Icons.info_outline,    iconColor: Color(0xFF9B59B6), titleKey: 'about'),
      const _DrawerItemData(icon: Icons.description,     iconColor: Color(0xFF2ECC71), titleKey: 'terms_conditions'),
      const _DrawerItemData(icon: Icons.dark_mode_rounded, iconColor: Color(0xFF5B8DEF), titleKey: 'dark_mode', isDarkToggle: true),
      const _DrawerItemData(icon: Icons.logout,          iconColor: Color(0xFFE74C3C), titleKey: 'logout', isLogout: true),
    ];

    VoidCallback? getAction(_DrawerItemData item) {
      if (item.isDarkToggle || item.isLogout) return null;
      if (item.isLanguage) return _openLanguagePicker;
      switch (item.titleKey) {
        case 'profile':          return _profile;
        case 'trip_history':     return _viewAll;
        case 'payment_methods':  return _payments;
        case 'buspoints':        return _redeem;
        case 'notifications':    return () { _closeDrawer(); _notifs(); };
        case 'help_center':      return _help;
        case 'about':            return _about;
        case 'terms_conditions': return _terms;
        default:                 return null;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: drawerBg,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 24,
              offset: const Offset(-4, 0)),
        ],
        borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(bottom: BorderSide(color: dividerCol)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        border: Border.all(color: _kTeal, width: 2),
                        shape: BoxShape.circle),
                    child: ClipOval(
                      child: SizedBox(
                          width: 56, height: 56,
                          child: _buildProfileImage()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _userName ?? widget.username,
                    style: TextStyle(
                        color: _isDarkMode ? Colors.white : _kTeal,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  if (_nickName != null && _nickName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('@$_nickName',
                        style: TextStyle(
                            color: _isDarkMode
                                ? Colors.white70
                                : Colors.grey.shade600,
                            fontSize: 13,
                            fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    _userEmail ?? 'user@example.com',
                    style: TextStyle(
                        color: _isDarkMode
                            ? Colors.white60
                            : Colors.grey.shade500,
                        fontSize: 13),
                  ),
                ]),
              ),
              GestureDetector(
                onTap: _closeDrawer,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _isDarkMode
                        ? const Color(0xFF1E2E38)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: _kTeal, size: 20),
                ),
              ),
            ]),
          ),

          // Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (items[i].isDarkToggle || items[i].isLogout)
                    Divider(
                        indent: 16,
                        endIndent: 16,
                        color: dividerCol,
                        height: 18),
                  _buildDrawerItem(
                    data: items[i],
                    index: i,
                    onTap: items[i].isLogout
                        ? _logout
                        : getAction(items[i]),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDrawerItem({
    required _DrawerItemData data,
    required int index,
    VoidCallback? onTap,
  }) {
    final textColor = data.isLogout
        ? const Color(0xFFE74C3C)
        : _isDarkMode
        ? const Color(0xFFD0E8F0)
        : Colors.black87;
    final subColor = _isDarkMode
        ? const Color(0xFF4A6A7A)
        : Colors.grey.shade400;

    return StatefulBuilder(
      builder: (_, set) {
        final hovered = _drawerHover == index;
        return MouseRegion(
          onEnter: (_) => set(() => _drawerHover = index),
          onExit:  (_) => set(() => _drawerHover = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: hovered
                  ? (_isDarkMode
                        ? Colors.white.withAlpha(12)
                        : _kTeal.withAlpha(12))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  child: Row(children: [
                    // Icon badge
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: data.iconColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(data.icon,
                          color: data.iconColor, size: 19),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(translate(data.titleKey, _language),
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 14.5,
                                  fontWeight: data.isLogout || hovered
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                          if (data.isLanguage)
                            Text(_languageName(),
                                style: TextStyle(
                                    color: subColor, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    // Right widget
                    if (data.isDarkToggle)
                      Switch(
                        value: _isDarkMode,
                        onChanged: (v) {
                          setState(() => _isDarkMode = v);
                          _saveThemePreference(v);
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: _kTeal,
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: _isDarkMode
                            ? const Color(0xFF2E3D45)
                            : Colors.grey.shade300,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      )
                    else if (data.titleKey == 'notifications' &&
                        _unreadCount > 0)
                      // Show badge in drawer too
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          _unreadCount > 99
                              ? '99+'
                              : '$_unreadCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Icon(Icons.chevron_right_rounded,
                          size: 20,
                          color: data.isLogout
                              ? const Color(0xFFE74C3C)
                                  .withAlpha(160)
                              : subColor),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BACKGROUND GRADIENT
// ─────────────────────────────────────────────────────────────────────────────
class _BackgroundGradient extends StatelessWidget {
  final bool isDark;
  const _BackgroundGradient({this.isDark = false});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: isDark
            ? [const Color(0xFF0D1C22), const Color(0xFF071318)]
            : [const Color(0xFF02515F), const Color(0xFF073F4B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _FieldLabel(this.text, {this.isDark = false});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFFB0CCD8) : Colors.black87,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY TILE
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryTile extends StatelessWidget {
  final String from, to, date, time, status;
  final int    price;
  final String paymentMethod;
  final String id;
  final void Function(String) onDelete;
  final bool isDark;
  final String languageCode;

  const _HistoryTile({
    required this.from,          required this.to,
    required this.date,          required this.time,
    required this.price,         required this.paymentMethod,
    required this.status,
    required this.id,
    required this.onDelete,
    required this.languageCode,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg   = isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50;
    final borderCol= isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    final textCol  = isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol   = isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;

    return Container(
      padding: const EdgeInsets.all(14),
      margin:  const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: _kTeal.withAlpha(22),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.directions_bus,
              color: _kTeal, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('$from → $to',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textCol)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.calendar_today, size: 11, color: subCol),
              const SizedBox(width: 4),
              Text(date,
                  style: TextStyle(fontSize: 11, color: subCol)),
              const SizedBox(width: 10),
              Icon(Icons.access_time, size: 11, color: subCol),
              const SizedBox(width: 4),
              Text(time,
                  style: TextStyle(fontSize: 11, color: subCol)),
            ]),
            const SizedBox(height: 6),
            Text('${translate('paid_via', languageCode)} $paymentMethod',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: isDark ? FontWeight.w700 : FontWeight.w600,
                    color: subCol)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.toLowerCase().contains('scanned')
                    ? Colors.green.withAlpha(24)
                    : Colors.orange.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                  status == 'Not yet Scanned'
                      ? translate('not_yet_scanned', languageCode)
                      : status,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: status.toLowerCase().contains('scanned')
                          ? Colors.green.shade700
                          : isDark ? Colors.orange.shade200 : Colors.orange.shade800)),
            ),
          ]),
        ),
        Text('RWF $price',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : _kTeal,
                fontSize: 14)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => onDelete(id),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.red.withAlpha(22),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.close,
                color: Colors.red, size: 16),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REDEEM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _RedeemSheet extends StatelessWidget {
  final bool       isDark;
  final String     languageCode;
  final int        buspoints;
  final VoidCallback onConfirm;
  static const int _redeemCost = 50;

  const _RedeemSheet({
    required this.isDark,
    required this.languageCode,
    required this.buspoints,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bg      = isDark ? const Color(0xFF1A2830) : Colors.white;
    final cardBg  = isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50;
    final borderC = isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    final textCol = isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol  = isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 6),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF3A5060)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 10),
        Text(translate('please_confirm', languageCode),
            style: TextStyle(
                fontSize: 13,
                color: subCol,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3)),
        const SizedBox(height: 10),
        Text(translate('are_you_sure', languageCode),
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textCol)),
        const SizedBox(height: 8),
        Text(
          translate('redeem_prompt', languageCode)
              .replaceAll('{cost}', '$_redeemCost'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: subCol, height: 1.55),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderC),
          ),
          child: Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(22),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.coffee_rounded,
                  color: Colors.orange, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(translate('redeem_reward_title', languageCode),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textCol)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(22),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(translate('redeem_cost', languageCode)
                      .replaceAll('{cost}', '$_redeemCost'),
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ]),
            ),
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF253238)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline_rounded,
                  size: 19, color: _kTeal),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(translate('available_buspoints', languageCode)
            .replaceAll('{count}', '$buspoints'),
            style: TextStyle(
                fontSize: 12,
                color: subCol,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(translate('yes_sure', languageCode),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(translate('cancel', languageCode),
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.orange.shade600,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATION SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _StationSheet extends StatefulWidget {
  final String title;
  final TextEditingController searchCtrl;
  final List<String> Function() getList;
  final VoidCallback onFilter;
  final void Function(String) onSelect;
  final List<Map<String, String>> stations;
  final String languageCode;
  final bool isDark;

  const _StationSheet({
    required this.title,     required this.searchCtrl,
    required this.getList,   required this.onFilter,
    required this.onSelect,  required this.stations,
    required this.languageCode,
    this.isDark = false,
  });

  @override
  State<_StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<_StationSheet> {
  @override
  void initState() {
    super.initState();
    widget.searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    widget.onFilter();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list    = widget.getList();
    final bg      = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final cardBg  = widget.isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50;
    final borderC = widget.isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol  = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final inputBg = widget.isDark ? const Color(0xFF1E2E38) : Colors.grey.shade100;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 2),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF3A5060)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(widget.title,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? _kTealLight : _kTeal)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: cardBg, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    color: _kTeal, size: 18),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderC),
            ),
            child: TextField(
              controller: widget.searchCtrl,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: textCol),
              decoration: InputDecoration(
                hintText: 'Search station...',
                hintStyle:
                    TextStyle(color: subCol, fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: _kTeal, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Icon(Icons.search_off, size: 44, color: subCol),
                    const SizedBox(height: 10),
                    Text(translate('no_stations_found', widget.languageCode),
                        style: TextStyle(color: subCol)),
                  ]))
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final name   = list[i];
                    final detail = widget.stations.firstWhere(
                        (s) => s['name'] == name,
                        orElse: () =>
                            {'name': name, 'detail': 'Bus Terminal'});
                    return GestureDetector(
                      onTap: () {
                        widget.onSelect(name);
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderC),
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                                color: _kTeal.withAlpha(20),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.location_on,
                                color: _kTeal, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                              Text(name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textCol)),
                              const SizedBox(height: 1),
                              Text(detail['detail']!,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: subCol)),
                            ]),
                          ),
                          Icon(Icons.chevron_right,
                              color: subCol, size: 18),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PASSENGER SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _PassengerSheet extends StatefulWidget {
  final int  current;
  final bool isDark;
  final String languageCode;
  final void Function(int) onSelect;
  const _PassengerSheet(
      {required this.current, required this.onSelect, required this.languageCode, this.isDark = false});

  @override
  State<_PassengerSheet> createState() => _PassengerSheetState();
}

class _PassengerSheetState extends State<_PassengerSheet> {
  late int _sel;
  String _searchTerm = '';

  List<int> get _filteredValues => List<int>.generate(29, (i) => i + 1)
      .where((value) => _searchTerm.isEmpty || '$value'.contains(_searchTerm))
      .toList();

  @override
  void initState() {
    super.initState();
    _sel = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final bg      = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final cardBg  = widget.isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50;
    final borderC = widget.isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 2),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF3A5060)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(translate('select_passengers', widget.languageCode),
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? _kTealLight : _kTeal)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: cardBg, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    color: _kTeal, size: 18),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: translate('search_passengers', widget.languageCode),
              hintStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey),
              filled: true,
              fillColor: widget.isDark ? const Color(0xFF16222C) : Colors.grey.shade100,
              prefixIcon: Icon(Icons.search, color: widget.isDark ? _kTealLight : _kTeal),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _searchTerm = value.trim()),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _filteredValues.length,
            itemBuilder: (_, i) {
              final val = _filteredValues[i];
              final sel = _sel == val;
              return GestureDetector(
                onTap: () {
                  widget.onSelect(val);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 13),
                  decoration: BoxDecoration(
                    color: sel ? _kTeal : cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: sel ? _kTeal : borderC),
                  ),
                  child: Row(children: [
                    Icon(Icons.person,
                        color: sel ? Colors.white : _kTeal,
                        size: 18),
                    const SizedBox(width: 12),
                    Text(
                        '$val Passenger${val > 1 ? 's' : ''}',
                        style: TextStyle(
                            color: sel ? Colors.white : textCol,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14)),
                    const Spacer(),
                    if (sel)
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 18),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE PICKER SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _DatePickerSheet extends StatefulWidget {
  final DateTime?           initial;
  final bool                isDark;
  final String              languageCode;
  final void Function(DateTime) onSave;
  const _DatePickerSheet(
      {required this.initial, required this.onSave, required this.languageCode, this.isDark = false});

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime      _sel;
  late int           _month, _year;
  late final DateTime      _now;
  late final Set<DateTime> _available;

  @override
  void initState() {
    super.initState();
    _now   = DateTime.now();
    _sel   = widget.initial ?? _now;
    _month = _sel.month;
    _year  = _sel.year;
    _available = {};
    for (int i = 0; i < 30; i++) {
      _available.add(_now.add(Duration(days: i)));
    }
  }

  bool _isAvailable(DateTime d) =>
      _available.any((a) =>
          a.year == d.year && a.month == d.month && a.day == d.day);
  bool _isToday(DateTime d) =>
      d.year == _now.year && d.month == _now.month && d.day == _now.day;
  bool _isPast(DateTime d) => d.isBefore(_now) && !_isToday(d);
  bool _isSel(DateTime d) =>
      d.year == _sel.year && d.month == _sel.month && d.day == _sel.day;

  @override
  Widget build(BuildContext context) {
    final bg     = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol= widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final pastBg = widget.isDark ? const Color(0xFF162028) : Colors.grey.shade100;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 2),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF3A5060)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(translate('select_departure_date', widget.languageCode),
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? _kTealLight : _kTeal)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF1E2E38)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    color: _kTeal, size: 18),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: textCol),
              onPressed: () => setState(() {
                if (_month == 1) { _month = 12; _year--; }
                else { _month--; }
              }),
            ),
            Text(
              '${DateFormat.MMMM().format(DateTime(_year, _month))} $_year',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textCol),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: textCol),
              onPressed: () => setState(() {
                if (_month == 12) { _month = 1; _year++; }
                else { _month++; }
              }),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((d) => _WDLabel(d, isDark: widget.isDark))
                  .toList()),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7, childAspectRatio: 1.1),
              itemCount: 42,
              itemBuilder: (_, index) {
                final first   = DateTime(_year, _month, 1);
                final dayNum  = index - first.weekday + 2;
                final lastDay = DateTime(_year, _month + 1, 0).day;
                if (dayNum < 1 || dayNum > lastDay) {
                  return const SizedBox();
                }
                final cell  = DateTime(_year, _month, dayNum);
                final avail = _isAvailable(cell);
                final today = _isToday(cell);
                final past  = _isPast(cell);
                final selC  = _isSel(cell);
                final cellColor = selC
                    ? _kTeal
                    : past
                    ? pastBg
                    : Colors.transparent;
                final dayColor = selC
                    ? Colors.white
                    : past
                    ? subCol
                    : avail
                    ? textCol
                    : subCol;
                return GestureDetector(
                  onTap: (avail && !past)
                      ? () => setState(() => _sel = cell)
                      : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(8),
                      border: today && !selC
                          ? Border.all(color: _kTeal, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text('$dayNum',
                          style: TextStyle(
                              color: dayColor,
                              fontWeight: selC || today
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 8),
          child: Row(children: [
            _legend(pastBg, translate('unavailable', widget.languageCode), subCol),
            const SizedBox(width: 16),
            _legend(_kTeal.withAlpha(28), translate('today', widget.languageCode), subCol,
                border: _kTeal),
            const SizedBox(width: 16),
            _legend(_kTeal, translate('selected', widget.languageCode), subCol),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: ElevatedButton(
            onPressed: () {
              widget.onSave(_sel);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(translate('save_date', widget.languageCode),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _legend(Color color, String label, Color textColor,
      {Color? border}) =>
      Row(children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border != null
                ? Border.all(color: border, width: 1.5)
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: textColor)),
      ]);
}

class _WDLabel extends StatelessWidget {
  final String text;
  final bool   isDark;
  const _WDLabel(this.text, {this.isDark = false});

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark
              ? const Color(0xFF4A6A7A)
              : Colors.grey.shade500,
          fontSize: 12));
}

// ─────────────────────────────────────────────────────────────────────────────
// LANGUAGE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageSheet extends StatefulWidget {
  final String current;
  final bool   isDark;
  final void Function(String) onSelect;
  const _LanguageSheet(
      {required this.current, required this.isDark, required this.onSelect});

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  late String _sel;

  @override
  void initState() {
    super.initState();
    _sel = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final bg      = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final cardBg  = widget.isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50;
    final borderC = widget.isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol  = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;

    return Container(
      height: MediaQuery.of(context).size.height * 0.68,
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 2),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF3A5060)
                  : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color:
                        const Color(0xFF1ABC9C).withAlpha(28),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.language,
                    color: Color(0xFF1ABC9C), size: 20),
              ),
              const SizedBox(width: 12),
              Text(translate('language_title', widget.current),
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: textCol)),
            ]),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: cardBg, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    color: _kTeal, size: 18),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
              translate('language_subtitle', widget.current),
              style: TextStyle(fontSize: 13, color: subCol)),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _kLanguages.length,
            itemBuilder: (_, i) {
              final lang  = _kLanguages[i];
              final code  = lang['code']!;
              final name  = lang['name']!;
              final flag  = lang['flag']!;
              final isSel = _sel == code;
              return GestureDetector(
                onTap: () {
                  widget.onSelect(code);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: isSel ? _kTeal : cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSel ? _kTeal : borderC,
                        width: isSel ? 2 : 1),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                                color: _kTeal.withAlpha(50),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ]
                        : [],
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: isSel
                              ? Colors.white.withAlpha(30)
                              : Colors.white,
                          borderRadius:
                              BorderRadius.circular(10),
                          border:
                              Border.all(color: borderC)),
                      child: Center(
                          child: Text(flag,
                              style: const TextStyle(
                                  fontSize: 20))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : textCol,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 15)),
                    ),
                    isSel
                        ? const Icon(Icons.check_circle,
                            color: Colors.white, size: 20)
                        : Icon(Icons.chevron_right_rounded,
                            color: subCol, size: 20),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PLACEHOLDER SCREENS
// ═════════════════════════════════════════════════════════════════════════════
class _PlaceholderScreen extends StatelessWidget {
  final String  title;
  final String  subtitle;
  final IconData icon;
  final Color   accent;
  final bool    isDark;
  const _PlaceholderScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = _kTeal,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol= isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          margin:  const EdgeInsets.all(32),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 40 : 16),
                  blurRadius: 20,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: accent.withAlpha(20),
                  shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 36),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textCol)),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: subCol, height: 1.6),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Activity / History ────────────────────────────────────────────────────────
class ActivityScreen extends StatefulWidget {
  final bool isDark;
  final String languageCode;
  final List<Map<String, dynamic>> history;
  final void Function(String) onDelete;
  const ActivityScreen({
    super.key,
    required this.isDark,
    required this.languageCode,
    required this.history,
    required this.onDelete,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  Widget build(BuildContext context) {
    final bg     = widget.isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final subCol = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor:
            widget.isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(translate('trip_activity', widget.languageCode),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: widget.history.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_rounded,
                  size: 64,
                  color: widget.isDark
                      ? const Color(0xFF3A5060)
                      : Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(translate('no_trips', widget.languageCode),
                  style: TextStyle(fontSize: 16, color: subCol)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.history.length,
              itemBuilder: (_, i) {
                final e = widget.history[i];
                return _HistoryTile(
                  from: e['from']!, to: e['to']!,
                  date: e['date']!, time: e['time']!,
                  price: e['price'] as int,
                  paymentMethod: e['paymentMethod'] as String? ?? 'Unknown',
                  status: e['status'] as String? ?? 'Not yet Scanned',
                  languageCode: widget.languageCode,
                  id: e['id'] as String,
                  onDelete: (id) {
                    widget.onDelete(id);
                    setState(() {});
                  },
                  isDark: widget.isDark,
                );
              },
            ),
    );
  }
}

// ── Live Map ──────────────────────────────────────────────────────────────────
class LiveMapScreen extends StatelessWidget {
  final bool isDark;
  final String languageCode;
  const LiveMapScreen({super.key, this.isDark = false, required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final mapBg  = isDark ? const Color(0xFF1A2830) : const Color(0xFFE8F0E9);
    final cardBg = isDark ? const Color(0xFF1A2830) : Colors.white;
    final subCol = isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: ColoredBox(color: mapBg)),
        Positioned(
          top: 0, left: 0, right: 0,
          child: AppBar(
            backgroundColor:
                isDark ? const Color(0xFF111C22) : _kTeal,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(translate('live_map', languageCode),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_pin,
                size: 72, color: Colors.red.withAlpha(200)),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Text(translate('plug_in_google_maps_here', languageCode),
                  style: TextStyle(fontSize: 13, color: subCol)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── QR Scan ───────────────────────────────────────────────────────────────────
class QRScanScreen extends StatefulWidget {
  final bool isDark;
  final String languageCode;
  const QRScanScreen({super.key, this.isDark = false, required this.languageCode});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool _loading = true;
  String? _error;
  List<Booking> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _error = 'You must be signed in to view tickets.';
        _loading = false;
      });
      return;
    }
    try {
      final bookings = await FirestoreService.getBookingsForUser(uid);
      if (!mounted) return;
      setState(() {
        _tickets = bookings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _shareBooking(Booking booking) async {
    final languageCode = widget.languageCode;
    final shareText = '''${translate('moveKigali_ticket', languageCode)}
${translate('transaction', languageCode)}: ${booking.transactionId}
${booking.from} → ${booking.to}
${translate('date', languageCode)}: ${booking.date}
${translate('departure', languageCode)}: ${booking.time}
${translate('passengers', languageCode)}: ${booking.passengers}
${translate('amount_paid', languageCode)}: RWF ${_fmtPrice(booking.price)}
${translate('payment', languageCode)}: ${booking.paymentMethod}
''';
    await _shareText(shareText);
  }

  void _showTicketDetails(Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bg = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
        final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
        final subCol = widget.isDark ? const Color(0xFF7DA6B4) : Colors.grey.shade600;
        final languageCode = widget.languageCode;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text(translate('ticket_details', languageCode), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(height: 8),
            Text(translate('ticket_details_hint', languageCode), style: TextStyle(color: subCol, fontSize: 13, height: 1.4)),
            const SizedBox(height: 18),
            _InfoBlock(label: translate('transaction', languageCode), value: booking.transactionId),
            const SizedBox(height: 8),
            _InfoBlock(label: translate('route', languageCode), value: '${booking.from} → ${booking.to}'),
            const SizedBox(height: 8),
            _InfoBlock(label: translate('date', languageCode), value: booking.date),
            const SizedBox(height: 8),
            _InfoBlock(label: translate('departure', languageCode), value: booking.time),
            const SizedBox(height: 8),
            _InfoBlock(label: translate('passengers', languageCode), value: '${booking.passengers}'),
            const SizedBox(height: 8),
            _InfoBlock(label: translate('payment', languageCode), value: booking.paymentMethod),
            const SizedBox(height: 8),
            _InfoBlock(label: translate('amount_paid', languageCode), value: 'RWF ${_fmtPrice(booking.price)}'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _shareBooking(booking),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(translate('share_ticket', languageCode), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _kTeal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = widget.isDark ? const Color(0xFF7DA6B4) : Colors.grey.shade600;
    final languageCode = widget.languageCode;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: widget.isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(translate('qr_scanner', widget.languageCode), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: textCol, fontSize: 14), textAlign: TextAlign.center))
                : _tickets.isEmpty
                    ? Center(child: Text(translate('no_completed_tickets', languageCode), style: TextStyle(color: subCol, fontSize: 14), textAlign: TextAlign.center))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(translate('completed_tickets', languageCode), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol)),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _tickets.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final booking = _tickets[index];
                              return Material(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showTicketDetails(booking),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.isDark ? const Color(0xFF23343F) : Colors.grey.shade200)),
                                    child: Row(children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(color: _kTeal.withAlpha(20), borderRadius: BorderRadius.circular(14)),
                                        child: const Icon(Icons.qr_code, color: _kTeal, size: 26),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('TX ${booking.transactionId}', style: TextStyle(fontWeight: FontWeight.bold, color: textCol)),
                                        const SizedBox(height: 4),
                                        Text('${booking.from} → ${booking.to}', style: TextStyle(color: subCol, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text('${booking.date} • ${booking.time}', style: TextStyle(color: subCol.withAlpha(200), fontSize: 12)),
                                      ])),
                                      IconButton(onPressed: () => _shareBooking(booking), icon: Icon(Icons.share_rounded, color: _kTeal)),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ]),
      ),
    );
  }
}

// ── Payment Methods ───────────────────────────────────────────────────────────
class PaymentMethodsScreen extends StatelessWidget {
  final bool isDark;
  final String languageCode;
  const PaymentMethodsScreen({super.key, this.isDark = false, required this.languageCode});

  static const List<Map<String, String>> _methods = [
    {'id':'mtn_momo',   'labelKey':'mtn_mobile_money','subKey':'pay_via_mtn_mobile_money'},
    {'id':'airtel_momo','labelKey':'airtel_money','subKey':'pay_via_airtel_money'},
    {'id':'card',       'labelKey':'debit_credit_card','subKey':'pay_with_card'},
    {'id':'digital_banking','labelKey':'digital_banking','subKey':'pay_via_digital_banking'},
  ];

  Color _tileColor(String id) {
    switch (id) {
      case 'mtn_momo': return const Color(0xFFFFCC00);
      case 'airtel_momo': return const Color(0xFFE60000);
      case 'card': return const Color(0xFF205081);
      case 'digital_banking': return const Color(0xFF003087);
      default: return _kTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = isDark ? const Color(0xFF7DA6B4) : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(translate('payment_methods', languageCode), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(translate('payment_methods', languageCode), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol)),
          const SizedBox(height: 8),
          Text(translate('payment_methods_description', languageCode), style: TextStyle(color: subCol, fontSize: 13, height: 1.5)),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: _methods.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final method = _methods[index];
                final label = translate(method['labelKey']!, languageCode);
                final subtitle = translate(method['subKey']!, languageCode);
                return GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(translate('available_at_checkout', languageCode).replaceAll('{method}', label)),
                      backgroundColor: _tileColor(method['id']!),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? const Color(0xFF223038) : Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: _tileColor(method['id']!).withAlpha(24), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.payment_rounded, color: _tileColor(method['id']!), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCol)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(color: subCol, fontSize: 13)),
                      ])),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Help Center ───────────────────────────────────────────────────────────────
class HelpCenterScreen extends StatelessWidget {
  final bool isDark;
  final String languageCode;
  const HelpCenterScreen({super.key, this.isDark = false, required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = isDark ? Colors.white : Colors.black87;
    final subCol = isDark ? const Color(0xFFB0D6E3) : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(translate('help_center', languageCode),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 40 : 16),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3498DB).withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.help_outline_rounded,
                      color: Color(0xFF3498DB), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Need help? Try one of these features.',
                    style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Text(
                'Recommended support features',
                style: TextStyle(
                  color: textCol,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _helpFeature(
                title: 'FAQ search',
                subtitle: 'Find quick answers for booking, tickets, and payments.',
                icon: Icons.search_rounded,
                isDark: isDark,
              ),
              _helpFeature(
                title: 'Live chat',
                subtitle: 'Chat instantly with support for urgent issues.',
                icon: Icons.chat_bubble_outline_rounded,
                isDark: isDark,
              ),
              _helpFeature(
                title: 'Report an issue',
                subtitle: 'Send a ticket with a screenshot or log details.',
                icon: Icons.report_problem_rounded,
                isDark: isDark,
              ),
              _helpFeature(
                title: 'Track requests',
                subtitle: 'View the status of your support requests.',
                icon: Icons.track_changes_rounded,
                isDark: isDark,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

Widget _helpFeature({
  required String title,
  required String subtitle,
  required IconData icon,
  required bool isDark,
}) {
  final cardBg = isDark ? const Color(0xFF162A34) : Colors.grey.shade50;
  final textCol = isDark ? Colors.white : Colors.black87;
  final subCol = isDark ? const Color(0xFFB0D6E3) : Colors.black54;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: isDark ? const Color(0xFF2A3D4F) : Colors.grey.shade200),
    ),
    child: Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3498DB).withOpacity(0.18) : const Color(0xFF3498DB).withOpacity(0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF3498DB), size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: textCol,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: subCol, fontSize: 13, height: 1.4)),
        ]),
      ),
    ]),
  );
}

// ── About ─────────────────────────────────────────────────────────────────────
class AboutScreen extends StatelessWidget {
  final bool isDark;
  final String languageCode;
  const AboutScreen({super.key, this.isDark = false, required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = isDark ? Colors.white : Colors.black87;
    final subCol = isDark ? const Color(0xFF9ABCCF) : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(translate('about_movekigali', languageCode),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 40 : 16),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B59B6).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF9B59B6), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    translate('moveKigali_description', languageCode),
                    style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Text(translate('what_we_do', languageCode),
                  style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                translate('moveKigali_connects', languageCode),
                style: TextStyle(color: subCol, height: 1.6, fontSize: 14),
              ),
              const SizedBox(height: 18),
              Text(translate('why_choose_movekigali', languageCode),
                  style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildBullet(translate('why_choose_movekigali_point_1', languageCode), subCol),
              _buildBullet(translate('why_choose_movekigali_point_2', languageCode), subCol),
              _buildBullet(translate('why_choose_movekigali_point_3', languageCode), subCol),
              const SizedBox(height: 18),
              Text(translate('our_commitment', languageCode),
                  style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                translate('our_commitment_description', languageCode),
                style: TextStyle(color: subCol, height: 1.6, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Terms & Conditions ────────────────────────────────────────────────────────
class TermsScreen extends StatelessWidget {
  final bool isDark;
  final String languageCode;
  const TermsScreen({super.key, this.isDark = false, required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = isDark ? Colors.white : Colors.black87;
    final subCol = isDark ? const Color(0xFF9ABCCF) : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(translate('terms_conditions', languageCode),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 40 : 16),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: Color(0xFF2ECC71), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    translate('terms_intro', languageCode),
                    style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Text(translate('service_scope', languageCode),
                  style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                translate('service_scope_text', languageCode),
                style: TextStyle(color: subCol, height: 1.6, fontSize: 14),
              ),
              const SizedBox(height: 18),
              Text(translate('booking_rules', languageCode),
                  style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildBullet(translate('booking_rule_1', languageCode), subCol),
              _buildBullet(translate('booking_rule_2', languageCode), subCol),
              _buildBullet(translate('booking_rule_3', languageCode), subCol),
              const SizedBox(height: 18),
              Text(translate('traveler_responsibilities', languageCode),
                  style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildBullet(translate('traveler_responsibility_1', languageCode), subCol),
              _buildBullet(translate('traveler_responsibility_2', languageCode), subCol),
              const SizedBox(height: 18),
              Text(translate('disclaimer', languageCode),
                  style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                translate('disclaimer_text', languageCode),
                style: TextStyle(color: subCol, height: 1.6, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildBullet(String text, Color color) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('• ', style: TextStyle(fontSize: 16, height: 1.6, color: color)),
      Expanded(
        child: Text(text,
            style: TextStyle(fontSize: 14, height: 1.6, color: color),
            softWrap: true),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULE RESULT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

/// A single bus schedule slot generated for the search result list.
class ScheduleSlot {
  final String busNumber;
  final String routeType;
  final String depTime;
  final String arrTime;
  final String duration;
  final int    seatsAvailable;
  final int    priceRfw;

  const ScheduleSlot({
    required this.busNumber,
    required this.routeType,
    required this.depTime,
    required this.arrTime,
    required this.duration,
    required this.seatsAvailable,
    required this.priceRfw,
  });
}

class ScheduleResultScreen extends StatefulWidget {
  final String   from;
  final String   to;
  final DateTime date;
  final int      passengers;
  final bool     isDark;
  final int      buspoints; // current user buspoints for eligibility check
  final String   languageCode;
  final void Function(Map<String, dynamic>) onBookingConfirmed;
  final void Function(String from, String to, DateTime date, int passengers)
      onChangeRequested;

  const ScheduleResultScreen({
    super.key,
    required this.from,
    required this.to,
    required this.date,
    required this.passengers,
    required this.isDark,
    required this.buspoints,
    required this.languageCode,
    required this.onBookingConfirmed,
    required this.onChangeRequested,
  });

  @override
  State<ScheduleResultScreen> createState() => _ScheduleResultScreenState();
}

class _ScheduleResultScreenState extends State<ScheduleResultScreen> {
  late List<ScheduleSlot> _slots;
  int? _selectedIdx;

  @override
  void initState() {
    super.initState();
    _slots = _generateSlots(widget.from, widget.to);
  }

  // ── Generate deterministic but varied slots ──────────────────────────────
  List<ScheduleSlot> _generateSlots(String from, String to) {
    final seed   = (from.hashCode ^ to.hashCode).abs();
    final count  = 3 + (seed % 5); // 3–7 slots
    final types  = ['Via Toll Direct', 'Via Highway', 'Local Route', 'Express'];
    final prices = [350, 450, 500, 620, 700, 800];

    return List.generate(count, (i) {
      final h   = (seed + i * 137) % 24;
      final min = ((seed + i * 53) % 60);
      final dur = 30 + ((seed + i * 17) % 150); // 30–180 min
      final arr = DateTime(2000, 1, 1, h, min)
          .add(Duration(minutes: dur));
      return ScheduleSlot(
        busNumber:      'RAB ${100 + ((seed + i * 31) % 900)} ${String.fromCharCode(65 + (i % 26))}',
        routeType:      types[(seed + i) % types.length],
        depTime:        '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}',
        arrTime:        '${arr.hour.toString().padLeft(2, '0')}:${arr.minute.toString().padLeft(2, '0')}',
        duration:       dur >= 60
            ? '${dur ~/ 60}h ${dur % 60}m'
            : '${dur}m',
        seatsAvailable: 5 + ((seed + i * 7) % 46),
        priceRfw:       prices[(seed + i) % prices.length] * widget.passengers,
      );
    });
  }

  // ── Confirm booking — navigate to full ticket flow ───────────────────────
  void _confirmBooking(ScheduleSlot slot) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => TicketDetailScreen(
          slot:         slot,
          from:         widget.from,
          to:           widget.to,
          date:         widget.date,
          passengers:   widget.passengers,
          isDark:       widget.isDark,
          buspoints:    widget.buspoints,
          languageCode: widget.languageCode,
          onBookingConfirmed: widget.onBookingConfirmed,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  // ── Change selections ────────────────────────────────────────────────────
  void _requestChange() async {
    // Show a bottom-sheet editor to change the trip details
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeSelectionSheet(
        from:         widget.from,
        to:           widget.to,
        date:         widget.date,
        passengers:   widget.passengers,
        isDark:       widget.isDark,
        languageCode: widget.languageCode,
        stations:     _HomeScreenState._stations,
      ),
    );

    if (result == null || !mounted) return;

    final newFrom       = result['from'] as String;
    final newTo         = result['to']   as String;
    final newDate       = result['date'] as DateTime;
    final newPassengers = result['passengers'] as int;

    // Notify home screen to update its fields
    widget.onChangeRequested(newFrom, newTo, newDate, newPassengers);

    // Replace this screen with a fresh result
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ScheduleResultScreen(
          from:       newFrom,
          to:         newTo,
          date:       newDate,
          passengers: newPassengers,
          isDark:     widget.isDark,
          buspoints:  widget.buspoints,
          languageCode: widget.languageCode,
          onBookingConfirmed: widget.onBookingConfirmed,
          onChangeRequested:  widget.onChangeRequested,
        ),
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
    final bg     = widget.isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol= widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final languageCode = widget.languageCode;

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        // ── Teal header ────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [_kTeal, _kTealLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(children: [
                // Back + Change row
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _requestChange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withAlpha(80), width: 1),
                      ),
                      child: Row(children: [
                        const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(translate('change', widget.languageCode),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ]),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // Route display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        widget.from,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        widget.to,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                Text(
                  DateFormat('dd/MM/yyyy').format(widget.date),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ),

        // ── Schedule count badge ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(children: [
            Text(translate('schedule_available', languageCode),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textCol)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: _kTeal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_slots.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ]),
        ),

        // ── Slot list ──────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            itemCount: _slots.length,
            itemBuilder: (_, i) => _ScheduleCard(
              slot:       _slots[i],
              isSelected: _selectedIdx == i,
              isDark:     widget.isDark,
              cardBg:     cardBg,
              textCol:    textCol,
              subCol:     subCol,
              passengers: widget.passengers,
              languageCode: widget.languageCode,
              onTap: () => setState(() =>
                  _selectedIdx = _selectedIdx == i ? null : i),
              onBook: () => _confirmBooking(_slots[i]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final ScheduleSlot slot;
  final bool       isSelected;
  final bool       isDark;
  final Color      cardBg;
  final Color      textCol;
  final Color      subCol;
  final int        passengers;
  final String     languageCode;
  final VoidCallback onTap;
  final VoidCallback onBook;

  const _ScheduleCard({
    required this.slot,        required this.isSelected,
    required this.isDark,      required this.cardBg,
    required this.textCol,     required this.subCol,
    required this.passengers,  required this.languageCode,
    required this.onTap,       required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final borderC = isDark
        ? const Color(0xFF2A3E4A)
        : Colors.grey.shade200;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _kTeal : borderC,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: isSelected
                    ? _kTeal.withAlpha(40)
                    : Colors.black.withAlpha(isDark ? 30 : 12),
                blurRadius: isSelected ? 16 : 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // ── Bus number + route type ──────────────────────────────────
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kTeal.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_bus_rounded,
                    color: _kTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(translate('bus_number', languageCode),
                      style: TextStyle(
                          fontSize: 10,
                          color: subCol)),
                  Text(slot.busNumber,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textCol)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kTeal.withAlpha(16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Icon(Icons.bolt_rounded,
                      color: _kTeal, size: 14),
                  const SizedBox(width: 3),
                  Text(slot.routeType,
                      style: const TextStyle(
                          color: _kTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ]),
              ),
            ]),

            const SizedBox(height: 14),
            // ── Times ────────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(slot.depTime,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textCol)),
                  Text(translate('departure', languageCode),
                      style: TextStyle(fontSize: 11, color: subCol)),
                ]),
              ),
              Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(slot.duration,
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                      width: 40, height: 1,
                      color: Colors.grey.shade300),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.orange),
                ]),
              ]),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  Text(slot.arrTime,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textCol)),
                  Text(translate('destination', languageCode),
                      style: TextStyle(fontSize: 11, color: subCol)),
                ]),
              ),
            ]),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Seats + price + book ─────────────────────────────────────
            Row(children: [
              const Icon(Icons.event_seat_rounded,
                  color: _kTeal, size: 16),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(translate('seats_available', languageCode),
                    style: TextStyle(fontSize: 10, color: subCol)),
                Text('${slot.seatsAvailable} ${translate('seats', languageCode)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textCol)),
              ]),
              const Spacer(),
              Text(
                'RWF ${slot.priceRfw.toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},',
                    )}',
                style: const TextStyle(
                    color: _kTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ]),

            // ── Expanded book button ─────────────────────────────────────
            if (isSelected) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton.icon(
                  onPressed: onBook,
                  icon: const Icon(Icons.confirmation_num_rounded,
                      size: 18),
                  label: Text(
                    translate('book_tickets', languageCode).replaceAll('{count}', '$passengers'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// CHANGE SELECTION SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ChangeSelectionSheet extends StatefulWidget {
  final String   from;
  final String   to;
  final DateTime date;
  final int      passengers;
  final bool     isDark;
  final String   languageCode;
  final List<Map<String, String>> stations;

  const _ChangeSelectionSheet({
    required this.from,         required this.to,
    required this.date,         required this.passengers,
    required this.isDark,       required this.languageCode,
    required this.stations,
  });

  @override
  State<_ChangeSelectionSheet> createState() =>
      _ChangeSelectionSheetState();
}

class _ChangeSelectionSheetState extends State<_ChangeSelectionSheet> {
  late String   _from;
  late String   _to;
  late DateTime _date;
  late int      _passengers;

  static List<String> get _names =>
      _HomeScreenState._stations.map((s) => s['name']!).toList();

  @override
  void initState() {
    super.initState();
    _from       = widget.from;
    _to         = widget.to;
    _date       = widget.date;
    _passengers = widget.passengers;
  }

  void _pickStation({required bool isDep}) {
    final ctrl   = TextEditingController();
    List<String> list = List.from(_names);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return _StationSheet(
            title:       isDep ? 'Change Departure' : 'Change Destination',
            searchCtrl:  ctrl,
            getList:     () => list,
            onFilter: () {
              final q = ctrl.text.toLowerCase();
              setLocal(() {
                list = q.isEmpty
                    ? List.from(_names)
                    : _names
                        .where((s) => s.toLowerCase().contains(q))
                        .toList();
              });
            },
            onSelect: (s) => setState(() {
              if (isDep) {
                _from = s;
              } else {
                _to = s;
              }
            }),
            stations: widget.stations,
            languageCode: widget.languageCode,
            isDark:   widget.isDark,
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DatePickerSheet(
        initial: _date,
        isDark:  widget.isDark,
        languageCode: widget.languageCode,
        onSave:  (d) => setState(() => _date = d),
      ),
    );
  }

  void _pickPassengers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PassengerSheet(
        current:      _passengers,
        isDark:       widget.isDark,
        languageCode: widget.languageCode,
        onSelect:     (v) => setState(() => _passengers = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg      = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol  = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final inputBg = widget.isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50;
    final borderC = widget.isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;

    Widget editRow(
        IconData icon, String label, String value, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderC),
          ),
          child: Row(children: [
            Icon(icon, color: _kTeal, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: subCol)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textCol)),
              ]),
            ),
            Icon(Icons.edit_rounded, color: subCol, size: 17),
          ]),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF3A5060)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(translate('change_selections', widget.languageCode),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textCol)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: inputBg, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    color: _kTeal, size: 18),
              ),
            ),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              editRow(
                Icons.trip_origin_rounded,
                translate('departure', widget.languageCode),
                _from,
                () => _pickStation(isDep: true),
              ),
              editRow(
                Icons.location_on_rounded,
                translate('destination', widget.languageCode),
                _to,
                () => _pickStation(isDep: false),
              ),
              editRow(
                Icons.calendar_today_rounded,
                translate('date', widget.languageCode),
                DateFormat('EEEE, dd MMM yyyy').format(_date),
                _pickDate,
              ),
              editRow(
                Icons.person_rounded,
                translate('passengers', widget.languageCode),
                '$_passengers ${translate('passengers', widget.languageCode)}',
                _pickPassengers,
              ),
            ]),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (_from == _to) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Departure and destination cannot be the same'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                Navigator.pop(context, {
                  'from':       _from,
                  'to':         _to,
                  'date':       _date,
                  'passengers': _passengers,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(translate('search_again', widget.languageCode),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════════
// TICKET DETAIL SCREEN  (Step 1 of booking flow)
// ═════════════════════════════════════════════════════════════════════════════
class TicketDetailScreen extends StatelessWidget {
  final ScheduleSlot slot;
  final String        from;
  final String        to;
  final DateTime      date;
  final int           passengers;
  final bool          isDark;
  final int           buspoints;
  final String        languageCode;
  final void Function(Map<String, dynamic>) onBookingConfirmed;

  const TicketDetailScreen({
    super.key,
    required this.slot,           required this.from,
    required this.to,             required this.date,
    required this.passengers,     required this.isDark,
    required this.buspoints,      required this.languageCode,
    required this.onBookingConfirmed,
  });

  static Route<void> _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 280),
  );

  String _driverName(int seed) {
    const names = ['Hernandez','Fernandez','Martinez','Garcia','Lopez','Mutabazi','Niyonzima','Habimana'];
    return names[seed.abs() % names.length];
  }

  @override
  Widget build(BuildContext context) {
    final bg      = isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg  = isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol  = isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final borderC = isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    final seed    = slot.busNumber.hashCode.abs();
    final drivers = [
      {'name': 'M. ${_driverName(seed)}',     'role': 'Driver'},
      {'name': 'D. ${_driverName(seed + 7)}', 'role': 'Co-Driver'},
    ];
    final vehicleType = ['Legacy SR3 XHD Prime','Sprinter Elite','City Express','Comfort Pro'][seed % 4];

    Widget infoRow(String label, String val) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: subCol, fontSize: 13)),
        Text(val, style: TextStyle(color: textCol, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white, elevation: 0,
        title: Text(translate('detail', languageCode), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.share_rounded, size: 20), onPressed: () {
          final shareText = '${translate('safe_travel', languageCode)}\n$from → $to\n${DateFormat('dd/MM/yyyy').format(date)} • ${slot.depTime}\n${translate('book_ticket', languageCode)} with moveKigali.';
          _shareText(shareText);
        })],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderC)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(DateFormat('dd/MM/yyyy').format(date), style: TextStyle(color: subCol, fontSize: 12)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _kTeal.withAlpha(16), borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        const Icon(Icons.bolt_rounded, color: _kTeal, size: 13),
                        const SizedBox(width: 3),
                        Text(slot.routeType, style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(translate('vehicle_type', languageCode), style: TextStyle(color: subCol, fontSize: 11)),
                  Text(vehicleType, style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(translate('bus_number', languageCode), style: TextStyle(color: subCol, fontSize: 11)),
                      Text(slot.busNumber, style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                    Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _kTeal.withAlpha(18), shape: BoxShape.circle),
                      child: const Icon(Icons.directions_bus_rounded, color: _kTeal, size: 20)),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(slot.depTime, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textCol)),
                      Text(from, style: TextStyle(color: textCol, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                    ])),
                    Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.withAlpha(22), borderRadius: BorderRadius.circular(12)),
                        child: Text(slot.duration, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 11)),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(width: 30, height: 1, color: Colors.grey.shade300),
                        const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.orange),
                      ]),
                    ]),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(slot.arrTime, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textCol)),
                      Text(to, style: TextStyle(color: textCol, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                    ])),
                  ]),
                  const Divider(height: 22),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.withAlpha(18), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withAlpha(50))),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(translate('estimated_travel_duration', languageCode),
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.orange.shade200 : Colors.orange.shade700, height: 1.5))),
                    ]),
                  ),
                  const Divider(height: 22),
                  infoRow(translate('seats_available', languageCode), '${slot.seatsAvailable} ${translate('passengers', languageCode)}'),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderC)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(translate('driver_and_crew', languageCode), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textCol)),
                  const SizedBox(height: 12),
                  ...drivers.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: _kTeal.withAlpha(20),
                        child: Text(d['name']![0], style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['name']!, style: TextStyle(fontWeight: FontWeight.w600, color: textCol, fontSize: 13)),
                        Text(d['role']!, style: TextStyle(color: subCol, fontSize: 11)),
                      ]),
                    ]),
                  )),
                  const Divider(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(translate('number_of_passengers', languageCode), style: TextStyle(color: subCol, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(border: Border.all(color: borderC), borderRadius: BorderRadius.circular(20)),
                      child: Text('+$passengers', style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: _kTeal.withAlpha(12), borderRadius: BorderRadius.circular(14), border: Border.all(color: _kTeal.withAlpha(40))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(translate('total_price', languageCode), style: TextStyle(fontWeight: FontWeight.bold, color: textCol, fontSize: 14)),
                  Text('RWF ${_fmtPrice(slot.priceRfw)}', style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, _slide(BuyTicketScreen(
                slot: slot, from: from, to: to, date: date, passengers: passengers,
                isDark: isDark, buspoints: buspoints, languageCode: languageCode,
                onBookingConfirmed: onBookingConfirmed,
              ))),
              icon: const Icon(Icons.confirmation_num_rounded, size: 18),
              label: Text(translate('buy_ticket', languageCode), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

String _fmtPrice(int rwf) => rwf.toString()
    .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

// ═════════════════════════════════════════════════════════════════════════════
// BUY TICKET SCREEN  (Step 2)
// ═════════════════════════════════════════════════════════════════════════════
class BuyTicketScreen extends StatefulWidget {
  final ScheduleSlot slot;
  final String from, to;
  final DateTime date;
  final int passengers;
  final bool isDark;
  final int buspoints;
  final String languageCode;
  final void Function(Map<String, dynamic>) onBookingConfirmed;
  const BuyTicketScreen({super.key, required this.slot, required this.from, required this.to,
      required this.date, required this.passengers, required this.isDark,
      required this.buspoints, required this.languageCode,
      required this.onBookingConfirmed});
  @override
  State<BuyTicketScreen> createState() => _BuyTicketScreenState();
}

class _BuyTicketScreenState extends State<BuyTicketScreen> {
  bool _isMember = true;
  final _nameCtrl  = TextEditingController(text: 'Aruna Dahlia');
  final _phoneCtrl = TextEditingController(text: '78-1234-5678');
  bool _agreed = false;
  String _phoneCode = '+250', _flag = '🇷🇼';
  static const List<Map<String, String>> _countries = [
    {'name':'Rwanda','flag':'🇷🇼','code':'+250'},
    {'name':'Kenya','flag':'🇰🇪','code':'+254'},
    {'name':'Uganda','flag':'🇺🇬','code':'+256'},
    {'name':'Tanzania','flag':'🇹🇿','code':'+255'},
  ];
  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  void _pickCountry() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 320, decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A2830) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 10, bottom: 8), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Text(translate('select_country', widget.languageCode), style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          ..._countries.map((c) => ListTile(
            leading: Text(c['flag']!, style: const TextStyle(fontSize: 22)),
            title: Text(c['name']!),
            trailing: Text(c['code']!, style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold)),
            onTap: () { setState(() { _phoneCode = c['code']!; _flag = c['flag']!; }); Navigator.pop(context); },
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final borderC = widget.isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    final inputBg = widget.isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: widget.isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white, elevation: 0, centerTitle: true,
        title: Text(translate('buy_ticket', widget.languageCode), style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionHeader(translate('order_information', widget.languageCode), isDark: widget.isDark,
                action: GestureDetector(onTap: () => Navigator.pop(context),
                  child: Row(children: [const Icon(Icons.edit_rounded, color: _kTeal, size: 14), const SizedBox(width: 4),
                    Text(translate('change', widget.languageCode), style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold, fontSize: 13))]))),
              const SizedBox(height: 8),
              _OrderInfoCard(slot: widget.slot, from: widget.from, to: widget.to, date: widget.date, passengers: widget.passengers, languageCode: widget.languageCode, isDark: widget.isDark),
              const SizedBox(height: 18),
              _SectionHeader(translate('passenger_information', widget.languageCode), isDark: widget.isDark),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderC)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('${translate('passenger_status', widget.languageCode)}', style: TextStyle(color: subCol, fontSize: 13)),
                    const SizedBox(width: 10),
                    _StatusChip(label: translate('member', widget.languageCode), selected: _isMember, onTap: () => setState(() => _isMember = true)),
                    const SizedBox(width: 8),
                    _StatusChip(label: translate('non_member', widget.languageCode), selected: !_isMember, onTap: () => setState(() => _isMember = false)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('${translate('facilities', widget.languageCode)}', style: TextStyle(color: subCol, fontSize: 13)),
                    const SizedBox(width: 10),
                    _FacilityChip(label: translate('meal_service', widget.languageCode), icon: Icons.restaurant, color: Colors.orange),
                    const SizedBox(width: 8),
                    _FacilityChip(label: translate('snack_only', widget.languageCode), icon: Icons.fastfood_rounded, color: _kTeal),
                  ]),
                  const SizedBox(height: 14),
                  Text(translate('select_member_name', widget.languageCode), style: TextStyle(fontSize: 12, color: subCol)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderC)),
                    child: Row(children: [
                      Expanded(child: TextField(controller: _nameCtrl, style: TextStyle(fontSize: 14, color: textCol),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
                      Icon(Icons.keyboard_arrow_down_rounded, color: subCol, size: 18),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Text(translate('phone_number', widget.languageCode), style: TextStyle(fontSize: 12, color: subCol)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderC)),
                    child: Row(children: [
                      GestureDetector(onTap: _pickCountry, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(border: Border(right: BorderSide(color: borderC))),
                        child: Row(children: [
                          Text(_flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 4),
                          Text(_phoneCode, style: TextStyle(color: textCol, fontWeight: FontWeight.w600, fontSize: 13)),
                          Icon(Icons.keyboard_arrow_down_rounded, color: subCol, size: 16),
                        ]),
                      )),
                      Expanded(child: TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                        style: TextStyle(fontSize: 14, color: textCol),
                        decoration: InputDecoration(hintText: '78-XXXX-XXXX', hintStyle: TextStyle(color: subCol),
                          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange.withAlpha(18), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withAlpha(40))),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 14), const SizedBox(width: 6),
                      Expanded(child: Text(translate('ticket_sent_notification', widget.languageCode),
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade700, height: 1.4))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(onTap: () => setState(() => _agreed = !_agreed),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 20, height: 20,
                        decoration: BoxDecoration(color: _agreed ? _kTeal : Colors.transparent, borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _agreed ? _kTeal : Colors.grey.shade400, width: 1.5)),
                        child: _agreed ? const Icon(Icons.check, color: Colors.white, size: 13) : null)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(translate('agree_terms', widget.languageCode), style: TextStyle(fontSize: 12, color: subCol))),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${translate('total_price', widget.languageCode)} (${widget.passengers} ${translate('passengers', widget.languageCode)}${widget.passengers > 1 ? 's' : ''})', style: TextStyle(color: subCol, fontSize: 13)),
                Text('RWF ${_fmtPrice(widget.slot.priceRfw)}', style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: _agreed ? () => Navigator.push(context, PageRouteBuilder(
                pageBuilder: (_, _, _) => SummaryScreen(
                  slot: widget.slot, from: widget.from, to: widget.to, date: widget.date,
                  passengers: widget.passengers, isDark: widget.isDark,
                  passengerName: _nameCtrl.text.trim().isEmpty ? 'Guest' : _nameCtrl.text.trim(),
                  phoneNumber: '$_phoneCode ${_phoneCtrl.text.trim()}',
                  buspoints: widget.buspoints, languageCode: widget.languageCode,
                  onBookingConfirmed: widget.onBookingConfirmed,
                ),
                transitionsBuilder: (_, anim, _, child) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
                transitionDuration: const Duration(milliseconds: 280),
              )) : null,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(translate('continue', widget.languageCode), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, elevation: 0,
                disabledBackgroundColor: Colors.orange.withAlpha(80),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUMMARY SCREEN  (Step 3)
// ═════════════════════════════════════════════════════════════════════════════
class SummaryScreen extends StatefulWidget {
  final ScheduleSlot slot;
  final String from, to, passengerName, phoneNumber;
  final DateTime date;
  final int passengers, buspoints;
  final bool isDark;
  final String languageCode;
  final void Function(Map<String, dynamic>) onBookingConfirmed;
  const SummaryScreen({super.key, required this.slot, required this.from, required this.to,
      required this.date, required this.passengers, required this.isDark,
      required this.passengerName, required this.phoneNumber,
      required this.buspoints, required this.languageCode,
      required this.onBookingConfirmed});
  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _useBuspoint = false;
  bool get _buspointEligible => widget.buspoints >= (widget.slot.priceRfw ~/ widget.passengers);
  int get _serviceFee => 5000;
  int get _buspointDiscount => (_useBuspoint && _buspointEligible) ? widget.slot.priceRfw : 0;
  int get _totalCost => widget.slot.priceRfw + _serviceFee - _buspointDiscount;

  void _goToPayment(BuildContext ctx) {
    Navigator.push(ctx, PageRouteBuilder(
      pageBuilder: (_, _, _) => PaymentMethodScreen(
        isDark: widget.isDark,
        languageCode: widget.languageCode,
        totalCost: _totalCost,
        onPaymentSelected: (method) {
          Navigator.push(ctx, PageRouteBuilder(
            pageBuilder: (_, _, _) => TicketIssuedScreen(
              slot: widget.slot, from: widget.from, to: widget.to, date: widget.date,
              passengers: widget.passengers, isDark: widget.isDark,
              passengerName: widget.passengerName, phoneNumber: widget.phoneNumber,
              totalPaid: _totalCost, paymentMethod: method,
              onBookingConfirmed: widget.onBookingConfirmed,
              languageCode: widget.languageCode,
            ),
            transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ));
        },
      ),
      transitionsBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
      transitionDuration: const Duration(milliseconds: 280),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final borderC = widget.isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;

    Widget priceRow(String label, String val, {Color? valColor, bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: bold ? textCol : subCol, fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(val, style: TextStyle(color: valColor ?? textCol, fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
      ]),
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: widget.isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white, elevation: 0, centerTitle: true,
        title: Text(translate('summary', widget.languageCode), style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _SectionHeader(translate('order_information', widget.languageCode), isDark: widget.isDark,
                action: GestureDetector(onTap: () => Navigator.pop(context),
                  child: Row(children: [const Icon(Icons.edit_rounded, color: _kTeal, size: 14), const SizedBox(width: 4),
                    Text(translate('change', widget.languageCode), style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold, fontSize: 13))]))),
              const SizedBox(height: 8),
              _OrderInfoCard(slot: widget.slot, from: widget.from, to: widget.to, date: widget.date, passengers: widget.passengers, languageCode: widget.languageCode, isDark: widget.isDark),
              const SizedBox(height: 16),
              _SectionHeader(translate('passenger_information', widget.languageCode), isDark: widget.isDark,
                action: GestureDetector(onTap: () => Navigator.pop(context),
                  child: Row(children: [const Icon(Icons.edit_rounded, color: _kTeal, size: 14), const SizedBox(width: 4),
                    Text(translate('change', widget.languageCode), style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold, fontSize: 13))]))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderC)),
                child: Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: _kTeal.withAlpha(20),
                    child: Text(widget.passengerName[0].toUpperCase(), style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.passengerName, style: TextStyle(fontWeight: FontWeight.bold, color: textCol)),
                    Text(widget.phoneNumber, style: TextStyle(color: subCol, fontSize: 12)),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _kTeal.withAlpha(18), borderRadius: BorderRadius.circular(20)),
                    child: Text('• ${translate('member', widget.languageCode)}', style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold, fontSize: 11))),
                ]),
              ),
              const SizedBox(height: 16),
              _SectionHeader(translate('payment_and_pricing_information', widget.languageCode), isDark: widget.isDark),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderC)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Select payment method row
                  GestureDetector(
                    onTap: () => _goToPayment(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10), border: Border.all(color: borderC)),
                      child: Row(children: [
                        const Icon(Icons.payment_rounded, color: _kTeal, size: 18), const SizedBox(width: 10),
                        Expanded(child: Text(translate('select_payment_method', widget.languageCode), style: TextStyle(color: subCol, fontSize: 13))),
                        const Icon(Icons.chevron_right_rounded, color: _kTeal, size: 18),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Buspoint row
                  Row(children: [
                    GestureDetector(
                      onTap: () {
                        if (!_buspointEligible) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(translate('need_more_points', widget.languageCode)
                          .replaceAll('{points}', '${(widget.slot.priceRfw ~/ widget.passengers) - widget.buspoints}')
                          .replaceAll('{balance}', '${widget.buspoints}')),
                            backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3),
                          ));
                          return;
                        }
                        setState(() => _useBuspoint = !_useBuspoint);
                      },
                      child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 20, height: 20,
                        decoration: BoxDecoration(color: (_useBuspoint && _buspointEligible) ? _kTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(5), border: Border.all(color: _buspointEligible ? _kTeal : Colors.grey.shade400, width: 1.5)),
                        child: (_useBuspoint && _buspointEligible) ? const Icon(Icons.check, color: Colors.white, size: 13) : null),
                    ),
                    const SizedBox(width: 10),
                    Container(padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.orange.withAlpha(18), shape: BoxShape.circle),
                      child: const Icon(Icons.card_giftcard, color: Colors.orange, size: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${widget.buspoints} pts  (${_buspointEligible ? '-RWF ${_fmtPrice(widget.slot.priceRfw)}' : translate('need_more_points', widget.languageCode)
                            .replaceAll('{points}', '${(widget.slot.priceRfw ~/ widget.passengers) - widget.buspoints}')
                            .replaceAll('{balance}', '${widget.buspoints}')})',
                          style: TextStyle(fontSize: 13, color: _buspointEligible ? textCol : subCol, fontWeight: FontWeight.w500)),
                      Text(translate('buspoint_balance', widget.languageCode), style: TextStyle(fontSize: 11, color: subCol)),
                    ])),
                    if (!_buspointEligible) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.grey.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                      child: Text(translate('not_eligible', widget.languageCode), style: TextStyle(color: subCol, fontSize: 10)),
                    ),
                  ]),
                  const Divider(height: 22),
                  priceRow(translate('total_ticket', widget.languageCode), 'RWF ${_fmtPrice(widget.slot.priceRfw)}'),
                  priceRow(translate('service_fee', widget.languageCode), 'RWF ${_fmtPrice(_serviceFee)}'),
                  priceRow(translate('voucher', widget.languageCode), '-RWF 0', valColor: Colors.green),
                  if (_useBuspoint && _buspointEligible)
                    priceRow(translate('buspoint_discount', widget.languageCode), '-RWF ${_fmtPrice(_buspointDiscount)}', valColor: Colors.green),
                  const Divider(height: 16),
                  priceRow(translate('total_cost', widget.languageCode), 'RWF ${_fmtPrice(_totalCost)}', bold: true, valColor: _kTeal),
                ]),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${translate('total_price', widget.languageCode)} (${widget.passengers} ${translate('passengers', widget.languageCode)}${widget.passengers > 1 ? 's' : ''})', style: TextStyle(color: subCol, fontSize: 13)),
                Text('RWF ${_fmtPrice(_totalCost)}', style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _goToPayment(context),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text(translate('pay_now', widget.languageCode), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PAYMENT METHOD SCREEN  (Step 4)
// ═════════════════════════════════════════════════════════════════════════════
class PaymentMethodScreen extends StatefulWidget {
  final bool isDark;
  final String languageCode;
  final int totalCost;
  final void Function(String) onPaymentSelected;
  const PaymentMethodScreen({super.key, required this.isDark, required this.languageCode, required this.totalCost, required this.onPaymentSelected});
  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String? _selected;
  static const List<Map<String, dynamic>> _methods = [
    {'id':'mtn_momo',   'labelKey':'mtn_mobile_money','subKey':'pay_via_mtn_mobile_money','image':'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5b/MTN_Mobile_Money_logo.png/320px-MTN_Mobile_Money_logo.png'},
    {'id':'airtel_momo','labelKey':'airtel_money','subKey':'pay_via_airtel_money','image':'https://upload.wikimedia.org/wikipedia/commons/thumb/7/75/Airtel_Money_logo.png/320px-Airtel_Money_logo.png'},
    {'id':'card',       'labelKey':'debit_credit_card','subKey':'pay_with_card','image':'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Visa_Logo.png/320px-Visa_Logo.png'},
    {'id':'digital_banking','labelKey':'digital_banking','subKey':'pay_via_digital_banking','image':'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Bank_%28PSF%29_Logo.svg/1200px-Bank_%28PSF%29_Logo.svg.png'},
  ];

  void _confirm() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translate('please_select_payment_method', widget.languageCode)), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
      return;
    }
    if (_selected == 'airtel_momo' || _selected == 'mtn_momo') {
      final phone = await showModalBottomSheet<String>(context: context, isScrollControlled: true,
          backgroundColor: Colors.transparent, builder: (_) => _MobileMoneySheet(isDark: widget.isDark, languageCode: widget.languageCode, method: _selected!, amount: widget.totalCost));
      if (phone != null && mounted) {
        final label = translate(_selected == 'airtel_momo' ? 'airtel_money' : 'mtn_mobile_money', widget.languageCode);
        widget.onPaymentSelected('$label · $phone');
      }
    } else if (_selected == 'digital_banking') {
      final bank = await showModalBottomSheet<String>(context: context, isScrollControlled: true,
          backgroundColor: Colors.transparent, builder: (_) => _DigitalBankSelectionSheet(isDark: widget.isDark, languageCode: widget.languageCode));
      if (bank != null && mounted) widget.onPaymentSelected(bank);
    } else if (_selected == 'card') {
      final cardLabel = await showModalBottomSheet<String>(context: context, isScrollControlled: true,
          backgroundColor: Colors.transparent, builder: (_) => _CardPaymentSheet(isDark: widget.isDark, languageCode: widget.languageCode, amount: widget.totalCost));
      if (cardLabel != null && mounted) widget.onPaymentSelected(cardLabel);
    } else {
      final item = _methods.firstWhere((m) => m['id'] as String == _selected!);
      final labelKey = item['labelKey'] as String;
      widget.onPaymentSelected(translate(labelKey, widget.languageCode));
    }
  }

  Color _payColor(String methodId) {
    switch(methodId) {
      case 'airtel_momo':   return const Color(0xFFE60000);
      case 'mtn_momo':      return const Color(0xFFFFCC00);
      case 'card':          return const Color(0xFF205081);
      case 'digital_banking':  return const Color(0xFF003087);
      default:              return _kTeal;
    }
  }

  Widget _payIcon(String icon, bool sel, String? imageUrl) {
    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.payment_rounded, color: sel ? _kTeal : Colors.grey.shade600, size: 26),
        ),
      );
    }
    switch(icon) {
      case 'airtel': return Stack(alignment: Alignment.center, children: [
        Container(decoration: BoxDecoration(color: const Color(0xFFE60000), borderRadius: BorderRadius.circular(10))),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Text('Airtel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
          Text('Money', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
        ]),
      ]);
      case 'mtn': return Stack(alignment: Alignment.center, children: [
        Container(decoration: BoxDecoration(color: const Color(0xFFFFCC00), borderRadius: BorderRadius.circular(10))),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Text('MTN', style: TextStyle(color: Color(0xFF003087), fontWeight: FontWeight.w900, fontSize: 12)),
          Text('MoMo', style: TextStyle(color: Color(0xFF003087), fontWeight: FontWeight.bold, fontSize: 8)),
        ]),
      ]);
      case 'card': return const Icon(Icons.credit_card, color: _kTeal, size: 26);
      case 'digital': return Stack(alignment: Alignment.center, children: [
        Container(decoration: BoxDecoration(color: const Color(0xFF003087), borderRadius: BorderRadius.circular(10))),
        const Icon(Icons.account_balance, color: Colors.white, size: 24),
      ]);
      default: return const Icon(Icons.payment_rounded, color: _kTeal, size: 24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0D1C22) : const Color(0xFFF4F7F9);
    final cardBg = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final borderC = widget.isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: widget.isDark ? const Color(0xFF111C22) : _kTeal,
        foregroundColor: Colors.white, elevation: 0, centerTitle: true,
        title: Text(translate('payment_method_title', widget.languageCode), style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text(translate('how_would_you_like_to_pay', widget.languageCode), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol)),
          const SizedBox(height: 20),
          Expanded(child: ListView(children: _methods.map((m) {
            final isSel = _selected == m['id'] as String;
            return GestureDetector(
              onTap: () => setState(() => _selected = m['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSel ? _kTeal.withAlpha(15) : cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSel ? _kTeal : borderC, width: isSel ? 2 : 1)),
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: _payColor(m['id'] as String).withAlpha(22), borderRadius: BorderRadius.circular(10)),
                    child: _payIcon(m['id'] as String, isSel, m['image'] as String?)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(translate(m['labelKey'] as String, widget.languageCode), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isSel ? _kTeal : textCol)),
                    Text(translate(m['subKey'] as String, widget.languageCode), style: TextStyle(fontSize: 11, color: subCol)),
                  ])),
                  AnimatedContainer(duration: const Duration(milliseconds: 180), width: 22, height: 22,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSel ? _kTeal : Colors.grey.shade400, width: 2), color: isSel ? _kTeal : Colors.transparent),
                    child: isSel ? const Icon(Icons.check, color: Colors.white, size: 14) : null),
                ]),
              ),
            );
          }).toList())),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Pay RWF ${_fmtPrice(widget.totalCost)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6), const Icon(Icons.arrow_forward_rounded, size: 18),
              ]),
            )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ── MTN Mobile Money Sheet ─────────────────────────────────────────────────
class _MobileMoneySheet extends StatefulWidget {
  final bool isDark;
  final String languageCode;
  final String method;
  final int amount;
  const _MobileMoneySheet({required this.isDark, required this.languageCode, required this.method, required this.amount});
  @override
  State<_MobileMoneySheet> createState() => _MobileMoneySheetState();
}
class _MobileMoneySheetState extends State<_MobileMoneySheet> {
  final _ctrl = TextEditingController();
  bool _saved = false;
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = widget.isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final borderC = widget.isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    final inputBg = widget.isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 16), width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Container(width: 64, height: 64, decoration: BoxDecoration(color: widget.method == 'airtel_momo' ? const Color(0xFFE60000) : const Color(0xFFFFCC00), borderRadius: BorderRadius.circular(18)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(widget.method == 'airtel_momo' ? 'Airtel' : 'MTN', style: TextStyle(color: widget.method == 'airtel_momo' ? Colors.white : const Color(0xFF003087), fontWeight: FontWeight.w900, fontSize: 16)),
              Text(widget.method == 'airtel_momo' ? 'Money' : 'MoMo', style: TextStyle(color: widget.method == 'airtel_momo' ? Colors.white : const Color(0xFF003087), fontWeight: FontWeight.bold, fontSize: 10)),
            ])),
          const SizedBox(height: 14),
          Text(widget.method == 'airtel_momo' ? translate('airtel_money', widget.languageCode) : translate('mtn_mobile_money', widget.languageCode), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol)),
          const SizedBox(height: 4),
          Text(widget.method == 'airtel_momo' ? translate('enter_airtel_account_number', widget.languageCode) : translate('enter_mtn_account_number', widget.languageCode), style: TextStyle(fontSize: 13, color: subCol)),
          const SizedBox(height: 12),
          Text(translate('after_pay_prompt', widget.languageCode), style: TextStyle(fontSize: 12, color: subCol)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderC)),
            child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(border: Border(right: BorderSide(color: borderC))),
                child: const Row(children: [
                  Text('🇷🇼', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 4),
                  Text('+250', style: TextStyle(color: _kTeal, fontWeight: FontWeight.w600, fontSize: 13)),
                ])),
              Expanded(child: TextField(controller: _ctrl, keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 15, color: textCol),
                decoration: InputDecoration(
                  hintText: widget.method == 'airtel_momo' ? '072XXXXXXX' : '078/9XXXXXXX',
                  hintStyle: TextStyle(color: subCol),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ))),
              Padding(padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: () { setState(() => _saved = true); FocusScope.of(context).unfocus(); },
                  style: TextButton.styleFrom(foregroundColor: _kTeal),
                  child: Text(translate('save', widget.languageCode), style: const TextStyle(fontWeight: FontWeight.bold)))),
            ]),
          ),
          if (_saved) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16), const SizedBox(width: 6),
                Text(translate('number_saved', widget.languageCode), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13)),
              ])),
          ],
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                final num = _ctrl.text.trim();
                if (num.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translate('please_enter_phone_number', widget.languageCode)), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
                  return;
                }
                Navigator.pop(context, '+250 $num');
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00), foregroundColor: const Color(0xFF003087), elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Pay RWF ${_fmtPrice(widget.amount)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            )),
        ]),
      ),
    );
  }
}

// ── Card payment sheet for Debit/Credit Card selection
class _CardPaymentSheet extends StatefulWidget {
  final bool isDark;
  final String languageCode;
  final int amount;
  const _CardPaymentSheet({required this.isDark, required this.languageCode, required this.amount});
  @override
  State<_CardPaymentSheet> createState() => _CardPaymentSheetState();
}

class _CardPaymentSheetState extends State<_CardPaymentSheet> {
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  String get _cardLabel {
    final number = _numberCtrl.text.trim();
    if (number.startsWith('4')) return 'Visa';
    if (number.startsWith('5')) return 'Mastercard';
    return 'Card';
  }

  void _pay() {
    final name = _nameCtrl.text.trim();
    final number = _numberCtrl.text.replaceAll(' ', '').trim();
    final expiry = _expiryCtrl.text.trim();
    final cvv = _cvvCtrl.text.trim();
    if (name.isEmpty || number.length < 12 || expiry.length < 4 || cvv.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translate('complete_card_fields', widget.languageCode)),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final last4 = number.length >= 4 ? number.substring(number.length - 4) : number;
    Navigator.pop(context, '${widget.languageCode == 'rw' ? 'Ikadi' : _cardLabel} · **** $last4');
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = widget.isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = widget.isDark ? const Color(0xFF7DA6B4) : Colors.grey.shade500;
    final borderC = widget.isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    final inputBg = widget.isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Text(translate('debit_credit_card', widget.languageCode), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textCol)),
          const SizedBox(height: 6),
          Text(translate('enter_card_details', widget.languageCode), style: TextStyle(color: subCol, fontSize: 13)),
          const SizedBox(height: 18),
          _buildField(label: translate('cardholder_name', widget.languageCode), controller: _nameCtrl, textCapitalization: TextCapitalization.words, inputType: TextInputType.name, hintText: translate('enter_name_on_card', widget.languageCode), bg: inputBg, borderC: borderC, textColor: textCol),
          const SizedBox(height: 12),
          _buildCardNumberField(label: translate('card_number', widget.languageCode), controller: _numberCtrl, inputType: TextInputType.number, hintText: translate('enter_card_number', widget.languageCode), bg: inputBg, borderC: borderC, textColor: textCol),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildField(label: translate('expiry_date', widget.languageCode), controller: _expiryCtrl, inputType: TextInputType.datetime, hintText: translate('expiry_format', widget.languageCode), bg: inputBg, borderC: borderC, textColor: textCol)),
            const SizedBox(width: 12),
            Expanded(child: _buildField(label: translate('cvv', widget.languageCode), controller: _cvvCtrl, inputType: TextInputType.number, hintText: translate('cvv', widget.languageCode), bg: inputBg, borderC: borderC, obscureText: true, textColor: textCol)),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _pay,
              style: ElevatedButton.styleFrom(backgroundColor: _kTeal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Pay RWF ${_fmtPrice(widget.amount)} with $_cardLabel', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildField({required String label, required TextEditingController controller, required TextInputType inputType, required String hintText, required Color bg, required Color borderC, required Color textColor, bool obscureText = false, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderC)),
        child: TextField(
          controller: controller,
          keyboardType: inputType,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade500),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    ]);
  }

  Widget _buildCardNumberField({required String label, required TextEditingController controller, required TextInputType inputType, required String hintText, required Color bg, required Color borderC, required Color textColor}) {
    const visaUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Visa_Logo.png/320px-Visa_Logo.png';
    const mcUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/04/Mastercard-logo.svg/320px-Mastercard-logo.svg.png';
    final brand = _cardLabel;

    Widget logo(String url) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(url, width: 38, height: 22, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(width: 38, height: 22)),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderC)),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: inputType,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey.shade500),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              if (brand == 'Visa' || brand == 'Card') logo(visaUrl),
              if (brand == 'Card') const SizedBox(width: 6),
              if (brand == 'Mastercard' || brand == 'Card') logo(mcUrl),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

// ── BK Bank Selection Sheet ─────────────────────────────────────────────────
class _DigitalBankSelectionSheet extends StatelessWidget {
  final bool isDark;
  final String languageCode;
  const _DigitalBankSelectionSheet({required this.isDark, required this.languageCode});
  static const List<Map<String, dynamic>> _banks = [
    {'id':'bk',       'name':'Bank of Kigali (BK)', 'abbr':'BK', 'color':0xFF003087},
    {'id':'equity',   'name':'Equity Bank',         'abbr':'EQ', 'color':0xFFCC0000},
    {'id':'im',       'name':'I&M Bank',            'abbr':'IM', 'color':0xFF0081C6},
    {'id':'ecobank',  'name':'Ecobank',             'abbr':'EC', 'color':0xFFEF3E21},
    {'id':'boa',      'name':'Bank of Africa',      'abbr':'BA', 'color':0xFF006341},
    {'id':'access',   'name':'Access Bank',         'abbr':'AB', 'color':0xFF0D2B7A},
    {'id':'bpr',      'name':'Banque Populaire du Rwanda (BPR)', 'abbr':'BPR', 'color':0xFF2A5E95},
    {'id':'gtbank',   'name':'GT Bank',             'abbr':'GT', 'color':0xFF1F7D31},
  ];
  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol = isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final borderC = isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 12, bottom: 16), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Text(translate('select_bank', languageCode), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textCol)),
        const SizedBox(height: 6),
        Text(translate('choose_bank_to_complete_payment', languageCode), style: TextStyle(fontSize: 13, color: subCol)),
        const SizedBox(height: 24),
        ..._banks.map((b) => GestureDetector(
          onTap: () => Navigator.pop(context, b['name'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2E38) : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderC)),
            child: Row(children: [
              Container(width: 56, height: 56,
                decoration: BoxDecoration(color: Color(b['color'] as int), borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Color(b['color'] as int).withAlpha(80), blurRadius: 10, offset: const Offset(0, 3))]),
                child: Center(child: Text(b['abbr'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCol)),
                Text(translate('tap_to_pay_via', languageCode).replaceAll('{bank}', b['name'] as String), style: TextStyle(fontSize: 12, color: subCol)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: subCol, size: 16),
            ]),
          ),
        )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TICKET ISSUED SCREEN  (Step 5 — final e-Ticket)
// ═════════════════════════════════════════════════════════════════════════════
class TicketIssuedScreen extends StatefulWidget {
  final ScheduleSlot slot;
  final String from, to, passengerName, phoneNumber, paymentMethod;
  final DateTime date;
  final int passengers, totalPaid;
  final bool isDark;
  final String languageCode;
  final void Function(Map<String, dynamic>) onBookingConfirmed;
  const TicketIssuedScreen({super.key, required this.slot, required this.from, required this.to,
      required this.date, required this.passengers, required this.isDark,
      required this.passengerName, required this.phoneNumber,
      required this.totalPaid, required this.paymentMethod, required this.onBookingConfirmed,
      required this.languageCode});
  @override
  State<TicketIssuedScreen> createState() => _TicketIssuedScreenState();
}

class _TicketIssuedScreenState extends State<TicketIssuedScreen> {
  late final String _txId;
  late final String _txTime;
  bool _bookingFired = false;

  @override
  void initState() {
    super.initState();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _txId   = 'TXN${ts.toString().substring(ts.toString().length - 9)}';
    _txTime = DateFormat('HH:mm').format(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_bookingFired) {
        _bookingFired = true;
        widget.onBookingConfirmed({
          'from':  widget.from,
          'to':    widget.to,
          'date':  DateFormat('dd/MM/yyyy').format(widget.date),
          'time':  widget.slot.depTime,
          'price': widget.totalPaid,
          'passengers': widget.passengers,
          'passengerName': widget.passengerName,
          'phoneNumber': widget.phoneNumber,
          'paymentMethod': widget.paymentMethod,
          'busNumber': widget.slot.busNumber,
          'routeType': widget.slot.routeType,
          'transactionId': _txId,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02515F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF02515F), elevation: 0,
        title: Text(translate('ticket_issued', widget.languageCode), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(children: [
              // e-Ticket card
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 24, offset: const Offset(0, 8))]),
                child: Column(children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(color: Color(0xFF02515F), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    child: Column(children: [
                      Row(children: [
                        Text(translate('e_ticket', widget.languageCode), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                          child: Text(_txId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Container(padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(translate('bus_number', widget.languageCode), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          Text(widget.slot.busNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ])),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                          child: Row(children: [
                            const Icon(Icons.bolt_rounded, color: Colors.orange, size: 13), const SizedBox(width: 3),
                            Text(widget.slot.routeType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ])),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.from, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                          Text(widget.slot.depTime, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ])),
                        const Column(children: [
                          Icon(Icons.location_on_rounded, color: Colors.orange, size: 18),
                          SizedBox(width: 30, height: 1),
                        ]),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(widget.to, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                          Text(widget.slot.arrTime, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ])),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _TChip(icon: Icons.people_rounded, label: '${widget.passengers}'),
                        const SizedBox(width: 8),
                        const _TChip(icon: Icons.restaurant_rounded, label: 'Meal Service'),
                      ]),
                    ]),
                  ),

                  // Jagged separator
                  SizedBox(height: 28, child: CustomPaint(painter: _JaggedPainter(), child: Container())),

                  // White body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _InfoBlock(label: 'Name', value: widget.passengerName)),
                        Expanded(child: _InfoBlock(label: translate('whatsapp_number', widget.languageCode), value: widget.phoneNumber)),
                      ]),
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _InfoBlock(label: translate('transaction_date', widget.languageCode), value: DateFormat('dd/MM/yyyy').format(widget.date))),
                        Expanded(child: _InfoBlock(label: translate('transaction_time', widget.languageCode), value: '$_txTime WIB')),
                      ]),
                      const SizedBox(height: 20),
                      // Barcode
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(children: [
                          SizedBox(width: double.infinity, height: 70,
                            child: CustomPaint(painter: _BarcodePainter(seed: widget.slot.busNumber.hashCode))),
                          const SizedBox(height: 10),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: _kTeal.withAlpha(12), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kTeal.withAlpha(40))),
                            child: Row(children: [
                              const Icon(Icons.qr_code_scanner_rounded, color: _kTeal, size: 16), const SizedBox(width: 8),
                              Expanded(child: Text(translate('show_qr_instruction', widget.languageCode),
                                  style: const TextStyle(fontSize: 12, color: _kTeal, fontWeight: FontWeight.w600))),
                            ])),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.payment_rounded, color: Colors.white70, size: 18), const SizedBox(width: 10),
                  Text('${translate('paid_via', widget.languageCode)} ${widget.paymentMethod}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('RWF ${_fmtPrice(widget.totalPaid)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(children: [
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _downloadTicket,
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(translate('download', widget.languageCode), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 46,
              child: OutlinedButton.icon(
                onPressed: () => _shareText(_buildTicketFileContent()),
                icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white70),
                label: Text(translate('share_ticket', widget.languageCode), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withAlpha(60)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (_, __, ___) => LiveMapScreen(isDark: widget.isDark, languageCode: widget.languageCode),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 240),
                  ));
                },
                icon: const Icon(Icons.map_rounded, size: 18, color: Colors.white70),
                label: Text(translate('view_route', widget.languageCode), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withAlpha(60)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
          ]),
        ),
      ]),
    );
  }

  String _buildTicketFileContent() => '''
moveKigali e-Ticket
-------------------
Transaction ID: $_txId
From: ${widget.from}
To: ${widget.to}
Date: ${DateFormat('dd/MM/yyyy').format(widget.date)}
Departure: ${widget.slot.depTime}
Arrival: ${widget.slot.arrTime}
${translate('passenger', widget.languageCode)}: ${widget.passengerName}
${translate('phone_number', widget.languageCode)}: ${widget.phoneNumber}
${translate('bus_number', widget.languageCode)}: ${widget.slot.busNumber}
${translate('route_type', widget.languageCode)}: ${widget.slot.routeType}
${translate('passengers', widget.languageCode)}: ${widget.passengers}
${translate('amount_paid', widget.languageCode)}: RWF ${_fmtPrice(widget.totalPaid)}
${translate('payment_method', widget.languageCode)}: ${widget.paymentMethod}
''';

  Future<void> _downloadTicket() async {
    final fileName = 'moveKigali_ticket_${DateTime.now().millisecondsSinceEpoch}.txt';
    final contents = _buildTicketFileContent();
    try {
      final savedPath = await saveTicketAsFile(fileName, contents);
      if (!mounted) return;
      final message = kIsWeb
          ? 'Ticket download started'
          : 'Ticket saved to $savedPath';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save ticket: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ── Ticket widget helpers ──────────────────────────────────────────────────
class _TChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 13), const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _InfoBlock extends StatelessWidget {
  final String label, value;
  const _InfoBlock({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
  ]);
}

class _JaggedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 2), Paint()..color = const Color(0xFF02515F));
    canvas.drawRect(Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2), Paint()..color = Colors.white);
    final cp = Paint()..color = const Color(0xFF02515F);
    canvas.drawCircle(Offset(0, size.height / 2), 14, cp);
    canvas.drawCircle(Offset(size.width, size.height / 2), 14, cp);
    final dp = Paint()..color = Colors.grey.shade300..strokeWidth = 1.2;
    double x = 28;
    while (x < size.width - 28) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 8, size.height / 2), dp);
      x += 14;
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _BarcodePainter extends CustomPainter {
  final int seed;
  const _BarcodePainter({required this.seed});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final rng = seed.abs();
    double x = 0;
    int i = 0;
    while (x < size.width) {
      final w = 1.0 + ((rng + i * 37) % 4).toDouble();
      final gap = 1.0 + ((rng + i * 53) % 3).toDouble();
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w + gap;
      i++;
    }
  }
  @override
  bool shouldRepaint(_BarcodePainter old) => old.seed != seed;
}

// ── Shared helper widgets ──────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  final Widget? action;
  const _SectionHeader(this.title, {this.isDark = false, this.action});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFD0E8F0) : Colors.black87)),
    if (action != null) action!,
  ]);
}

class _OrderInfoCard extends StatelessWidget {
  final ScheduleSlot slot;
  final String from, to;
  final DateTime date;
  final int passengers;
  final String languageCode;
  final bool isDark;
  const _OrderInfoCard({required this.slot, required this.from, required this.to,
      required this.date, required this.passengers, required this.languageCode, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final cardBg  = isDark ? const Color(0xFF1A2830) : Colors.white;
    final textCol = isDark ? const Color(0xFFD0E8F0) : Colors.black87;
    final subCol  = isDark ? const Color(0xFF4A6A7A) : Colors.grey.shade500;
    final borderC = isDark ? const Color(0xFF2A3E4A) : Colors.grey.shade200;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderC)),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(from, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textCol), overflow: TextOverflow.ellipsis),
            Text(slot.depTime, style: TextStyle(color: subCol, fontSize: 12)),
          ])),
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _kTeal.withAlpha(16), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward_rounded, color: _kTeal, size: 14)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(to, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textCol), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
            Text(slot.arrTime, style: TextStyle(color: subCol, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(translate('date', languageCode), style: TextStyle(color: subCol, fontSize: 11)),
            Text(DateFormat('EEE, dd/MM/yyyy').format(date), style: TextStyle(color: textCol, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(translate('passengers', languageCode), style: TextStyle(color: subCol, fontSize: 11)),
            Text('$passengers ${translate('passengers', languageCode).toLowerCase()}', style: TextStyle(color: textCol, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.orange.withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.directions_bus_rounded, color: Colors.orange, size: 14)),
          const SizedBox(width: 8),
          Text(slot.busNumber, style: TextStyle(fontWeight: FontWeight.bold, color: textCol, fontSize: 13)),
          const Spacer(),
          Text('RWF ${_fmtPrice(slot.priceRfw)}', style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: selected ? Colors.orange : Colors.transparent, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.orange : Colors.grey.shade300)),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12))));
}

class _FacilityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _FacilityChip({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withAlpha(50))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13), const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    ]));
} 