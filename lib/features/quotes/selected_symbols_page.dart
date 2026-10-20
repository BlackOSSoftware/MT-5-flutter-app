import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import 'quote_data.dart';

const _descriptions = <String, String>{
  'EURUSD': 'Euro vs US Dollar',
  'GBPUSD': 'Pound Sterling vs US Dollar',
  'USDCHF': 'US Dollar vs Swiss Franc',
  'USDJPY': 'US Dollar vs Yen',
  'USDCNH': 'US Dollar vs Chinese Yuan',
  'USDRUB': 'US Dollar vs Russian Ruble',
  'AUDUSD': 'Australian Dollar vs US Dollar',
  'NZDUSD': 'New Zealand Dollar vs US Dollar',
  'USDCAD': 'US Dollar vs Canadian Dollar',
  'USDSEK': 'US Dollar vs Swedish Krona',
};

class SelectedSymbolsPage extends StatefulWidget {
  const SelectedSymbolsPage({super.key});

  @override
  State<SelectedSymbolsPage> createState() => _SelectedSymbolsPageState();
}

class _SelectedSymbolsPageState extends State<SelectedSymbolsPage> {
  bool _deleteMode = false;
  final Set<String> _checked = {};
  List<WatchSymbol> _items = const [];

  // Order-save calls ek ke peeche ek (queue me) chalte hain,
  // warna tez drag par purana save baad me aakar order bigaad deta tha.
  Future<void> _saveChain = Future.value();

  @override
  void initState() {
    super.initState();
    _sync();
    tradingService.addListener(_sync);
  }

  @override
  void dispose() {
    tradingService.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final fresh = tradingService.watchlist.isNotEmpty
        ? List.of(tradingService.watchlist)
        : [
            for (final q in quotes)
              WatchSymbol(code: q.symbol, name: _descriptions[q.symbol] ?? ''),
          ];
    setState(() {
      if (_items.isEmpty) {
        _items = fresh;
      } else {
        // Local (drag ki hui) order hi rakho - peeche se refresh
        // aane par list purani order se overwrite nahi hogi
        // (warna item ek baar wapas upar uchhalta tha). Sirf
        // naye symbols aakhir me judenge, hate hue nikal jayenge.
        final freshByCode = {for (final w in fresh) w.code: w};
        final kept = <WatchSymbol>[
          for (final w in _items)
            if (freshByCode[w.code] != null) freshByCode[w.code]!,
        ];
        final keptCodes = kept.map((w) => w.code).toSet();
        _items = [
          ...kept,
          for (final w in fresh)
            if (!keptCodes.contains(w.code)) w,
        ];
      }
      // Jo symbols ab list me nahi, unke tick hata do.
      _checked.removeWhere((c) => !_items.any((w) => w.code == c));
    });
  }

  Future<void> _deleteChecked() async {
    if (_checked.isEmpty) return;
    final codes = List.of(_checked);
    try {
      for (final code in codes) {
        await tradingService.removeWatchlist(code);
      }
      if (!mounted) return;
      setState(() {
        _checked.clear();
        _deleteMode = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _name(WatchSymbol w) {
    if (w.name.isNotEmpty && w.name.toUpperCase() != w.code) return w.name;
    return _descriptions[w.code] ?? w.name;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Delete mode me back dabane se page band nahi hota,
      // pehle selection mode band hota hai (MT5 ki tarah).
      canPop: !_deleteMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _deleteMode) {
          setState(() {
            _deleteMode = false;
            _checked.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: MtColors.white,
        appBar: AppBar(
          backgroundColor: MtColors.white,
          foregroundColor: MtColors.text,
          elevation: 0,
          automaticallyImplyLeading: !_deleteMode,
          titleSpacing: 0,
          title: _deleteMode
              // Delete mode header: blue check + selected count.
              ? Row(
                  children: [
                    const Icon(Icons.check, size: 28, color: Color(0xFF2F66C4)),
                    const SizedBox(width: 10),
                    Text(
                      '${_checked.length}',
                      style: TextStyle(fontSize: 16, color: MtColors.text),
                    ),
                  ],
                )
              : const Text('Selected symbols', style: TextStyle(fontSize: 16)),
          actions: [
            if (!_deleteMode)
              IconButton(
                tooltip: 'Add',
                icon: Icon(Icons.add, size: 28, color: MtColors.iconDark),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AddSymbolsPage(),
                    ),
                  );
                },
              ),
            if (_deleteMode)
              IconButton(
                tooltip: 'Select all',
                icon: Image.asset(
                  'assets/icons/select_all_checks.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
                onPressed: () => setState(() {
                  if (_checked.length == _items.length) {
                    _checked.clear();
                  } else {
                    _checked.addAll(_items.map((w) => w.code));
                  }
                }),
              ),
            IconButton(
              // Pehli baar dabane par checkbox mode, mode me
              // dabane par tick wale symbols delete.
              tooltip: _deleteMode ? 'Delete selected' : 'Delete',
              icon: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  _deleteMode ? const Color(0xFF2F66C4) : MtColors.iconDark,
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/icons/trash_bin.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              ),
              onPressed: _deleteMode
                  ? _deleteChecked
                  : () => setState(() => _deleteMode = true),
            ),
          ],
        ),
        body: ReorderableListView.builder(
          // Default long-press drag band - sirf 4-line icon ko
          // pakadte hi (bina hold) drag shuru hoga.
          buildDefaultDragHandles: false,
          // Drag karte waqt utha hua shadow/elevation effect nahi.
          proxyDecorator: (child, index, animation) =>
              Material(elevation: 0, color: Colors.transparent, child: child),
          itemCount: _items.length,
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              final item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
            });
            // Nayi position backend par save karo, warna page
            // dobara khulte hi purani order wapas aa jati thi.
            final codes = [for (final w in _items) w.code];
            final messenger = ScaffoldMessenger.of(context);
            _saveChain = _saveChain.then((_) async {
              try {
                await tradingService.reorderWatchlist(codes);
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Order save nahi ho payi')),
                );
              }
            });
            unawaited(_saveChain);
          },
          itemBuilder: (context, i) {
            final w = _items[i];
            return Column(
              key: ValueKey(w.code),
              children: [
                InkWell(
                  // Delete mode me poori row dabane se tick lage/hate.
                  onTap: _deleteMode
                      ? () => setState(() {
                          if (!_checked.add(w.code)) _checked.remove(w.code);
                        })
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.code,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: MtColors.text,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _name(w),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: MtColors.icon,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_deleteMode)
                          Checkbox(
                            value: _checked.contains(w.code),
                            activeColor: const Color(0xFF2F66C4),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _checked.add(w.code);
                              } else {
                                _checked.remove(w.code);
                              }
                            }),
                          )
                        else
                          // 4-line icon ko pakad (grab) karke row ko
                          // upar-neeche drag karke order badlo.
                          ReorderableDragStartListener(
                            index: i,
                            // Solid (transparent rang ka) bada grab
                            // area - ungli kahin bhi pade, drag miss
                            // nahi hoga (sirf icon par nahi).
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                14,
                                16,
                                14,
                              ),
                              color: Colors.transparent,
                              child: ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  MtColors.icon,
                                  BlendMode.srcIn,
                                ),
                                child: Image.asset(
                                  'assets/icons/drag_bars.png',
                                  width: 16,
                                  height: 16,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: MtColors.line,
                  indent: 16,
                  endIndent: 16,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AddSymbolsPage extends StatefulWidget {
  const AddSymbolsPage({super.key});

  @override
  State<AddSymbolsPage> createState() => _AddSymbolsPageState();
}

class _AddSymbolsPageState extends State<AddSymbolsPage> {
  final _ctrl = TextEditingController();
  List<SymbolSegment> _segments = const [];
  List<WatchSymbol> _symbols = const []; // khule hue folder ke symbols
  List<WatchSymbol> _results = const []; // search results
  SymbolSegment? _folder;
  String _query = '';
  bool _busy = true;
  Timer? _debounce;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _loadSegments();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  static String _folderName(String segment) {
    return switch (segment.toUpperCase()) {
      'FOREX' => 'Forex',
      'METAL' || 'METALS' => 'Metals',
      'INDEX' || 'INDICES' || 'INDEXES' => 'Indexes',
      'STOCK' => 'Stock',
      'NASDAQ' => 'Nasdaq',
      'ETF' => 'ETF',
      'WARRANT' => 'Warrant',
      'CRYPTO' => 'Crypto',
      'ENERGY' => 'Energy',
      'COMMODITY' || 'COMMODITIES' => 'Commodities',
      'OTHER' => 'Other',
      _ =>
        segment.isEmpty
            ? 'Other'
            : segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
    };
  }

  static int _folderRank(String segment) {
    return switch (segment.toUpperCase()) {
      'FOREX' => 0,
      'INDEX' || 'INDICES' || 'INDEXES' => 1,
      'METAL' || 'METALS' => 2,
      'ENERGY' => 3,
      'COMMODITY' || 'COMMODITIES' => 4,
      'STOCK' => 5,
      'NASDAQ' => 6,
      'ETF' => 7,
      'CRYPTO' => 8,
      _ => 20,
    };
  }

  Future<void> _loadSegments() async {
    final seq = ++_seq;
    setState(() => _busy = true);
    try {
      final r = await tradingService.symbolSegments();
      if (!mounted || seq != _seq) return;
      final sorted = List.of(r)
        ..sort(
          (a, b) => _folderRank(a.segment).compareTo(_folderRank(b.segment)),
        );
      setState(() => _segments = sorted);
    } catch (_) {
      if (mounted && seq == _seq) setState(() => _segments = const []);
    } finally {
      if (mounted && seq == _seq) setState(() => _busy = false);
    }
  }

  Future<void> _openFolder(SymbolSegment seg) async {
    final seq = ++_seq;
    setState(() {
      _folder = seg;
      _symbols = const [];
      _busy = true;
    });
    try {
      final r = await tradingService.segmentInstruments(seg.segment);
      if (!mounted || seq != _seq) return;
      final sorted = List.of(r)..sort((a, b) => a.code.compareTo(b.code));
      setState(() => _symbols = sorted);
    } catch (_) {
      if (mounted && seq == _seq) setState(() => _symbols = const []);
    } finally {
      if (mounted && seq == _seq) setState(() => _busy = false);
    }
  }

  void _onQuery(String v) {
    setState(() => _query = v.trim());
    _debounce?.cancel();
    if (_query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    final seq = ++_seq;
    setState(() => _busy = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await tradingService.searchInstruments(_query);
        if (!mounted || seq != _seq) return;
        final sorted = List.of(r)..sort((a, b) => a.code.compareTo(b.code));
        setState(() => _results = sorted);
      } catch (_) {
        if (mounted && seq == _seq) setState(() => _results = const []);
      } finally {
        if (mounted && seq == _seq) setState(() => _busy = false);
      }
    });
  }

  // Optimistic flips ka local record - watchlist refresh
  // hone tak yahi sach mana jata hai (flicker nahi hota).
  final _forced = <String, bool>{};

  bool _isAdded(WatchSymbol w) {
    final f = _forced[w.code];
    if (f != null) return f;
    if (w.isAdded) return true;
    return tradingService.watchlist.any((x) => x.code == w.code);
  }

  /// Local lists me symbol ka added status turant badlo
  /// (API ka wait kiye bina - smooth lagta hai).
  void _flipLocal(WatchSymbol w, bool toAdded) {
    _forced[w.code] = toAdded;
    setState(() {
      WatchSymbol flip(WatchSymbol x) => x.code == w.code
          ? WatchSymbol(
              code: x.code,
              name: x.name,
              segment: x.segment,
              isAdded: toAdded,
            )
          : x;
      _symbols = [for (final x in _symbols) flip(x)];
      _results = [for (final x in _results) flip(x)];
      final f = _folder;
      if (f != null) {
        _folder = SymbolSegment(
          segment: f.segment,
          total: f.total,
          added: f.added + (toAdded ? 1 : -1),
        );
      }
    });
  }

  Future<void> _toggle(WatchSymbol w, bool added) async {
    // Pehle UI turant flip (optimistic) - add/remove smooth
    // lagega, API peeche background me chalegi.
    _flipLocal(w, !added);
    try {
      if (added) {
        await tradingService.removeWatchlist(w.code);
      } else {
        await tradingService.addWatchlist(w.code, w.name);
        tradingService.subscribe(w.code);
      }
      unawaited(tradingService.refreshWatchlist());
    } catch (e) {
      // API fail ho to UI wapas purani state par.
      if (!mounted) return;
      _flipLocal(w, added);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _goHome() {
    setState(() {
      _folder = null;
      _symbols = const [];
    });
    _loadSegments();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    return Scaffold(
      backgroundColor: MtColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header: back + "Add symbol".
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () {
                      if (_folder != null && !searching) {
                        _goHome();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back,
                      size: 24,
                      color: MtColors.text,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Add symbol',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: MtColors.text,
                    ),
                  ),
                ],
              ),
            ),
            // Search row.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
              child: Row(
                children: [
                  Icon(Icons.search, size: 24, color: MtColors.icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onChanged: _onQuery,
                      style: TextStyle(fontSize: 16, color: MtColors.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Find symbols',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: MtColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  if (searching)
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _ctrl.clear();
                        _onQuery('');
                      },
                      icon: Icon(Icons.close, size: 22, color: MtColors.icon),
                    ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: MtColors.line),
            // Breadcrumb: home > Folder.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: _goHome,
                    child: Image.asset(
                      'assets/icons/home_gray.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (_folder != null && !searching) ...[
                    Icon(Icons.chevron_right, size: 18, color: MtColors.icon),
                    const SizedBox(width: 4),
                    Text(
                      _folderName(_folder!.segment),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF2F66C4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: _body(searching)),
          ],
        ),
      ),
    );
  }

  Widget _body(bool searching) {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (searching) {
      if (_results.isEmpty) return _empty('No symbols found');
      return ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, i) => _symbolRow(_results[i], searchMode: true),
      );
    }
    if (_folder != null) {
      if (_symbols.isEmpty) return _empty('No symbols in this folder');
      return ListView.builder(
        itemCount: _symbols.length,
        itemBuilder: (context, i) => _symbolRow(_symbols[i], searchMode: false),
      );
    }
    if (_segments.isEmpty) return _empty('No symbols available');
    return ListView.builder(
      itemCount: _segments.length,
      itemBuilder: (context, i) {
        final s = _segments[i];
        return InkWell(
          onTap: () => _openFolder(s),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Image.asset(
                  'assets/icons/folder_gold.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _folderName(s.segment),
                    style: TextStyle(fontSize: 16, color: MtColors.text),
                  ),
                ),
                Text(
                  '${s.added}/${s.total}',
                  style: TextStyle(fontSize: 13, color: MtColors.icon),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Symbol code - search mode me sirf utna hissa blue hota
  /// hai jitna search se match ho, baaki hissa kaala rehta hai.
  Widget _codeText(WatchSymbol w, {required bool searchMode}) {
    const blue = Color(0xFF2F66C4);
    final base = TextStyle(fontSize: 16, color: MtColors.text);
    if (!searchMode || _query.isEmpty) {
      return Text(w.code, style: base);
    }
    final idx = w.code.toUpperCase().indexOf(_query.toUpperCase());
    if (idx < 0) return Text(w.code, style: base);
    final end = idx + _query.length;
    return Text.rich(
      TextSpan(
        children: [
          if (idx > 0) TextSpan(text: w.code.substring(0, idx)),
          TextSpan(
            text: w.code.substring(idx, end),
            style: const TextStyle(color: blue),
          ),
          if (end < w.code.length) TextSpan(text: w.code.substring(end)),
        ],
      ),
      style: base,
    );
  }

  Widget _symbolRow(WatchSymbol w, {required bool searchMode}) {
    final added = _isAdded(w);
    // Poori row (card) par tap + ripple effect - kahin bhi
    // dabane se add/remove hoga, sirf + button par nahi.
    return InkWell(
      onTap: () => _toggle(w, added),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _codeText(w, searchMode: searchMode),
                  const SizedBox(height: 1),
                  Text(
                    w.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: MtColors.icon),
                  ),
                ],
              ),
            ),
            // Icon sirf dikhane ke liye - tap poori row par hai.
            // Add/remove hone par icon halka sa pop (bounce) hota hai.
            IgnorePointer(
              child: _PopIcon(
                key: ValueKey(w.code),
                added: added,
                child: added
                    ? const Icon(
                        Icons.check_circle,
                        size: 24,
                        color: Color(0xFF2F66C4),
                      )
                    // Halka (light) plus: patli border wala chhota
                    // circle, beech me chhota sa +.
                    : Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF2F66C4),
                            width: 1.4,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 13,
                          color: Color(0xFF2F66C4),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String msg) {
    return Center(
      child: Text(
        msg,
        style: TextStyle(fontSize: 15, color: MtColors.textSecondary),
      ),
    );
  }
}

/// Add/remove icon ka pop effect - status badalte hi icon
/// 1.45x se bounce karke wapas normal ho jata hai.
class _PopIcon extends StatefulWidget {
  const _PopIcon({super.key, required this.added, required this.child});

  final bool added;
  final Widget child;

  @override
  State<_PopIcon> createState() => _PopIconState();
}

class _PopIconState extends State<_PopIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    _scale = Tween<double>(
      begin: 1.45,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(covariant _PopIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.added != widget.added) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
