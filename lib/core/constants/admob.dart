const admobAppId = 'ca-app-pub-9773173651120365~3784384609';
const admobRewardedUnitId = 'ca-app-pub-9773173651120365/5748202969';

/// Google's sample rewarded unit. Debug builds use this. Android games other
/// than Luno League also use it until they have their own unit.
const admobTestRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

const admobBilgiRewardedUnitId = 'ca-app-pub-2627324717388568/7033504096';

/// Android Luno League keeps the published AdMob units. Other Android games do not.
bool androidUsesLeagueAds = true;

/// Release rewarded unit for an Android game that is not Luno League.
String? androidRewardedUnitId;
