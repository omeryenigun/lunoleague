const admobAppId = 'ca-app-pub-9773173651120365~3784384609';
const admobRewardedUnitId = 'ca-app-pub-9773173651120365/5748202969';

/// Google's sample rewarded unit. Debug builds use this. Android games other
/// than Luno League also use it until they have their own unit.
const admobTestRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

/// Google's sample rewarded interstitial unit (debug / fallback).
const admobTestRewardedInterstitialUnitId =
    'ca-app-pub-3940256099942544/5353538341';

/// Luno Bilgi Android rewarded interstitial unit.
const admobBilgiRewardedInterstitialUnitId =
    'ca-app-pub-9773173651120365/1299785518';

/// Android Luno League keeps the published AdMob units. Other Android games do not.
bool androidUsesLeagueAds = true;

/// When true, AdService loads rewarded interstitial instead of rewarded video.
bool androidUsesRewardedInterstitial = false;

/// Release rewarded / rewarded-interstitial unit for an Android game that is
/// not Luno League.
String? androidRewardedUnitId;
