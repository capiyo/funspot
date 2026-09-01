import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../utils/add_helper.dart';

// Module-level counter — guarantees every mounted ad card gets a unique
// view type, even when the round-robin repeats a slot ID (feed > 15 posts).
// AdSense needs one distinct <ins> element per impression.
int _webAdInstanceCounter = 0;

class WebNativeAdCard extends StatefulWidget {
  /// Position of this ad slot in the feed (0-based: 1st ad = 0, 2nd = 1...).
  /// Wrapped against AdHelper.adSenseInFeedSlotIds.length internally.
  final int slotIndex;

  const WebNativeAdCard({super.key, required this.slotIndex});

  @override
  State<WebNativeAdCard> createState() => _WebNativeAdCardState();
}


class _WebNativeAdCardState extends State<WebNativeAdCard> {
  late final String _viewType;
  late final String _slotId;
  bool _pushed = false;
  bool _checkedFill = false;
  bool _isFilled = false;
  web.HTMLElement? _insElement;

  @override
  void initState() {
    super.initState();
    assert(kIsWeb, 'WebNativeAdCard must only be mounted when kIsWeb is true.');

    final slots = AdHelper.adSenseInFeedSlotIds;
    _slotId = slots[widget.slotIndex % slots.length];

    _webAdInstanceCounter++;
    _viewType = 'adsense-infeed-${_slotId}_$_webAdInstanceCounter';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container = web.document.createElement('div') as web.HTMLDivElement
        ..style.width = '100%'
        ..style.minHeight = '100px';

      final ins = web.document.createElement('ins') as web.HTMLElement
        ..className = 'adsbygoogle'
        ..style.display = 'block';
      ins.setAttribute('data-ad-format', 'fluid');
      ins.setAttribute('data-ad-layout-key', AdHelper.adSenseInFeedLayoutKey);
      ins.setAttribute('data-ad-client', AdHelper.adSenseClientId);
      ins.setAttribute('data-ad-slot', _slotId);

      _insElement = ins; // ✅ keep a reference so we can poll it later
      container.append(ins);
      return container;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _pushAd());
  }

  void _pushAd() {
    if (_pushed || !mounted) return;
    _pushed = true;
    try {
      final win = web.window as JSObject;
      if (win['adsbygoogle'] == null) {
        win['adsbygoogle'] = JSArray();
      }
      final adsbygoogle = win['adsbygoogle'] as JSObject;
      adsbygoogle.callMethod('push'.toJS, JSObject());

      // ✅ AdSense sets data-ad-status async, usually within ~1s. Poll a
      // few times before giving up and treating it as unfilled — avoids
      // both a too-early false negative and hanging forever if it never
      // resolves (e.g. adblock intercepted the fill call silently).
      _pollFillStatus(attempt: 0);
    } catch (e) {
      debugPrint('❌ AdSense push failed for slot $_slotId: $e');
      if (mounted) setState(() => _checkedFill = true); // treat as unfilled
    }
  }

  void _pollFillStatus({required int attempt}) {
    const maxAttempts = 10;
    const interval = Duration(milliseconds: 300);

    Future.delayed(interval, () {
      if (!mounted) return;
      final status = _insElement?.getAttribute('data-ad-status');

      if (status == 'filled') {
        setState(() {
          _isFilled = true;
          _checkedFill = true;
        });
        return;
      }
      if (status == 'unfilled' || attempt >= maxAttempts) {
        setState(() {
          _isFilled = false;
          _checkedFill = true;
        });
        return;
      }
      _pollFillStatus(attempt: attempt + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show yet, or confirmed no fill — collapse to zero height
    // instead of reserving blank space.
    if (!_checkedFill || !_isFilled) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: Container(
        key: ValueKey(_viewType),
        constraints: const BoxConstraints(minHeight: 100, maxHeight: 400),
        margin: const EdgeInsets.only(bottom: 1),
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
