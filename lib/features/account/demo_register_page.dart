import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import 'account_created_page.dart';
import 'mq_widgets.dart';

/// "Open a demo account" form (MetaQuotes Ltd.).
/// On REGISTER the account is created on OUR server only
/// (POST /v1/metaquotes/demo/register -> Mongo collection
/// `metaquotes_demo_accounts`) and the generated login/password
/// are shown to the user. No trading session is started.
class DemoRegisterPage extends StatefulWidget {
  const DemoRegisterPage({super.key});

  @override
  State<DemoRegisterPage> createState() => _DemoRegisterPageState();
}

class _DemoRegisterPageState extends State<DemoRegisterPage> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  final _dob = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  bool _hedge = true;
  bool _accept = false;
  bool _busy = false;

  // Inline validation errors (MT5 style: red underline + red text
  // below the field, shown after REGISTER is tapped).
  String? _firstError;
  String? _secondError;
  String? _phoneError;
  String? _emailError;
  bool _acceptError = false;
  String _server = 'MetaQuotes-Demo';
  String _accountType = 'Forex Hedged USD';
  String _leverage = '1:100';
  int _deposit = 100000;

  static const _depositValues = [
    3000,
    5000,
    10000,
    25000,
    50000,
    100000,
    500000,
    1000000,
    5000000,
  ];

  /// Selected date of birth; defaults to exactly 18 years before
  /// today and is shown in the field from the start.
  late DateTime _dobDate;

  static String _formatDob(DateTime d) =>
      '${d.month}/${d.day}/${'${d.year}'.substring(2)}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dobDate = DateTime(now.year - 18, now.month, now.day);
    _dob.text = _formatDob(_dobDate);
    _restoreForm();
  }

  // ---- Local persistence -------------------------------------------
  // Jo detail user ek baar daal deta hai woh phone me save ho jati
  // hai; page dobara khulne par form khud refill ho jata hai.
  static const _k = 'mq_demo_form_';

  Future<void> _restoreForm() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _first.text = p.getString('${_k}first') ?? _first.text;
      _second.text = p.getString('${_k}second') ?? _second.text;
      _phone.text = p.getString('${_k}phone') ?? _phone.text;
      _email.text = p.getString('${_k}email') ?? _email.text;
      final dobIso = p.getString('${_k}dob');
      final dob = dobIso == null ? null : DateTime.tryParse(dobIso);
      if (dob != null) {
        _dobDate = dob;
        _dob.text = _formatDob(dob);
      }
      _server = p.getString('${_k}server') ?? _server;
      _accountType = p.getString('${_k}accountType') ?? _accountType;
      _leverage = p.getString('${_k}leverage') ?? _leverage;
      _deposit = p.getInt('${_k}deposit') ?? _deposit;
      _hedge = p.getBool('${_k}hedge') ?? _hedge;
    });
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('${_k}first', _first.text);
    await p.setString('${_k}second', _second.text);
    await p.setString('${_k}dob', _dobDate.toIso8601String());
    await p.setString('${_k}phone', _phone.text);
    await p.setString('${_k}email', _email.text);
    await p.setString('${_k}server', _server);
    await p.setString('${_k}accountType', _accountType);
    await p.setString('${_k}leverage', _leverage);
    await p.setInt('${_k}deposit', _deposit);
    await p.setBool('${_k}hedge', _hedge);
  }

  /// Account bante hi server se aayi ID / password phone me save
  /// ho jati hai (list me, taaki saare created accounts mil jayein),
  /// aur yehi account "active" (logged-in) bhi ho jata hai - Accounts
  /// screen me iski card dikhti hai.
  Future<void> _saveCreatedAccount(
    Map<String, dynamic> result,
    String email,
  ) async {
    final p = await SharedPreferences.getInstance();
    final account = <String, dynamic>{
      'login_id': result['login_id'],
      'client_id': result['client_id'] ?? email,
      'email': email,
      'password': result['password'],
      'investor_password': result['investor_password'],
      'server': result['server'],
      'first_name': result['first_name'] ?? _first.text.trim(),
      'second_name': result['second_name'] ?? _second.text.trim(),
      'account_type': result['account_type'] ?? _accountType,
      'hedge': result['hedge'] ?? _hedge,
      'deposit': result['deposit'],
      'balance': result['balance'] ?? result['deposit'],
      'currency': result['currency'],
      'created_at': DateTime.now().toIso8601String(),
    };
    final list = p.getStringList('mq_created_accounts') ?? <String>[];
    list.add(jsonEncode(account));
    await p.setStringList('mq_created_accounts', list);
    // Active (logged-in) account app-wide.
    await tradingService.setMqAccount(account);
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _dob.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Opens the MT5-style wheel date picker dialog (see
  /// [_DobWheelDialog]) and applies the picked date.
  Future<void> _pickDob() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _DobWheelDialog(initial: _dobDate),
    );
    if (picked != null) {
      setState(() {
        _dobDate = picked;
        _dob.text = _formatDob(picked);
      });
      _persist();
    }
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _firstError = _first.text.trim().length < 2 ? 'Specify name' : null;
      _secondError = _second.text.trim().length < 2 ? 'Specify name' : null;
      _phoneError = digits.length < 11 ? 'Phone number is too short' : null;
      _emailError = (!email.contains('@') || !email.contains('.'))
          ? 'Specify email address'
          : null;
      _acceptError = !_accept;
    });
    if (_firstError != null ||
        _secondError != null ||
        _phoneError != null ||
        _emailError != null ||
        _acceptError) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await tradingService.registerMetaQuotesDemo({
        'first_name': _first.text.trim(),
        'second_name': _second.text.trim(),
        'date_of_birth': _dob.text.trim(),
        'phone': _phone.text.trim(),
        'email': email,
        'server': _server,
        'account_type': _accountType,
        'leverage': _leverage,
        'hedge': _hedge,
        'deposit': _deposit,
        'currency': 'USD',
      });
      if (!mounted) return;
      await _saveCreatedAccount(result, email);
      // Usi ID / password se foran login bhi kar do (server par
      // verify + last_login update); fail ho to bhi local active
      // account pehle hi set ho chuka hai.
      try {
        await tradingService.loginMetaQuotesDemo(
          type: 'CLIENT_ID',
          identifier: email,
          password: '${result['password']}',
        );
      } catch (_) {}
      if (!mounted) return;
      // MT5-style success screen with Login / Password / Investor.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AccountCreatedPage(
            firstName: _first.text.trim(),
            secondName: _second.text.trim(),
            accountType: _accountType,
            deposit: _deposit,
            loginId: '${result['login_id']}',
            password: '${result['password']}',
            investorPassword: '${result['investor_password'] ?? ''}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) _snack('$e');
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
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: MqPageHeader(
                title: 'Open a demo account',
                subtitle: 'Personal information',
                titleWeight: FontWeight.w500,
                titleFontSize: 16,
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Broker row form ke saath scroll hoti hai
                  // (fixed nahi hai).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/icons/mt5_logo.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MetaQuotes-Demo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: MtColors.text,
                              ),
                            ),
                            Text(
                              'MetaQuotes Ltd.',
                              style: TextStyle(
                                fontSize: 14,
                                color: MtColors.text,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const MqSectionHeader('PERSONAL INFORMATION'),
                  MqFieldRow(
                    label: 'First name',
                    controller: _first,
                    hint: 'min 2 chars',
                    errorText: _firstError,
                    onChanged: (_) {
                      if (_firstError != null) {
                        setState(() => _firstError = null);
                      }
                      _persist();
                    },
                  ),
                  MqFieldRow(
                    label: 'Second name',
                    controller: _second,
                    hint: 'min 2 chars',
                    errorText: _secondError,
                    onChanged: (_) {
                      if (_secondError != null) {
                        setState(() => _secondError = null);
                      }
                      _persist();
                    },
                  ),
                  MqFieldRow(
                    label: 'Date of birth',
                    controller: _dob,
                    readOnly: true,
                    onTap: _pickDob,
                  ),
                  MqFieldRow(
                    label: 'Phone',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    hint: '+12345678912',
                    errorText: _phoneError,
                    onChanged: (v) {
                      if (_phoneError != null) {
                        setState(() => _phoneError = null);
                      }
                      // Type karte hi number ke pehle +91 apne
                      // aap aa jata hai.
                      if (!v.startsWith('+91')) {
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        final text = '+91 $digits';
                        _phone.value = TextEditingValue(
                          text: text,
                          selection: TextSelection.collapsed(
                            offset: text.length,
                          ),
                        );
                      }
                      _persist();
                    },
                  ),
                  MqFieldRow(
                    label: 'E-Mail',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'name@company.com',
                    errorText: _emailError,
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                      _persist();
                    },
                  ),
                  const MqSectionHeader('ACCOUNT INFORMATION'),
                  MqCheckboxRow(
                    label: 'Use hedge in trading',
                    value: _hedge,
                    onChanged: (v) {
                      setState(() => _hedge = v);
                      _persist();
                    },
                  ),
                  Builder(
                    builder: (rowCtx) => MqDropdownRow(
                      label: 'Server',
                      value: _server,
                      onTap: () async {
                        final v = await showMqMenu(rowCtx, const [
                          'MetaQuotes-Demo',
                        ]);
                        if (v != null) {
                          setState(() => _server = v);
                          _persist();
                        }
                      },
                    ),
                  ),
                  Builder(
                    builder: (rowCtx) => MqDropdownRow(
                      label: 'Account type',
                      value: _accountType,
                      onTap: () async {
                        final v = await showMqMenu(rowCtx, const [
                          'Forex Hedged USD',
                          'Forex Hedged EUR',
                          'Forex Netting USD',
                        ]);
                        if (v != null) {
                          setState(() => _accountType = v);
                          _persist();
                        }
                      },
                    ),
                  ),
                  Builder(
                    builder: (rowCtx) => MqDropdownRow(
                      label: 'Leverage',
                      value: _leverage,
                      onTap: () async {
                        final v = await showMqMenu(rowCtx, const [
                          '1:10',
                          '1:50',
                          '1:100',
                          '1:200',
                          '1:500',
                          '1:1000',
                        ]);
                        if (v != null) {
                          setState(() => _leverage = v);
                          _persist();
                        }
                      },
                    ),
                  ),
                  Builder(
                    builder: (rowCtx) => MqDropdownRow(
                      label: 'Deposit',
                      value: '$_deposit USD',
                      boldValue: true,
                      onTap: () async {
                        final v = await showMqMenu(rowCtx, [
                          for (final d in _depositValues) '$d',
                        ]);
                        if (v != null) {
                          setState(() => _deposit = int.parse(v));
                          _persist();
                        }
                      },
                    ),
                  ),
                  const MqSectionHeader('AGREEMENTS'),
                  MqCheckboxRow(
                    label: 'Accept',
                    value: _accept,
                    showErrorIcon: _acceptError,
                    onChanged: (v) => setState(() {
                      _accept = v;
                      if (v) _acceptError = false;
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Text(
                      'By enabling "Accept" you agree with the terms and conditions for opening an account and the data protection policy',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: MtColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Fixed at the bottom (above the system navigation),
            // does not scroll with the form.
            MqPrimaryButton(label: 'REGISTER', busy: _busy, onTap: _register),
          ],
        ),
      ),
    );
  }
}

/// MT5-style date-of-birth picker: white rounded dialog with three
/// flat wheels (Month / Day / Year). The selected row sits between
/// two dark lines in each column; neighbours are gray. Cancel / OK
/// at the bottom right. Returns the picked date (or null).
class _DobWheelDialog extends StatefulWidget {
  const _DobWheelDialog({required this.initial});

  final DateTime initial;

  @override
  State<_DobWheelDialog> createState() => _DobWheelDialogState();
}

class _DobWheelDialogState extends State<_DobWheelDialog> {
  static const _minYear = 1930;
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const double _itemExtent = 60;
  static const double _wheelHeight = 180; // exactly 3 rows visible

  late int _month; // 1..12
  late int _day; // 1..31
  late int _year;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _yearCtrl;

  int get _maxYear => DateTime.now().year;
  int get _daysInMonth => DateUtils.getDaysInMonth(_year, _month);

  @override
  void initState() {
    super.initState();
    _month = widget.initial.month;
    _day = widget.initial.day;
    _year = widget.initial.year;
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _yearCtrl = FixedExtentScrollController(initialItem: _year - _minYear);
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _clampDay() {
    final dim = _daysInMonth;
    if (_day > dim) {
      _day = dim;
      if (_dayCtrl.hasClients) _dayCtrl.jumpToItem(_day - 1);
    }
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedIndex,
    required String Function(int index) text,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      height: _wheelHeight,
      child: Stack(
        children: [
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: _itemExtent,
            diameterRatio: 8,
            perspective: 0.001,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, i) => Center(
                child: Text(
                  text(i),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: i == selectedIndex
                        ? MtColors.text
                        : MtColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          // Dark lines above and below the selected (middle) row.
          const Positioned(
            left: 6,
            right: 6,
            top: _itemExtent,
            height: _itemExtent,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF757575), width: 1.6),
                    bottom: BorderSide(color: Color(0xFF757575), width: 1.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MtColors.white,
      insetPadding: const EdgeInsets.fromLTRB(12, 58, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 44, 48, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Date of birth',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: MtColors.text,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _wheel(
                    controller: _monthCtrl,
                    itemCount: 12,
                    selectedIndex: _month - 1,
                    text: (i) => _months[i],
                    onChanged: (i) => setState(() {
                      _month = i + 1;
                      _clampDay();
                    }),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: _wheel(
                    controller: _dayCtrl,
                    itemCount: _daysInMonth,
                    selectedIndex: _day - 1,
                    text: (i) => '${i + 1}'.padLeft(2, '0'),
                    onChanged: (i) => setState(() => _day = i + 1),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: _wheel(
                    controller: _yearCtrl,
                    itemCount: _maxYear - _minYear + 1,
                    selectedIndex: _year - _minYear,
                    text: (i) => '${_minYear + i}',
                    onChanged: (i) => setState(() {
                      _year = _minYear + i;
                      _clampDay();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: mqBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(DateTime(_year, _month, _day)),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: mqBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
