import 'package:flutter/foundation.dart';

class AdHelper {
  static const String productionNativeAdUnitId =
      'ca-app-pub-8671302794311438/1354354005';

  static const String productionCarouselAdUnitId1 =
      'ca-app-pub-8671302794311438/3524169425';
  static const String productionCarouselAdUnitId2 =
      'ca-app-pub-8671302794311438/4130674080';
  static const String productionCarouselAdUnitId3 =
      'ca-app-pub-8671302794311438/1504510743';

  // Google's official test ad unit IDs (different IDs per slot)
  static const String _testNativeAdUnitId1 =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _testNativeAdUnitId2 =
      'ca-app-pub-3940256099942544/1044960115';
  static const String _testNativeAdUnitId3 =
      'ca-app-pub-3940256099942544/2247696110';

  // Rely solely on kDebugMode — Platform.environment doesn't
  // expose Android system properties so isEmulator was always false
  static String get postsFeedNativeAdUnitId {
    if (kDebugMode) return _testNativeAdUnitId1;
    return productionNativeAdUnitId;
  }

  static String get carouselAdUnitId1 {
    if (kDebugMode) return _testNativeAdUnitId1;
    return productionCarouselAdUnitId1;
  }

  static String get carouselAdUnitId2 {
    if (kDebugMode) return _testNativeAdUnitId2;
    return productionCarouselAdUnitId2;
  }

  static String get carouselAdUnitId3 {
    if (kDebugMode) return _testNativeAdUnitId3;
    return productionCarouselAdUnitId3;
  }

  static List<String> get carouselAdUnitIds {
    return [carouselAdUnitId1, carouselAdUnitId2, carouselAdUnitId3];
  }
}
