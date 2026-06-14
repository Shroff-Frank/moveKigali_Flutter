import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
// ignore: unused_element
const _kTeal = Color(0xFF02515F);
const _kBlue = Color(0xFF4A90D9);

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class NotificationScreen extends StatefulWidget {
  final bool isDark;

  const NotificationScreen({super.key, this.isDark = false});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // ── Common ──────────────────────────────────────────────────────────────────
  bool _generalNotif = true;
  bool _sound = false;
  bool _vibrate = true;

  // ── System & services update ────────────────────────────────────────────────
  bool _appUpdates = false;
  bool _billReminder = true;
  bool _promotion = true;
  bool _discountAvailable = false;
  bool _paymentRequest = false;

  // ── Others ──────────────────────────────────────────────────────────────────
  bool _newServiceAvailable = false;
  bool _newTipsAvailable = true;

  // ── Colour helpers ──────────────────────────────────────────────────────────
  bool get _d => widget.isDark;
  Color get _bg => _d ? const Color(0xFF0D1C22) : Colors.white;
  Color get _appBarBg => _d ? const Color(0xFF111C22) : Colors.white;
  Color get _textCol => _d ? const Color(0xFFD0E8F0) : const Color(0xFF1A1A2E);
  Color get _sectionCol => _d ? const Color(0xFF8FAAB8) : const Color(0xFF1A1A2E);
  Color get _dividerCol => _d ? const Color(0xFF1E2E38) : const Color(0xFFF0F0F5);
  Color get _rowBg => _d ? const Color(0xFF111C22) : Colors.white;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _d ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _appBarBg,
          foregroundColor: _textCol,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            'Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textCol,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textCol, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: _dividerCol),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Common ────────────────────────────────────────────────────────
            _sectionHeader('Common'),
            _toggleRow(
              label: 'General Notification',
              value: _generalNotif,
              onChanged: (v) => setState(() => _generalNotif = v),
              isFirst: true,
            ),
            _toggleRow(
              label: 'Sound',
              value: _sound,
              onChanged: (v) => setState(() => _sound = v),
            ),
            _toggleRow(
              label: 'Vibrate',
              value: _vibrate,
              onChanged: (v) => setState(() => _vibrate = v),
              isLast: true,
            ),

            // ── System & services update ──────────────────────────────────────
            _sectionHeader('System & services update'),
            _toggleRow(
              label: 'App updates',
              value: _appUpdates,
              onChanged: (v) => setState(() => _appUpdates = v),
              isFirst: true,
            ),
            _toggleRow(
              label: 'Bill Reminder',
              value: _billReminder,
              onChanged: (v) => setState(() => _billReminder = v),
            ),
            _toggleRow(
              label: 'Promotion',
              value: _promotion,
              onChanged: (v) => setState(() => _promotion = v),
            ),
            _toggleRow(
              label: 'Discount Available',
              value: _discountAvailable,
              onChanged: (v) => setState(() => _discountAvailable = v),
            ),
            _toggleRow(
              label: 'Payment Request',
              value: _paymentRequest,
              onChanged: (v) => setState(() => _paymentRequest = v),
              isLast: true,
            ),

            // ── Others ────────────────────────────────────────────────────────
            _sectionHeader('Others'),
            _toggleRow(
              label: 'New Service Available',
              value: _newServiceAvailable,
              onChanged: (v) => setState(() => _newServiceAvailable = v),
              isFirst: true,
            ),
            _toggleRow(
              label: 'New Tips Available',
              value: _newTipsAvailable,
              onChanged: (v) => setState(() => _newTipsAvailable = v),
              isLast: true,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Section header ──────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _sectionCol,
        ),
      ),
    );
  }

  // ── Toggle row ──────────────────────────────────────────────────────────────
  Widget _toggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    // ignore: unused_local_variable
    final radius = BorderRadius.only(
      topLeft: isFirst ? const Radius.circular(0) : Radius.zero,
      topRight: isFirst ? const Radius.circular(0) : Radius.zero,
      bottomLeft: isLast ? const Radius.circular(0) : Radius.zero,
      bottomRight: isLast ? const Radius.circular(0) : Radius.zero,
    );

    return Column(
      children: [
        Container(
          color: _rowBg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: _textCol,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: _kBlue,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: _d
                        ? const Color(0xFF2E4250)
                        : Colors.grey.shade300,
                    trackOutlineColor:
                        WidgetStateProperty.all(Colors.transparent),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            indent: 20,
            endIndent: 20,
            height: 1,
            color: _dividerCol,
          ),
      ],
    );
  }
}