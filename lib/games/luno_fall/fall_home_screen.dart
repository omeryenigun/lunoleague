import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/games/luno_fall/fall_copy.dart';
import 'package:kelimelig/games/luno_fall/fall_rules.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';
import 'package:kelimelig/injection.dart';

class FallHomeScreen extends StatefulWidget {
  const FallHomeScreen({super.key});

  @override
  State<FallHomeScreen> createState() => _FallHomeScreenState();
}

class _FallHomeScreenState extends State<FallHomeScreen> {
  FallProfile? _profile;
  var _banner = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final server = sl<LunoFallServer>();
    final profile = await server.profile();
    final banner = await server.noteBannerShown();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _banner = banner;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)));
    }
    final lang = profile.locale;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        const Text(
          'LUNO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Color(0xFF2ECC71),
          ),
        ),
        const Text(
          'FALL',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
            color: Color(0xFFF1C40F),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          fallText(lang, 'slogan'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(profile.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${profile.coins}', style: const TextStyle(color: Color(0xFFF1C40F), fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'tr', label: Text('TR')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {lang},
              onSelectionChanged: (next) async {
                await sl<LunoFallServer>().setLocale(next.first);
                await _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${FallRules.tierLabel(profile.tier, lang)} · ${fallText(lang, 'no_midgame_ad')}',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        const SizedBox(height: 18),
        Text(fallText(lang, 'pick'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final diff in FallDifficulty.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF1E293B)),
              ),
              tileColor: const Color(0xFF111827),
              title: Text(fallText(lang, diff.name)),
              subtitle: Text(_blurb(diff, lang)),
              trailing: const Icon(Icons.play_arrow, color: Color(0xFF2ECC71)),
              onTap: () => context.push('/fall/play?d=${diff.name}'),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: FallRules.coinAdAllowed(claimedToday: profile.rewardToday)
              ? () async {
                  await sl<LunoFallServer>().claimCoinAd();
                  await _load();
                }
              : null,
          child: Text(
            FallRules.coinAdAllowed(claimedToday: profile.rewardToday)
                ? fallText(lang, 'ad_coin')
                : fallText(lang, 'ad_coin_done'),
          ),
        ),
        if (_banner) ...[
          const SizedBox(height: 12),
          Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              fallText(lang, 'banner'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ],
    );
  }

  String _blurb(FallDifficulty diff, String lang) {
    final rule = FallRules.difficulty[diff]!;
    if (lang == 'en') {
      return '${rule.minLetters}-${rule.maxLetters} letters · ${rule.seconds}s · ${rule.lives} lives';
    }
    return '${rule.minLetters}-${rule.maxLetters} harf · ${rule.seconds} sn · ${rule.lives} can';
  }
}
