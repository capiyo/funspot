import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdWidget extends StatefulWidget {
  final String adUnitId;
  final double height;

  const NativeAdWidget({super.key, required this.adUnitId, this.height = 350});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      factoryId: 'defaultNative', // ✅ CORRECT: Matches your registered factory
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          print('✅ Native ad loaded successfully');
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Native ad failed to load: $error');
          ad.dispose();
          // Retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), _loadNativeAd);
        },
        onAdClicked: (ad) => print('Ad clicked'),
        onAdImpression: (ad) => print('Ad impression recorded'),
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded) {
      return _buildAdPlaceholder();
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: AdWidget(ad: _nativeAd!),
    );
  }

  Widget _buildAdPlaceholder() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ads_click, size: 50, color: Colors.green[300]),
          const SizedBox(height: 10),
          Text(
            'Ad Loading...',
            style: TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const CircularProgressIndicator(color: Colors.green),
        ],
      ),
    );
  }
}
