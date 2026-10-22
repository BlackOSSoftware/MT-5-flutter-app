import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';

/// MT5 "Change master / investor / trader / money manager password".
/// Har type ke liye current MASTER password chahiye; naya password strong
/// (8+ chars, lower + upper + digit + symbol) aur confirmation same ho tabhi
/// DONE chalu hota hai.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    super.key,
    required this.kind,
    required this.accountLine,
  });

  /// master | investor | trader | money_manager
  final String kind;

  /// Header subtitle, jaise "114371320, Kuch Vbhee".
  final String accountLine;

  static String labelFor(String kind) => switch (kind) {
    'investor' => 'investor',
    'trader' => 'trader',
    'money_manager' => 'money manager',
    _ => 'master',
  };

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _label => ChangePasswordPage.labelFor(widget.kind);

  /// 0..4 - lower, upper, digit, symbol; 8 se chhota ho to max 3.
  int get _strength {
    final p = _next.text;
    var s = 0;
    if (RegExp('[a-z]').hasMatch(p)) s++;
    if (RegExp('[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp('[^A-Za-z0-9]').hasMatch(p)) s++;
    if (p.length < 8 && s > 3) s = 3;
    return s;
  }

  bool get _valid =>
      _current.text.isNotEmpty &&
      _strength == 4 &&
      !_next.text.contains(' ') &&
      _confirm.text == _next.text;

  Future<void> _done() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await tradingService.changePassword(
        kind: widget.kind,
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('The $_label password has been changed')),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MtColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back, color: MtColors.text),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change $_label password',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            letterSpacing: -0.4,
                            color: MtColors.text,
                          ),
                        ),
                        Text(
                          widget.accountLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  _field(_current, 'Current master password'),
                  _field(_next, 'New $_label password'),
                  const SizedBox(height: 14),
                  _strengthBar(),
                  _field(_confirm, 'New password confirmation'),
                  const SizedBox(height: 14),
                  _hint(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _valid && !_busy ? _done : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF168BE1),
                    disabledBackgroundColor: const Color(0xFFD9D9D9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'DONE',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

  Widget _field(TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: TextField(
        controller: ctrl,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 16, color: MtColors.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF8A8A8A)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF168BE1), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _strengthBar() {
    final s = _strength;
    final color = switch (s) {
      0 || 1 => const Color(0xFFE53935),
      2 => const Color(0xFFFB8C00),
      3 => const Color(0xFFFDD835),
      _ => const Color(0xFF43A047),
    };
    final filled = s < 1 ? 1 : s;
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 4,
              color: i < filled ? color : const Color(0xFFE0E0E0),
            ),
          ),
        ],
      ],
    );
  }

  Widget _hint() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Text(
                  'A',
                  style: TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              ),
              Positioned(
                left: 11,
                top: 2,
                child: Text(
                  'z',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              ),
              Positioned(
                left: 5,
                top: 12,
                child: Text(
                  '5',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Password must be strong and contain at least 8 characters, '
            'including lower- and uppercase letters, numbers and special '
            'symbols',
            style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
          ),
        ),
      ],
    );
  }
}
