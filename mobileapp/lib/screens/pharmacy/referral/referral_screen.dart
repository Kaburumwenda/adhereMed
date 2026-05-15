import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../../../core/api.dart';
import '../../../widgets/common.dart';

final _refDashProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/usage-billing/referral/dashboard/');
  return res.data;
});

String _fmtCoins(dynamic v) {
  final n = double.tryParse('$v') ?? 0;
  if (n >= 1000) return NumberFormat.compact().format(n);
  return NumberFormat('#,##0.##').format(n);
}

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_refDashProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/images/adhere_coin.png', width: 28, height: 28),
          const SizedBox(width: 10),
          const Text('Referral Program'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Performance',
            onPressed: () => context.go('/referral/performance'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_refDashProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_refDashProvider),
        child: data.when(
          loading: () => const LoadingShimmer(),
          error: (e, _) => ErrorRetry(message: 'Failed to load referral data', onRetry: () => ref.invalidate(_refDashProvider)),
          data: (d) => _Body(d: d, cs: cs, isDark: isDark),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Map d;
  final ColorScheme cs;
  final bool isDark;
  const _Body({required this.d, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final profile = d['profile'] ?? {};
    final referrals = (d['referrals'] as List?) ?? [];
    final transactions = (d['transactions'] as List?) ?? [];
    final code = '${profile['referral_code'] ?? ''}';
    final link = '${d['referral_link'] ?? ''}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // ── Coin Balance Hero Card ──
        _CoinHeroCard(profile: profile, cs: cs, isDark: isDark).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
        const SizedBox(height: 16),

        // ── Referral Code & Share ──
        _ShareCard(code: code, link: link, cs: cs, isDark: isDark).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05),
        const SizedBox(height: 16),

        // ── How It Works ──
        _HowItWorksCard(cs: cs, isDark: isDark).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05),
        const SizedBox(height: 16),

        // ── Redeem Section ──
        _RedeemCard(cs: cs, isDark: isDark).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05),
        const SizedBox(height: 20),

        // ── Your Referrals ──
        _SectionHeader(icon: Icons.people_rounded, title: 'Your Referrals', count: referrals.length, color: cs.primary),
        const SizedBox(height: 8),
        if (referrals.isEmpty)
          _EmptyCard(icon: Icons.person_add_rounded, title: 'No referrals yet', subtitle: 'Share your code to start earning coins!')
        else
          ...referrals.map((r) => _ReferralTile(r: r, cs: cs)),
        const SizedBox(height: 20),

        // ── Transaction History ──
        _SectionHeader(icon: Icons.receipt_long_rounded, title: 'Transactions', count: transactions.length, color: cs.tertiary),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          _EmptyCard(icon: Icons.swap_horiz_rounded, title: 'No transactions yet', subtitle: 'Your coin activity will appear here.')
        else
          ...transactions.take(20).map((t) => _TransactionTile(t: t, cs: cs)),
      ],
    );
  }
}

// ────────────────────────────────────────────────────
// Coin Hero Card
// ────────────────────────────────────────────────────
class _CoinHeroCard extends StatelessWidget {
  final Map profile;
  final ColorScheme cs;
  final bool isDark;
  const _CoinHeroCard({required this.profile, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
          ),
        ),
        child: Stack(children: [
          Positioned(right: -30, top: -30, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)))),
          Positioned(left: -20, bottom: -20, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.amber.withValues(alpha: 0.15)),
                child: Image.asset('assets/images/adhere_coin.png', width: 48, height: 48),
              ),
              const SizedBox(height: 14),
              Text('Your Balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(_fmtCoins(profile['coin_balance']), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
              Text('Adhere Coins', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _HeroStat(value: _fmtCoins(profile['total_earned']), label: 'Earned', color: const Color(0xFF4ADE80)),
                  Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.15)),
                  _HeroStat(value: '${profile['referral_count'] ?? 0}', label: 'Referrals', color: const Color(0xFF60A5FA)),
                  Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.15)),
                  _HeroStat(value: _fmtCoins(profile['total_redeemed']), label: 'Redeemed', color: const Color(0xFFFBBF24)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeroStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
  ]);
}

// ────────────────────────────────────────────────────
// Share Card
// ────────────────────────────────────────────────────
class _ShareCard extends StatefulWidget {
  final String code, link;
  final ColorScheme cs;
  final bool isDark;
  const _ShareCard({required this.code, required this.link, required this.cs, required this.isDark});

  @override
  State<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<_ShareCard> {
  String _copied = '';

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = 'code');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!'), duration: Duration(seconds: 1)));
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copied = ''); });
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.link));
    setState(() => _copied = 'link');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!'), duration: Duration(seconds: 1)));
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copied = ''); });
  }

  void _shareNative() {
    share_plus.Share.share('Join AdhereMed using my referral code: ${widget.code}\n\n${widget.link}');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: widget.cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.link_rounded, color: widget.cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Invite & Earn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Share your unique code. Earn 100 coins per signup + 1 coin per 1,000 API requests.',
            style: TextStyle(fontSize: 12, color: widget.cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Text('REFERRAL CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.cs.onSurfaceVariant, letterSpacing: 1)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? widget.cs.surfaceContainerHighest : widget.cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(child: Text(widget.code, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, color: widget.cs.primary, fontFamily: 'monospace'))),
              IconButton(
                icon: Icon(_copied == 'code' ? Icons.check_rounded : Icons.copy_rounded, size: 20),
                onPressed: _copyCode,
                color: _copied == 'code' ? Colors.green : widget.cs.onSurfaceVariant,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Text('REFERRAL LINK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.cs.onSurfaceVariant, letterSpacing: 1)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isDark ? widget.cs.surfaceContainerHighest : widget.cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(child: Text(widget.link, style: TextStyle(fontSize: 12, color: widget.cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: Icon(_copied == 'link' ? Icons.check_rounded : Icons.copy_rounded, size: 20),
                onPressed: _copyLink,
                color: _copied == 'link' ? Colors.green : widget.cs.onSurfaceVariant,
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: FilledButton.tonalIcon(
              onPressed: _shareNative,
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Share', style: TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.tonalIcon(
              onPressed: _copyCode,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Code', style: TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.tonalIcon(
              onPressed: _copyLink,
              icon: const Icon(Icons.link_rounded, size: 16),
              label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// How It Works
// ────────────────────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;
  const _HowItWorksCard({required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.share_rounded, Color(0xFF6366F1), 'Share Your Code', 'Send your unique code or link to other pharmacies'),
      (Icons.person_add_rounded, Color(0xFF22C55E), 'They Sign Up', 'The pharmacy enters your code during registration'),
      (Icons.star_rounded, Color(0xFFF59E0B), 'Earn 100 Coins', 'You receive 100 Adhere Coins as a referral bonus'),
      (Icons.trending_up_rounded, Color(0xFF3B82F6), 'Keep Earning', 'Earn 1 coin for every 1,000 API requests they make'),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.rocket_launch_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('How It Works', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((e) {
            final i = e.key;
            final (icon, color, title, desc) = e.value;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
                  child: Icon(icon, size: 18, color: color),
                ),
                if (i < steps.length - 1)
                  Container(width: 2, height: 28, color: cs.outlineVariant.withValues(alpha: 0.3)),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  if (i < steps.length - 1) const SizedBox(height: 12),
                ]),
              )),
            ]);
          }),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Redeem Card
// ────────────────────────────────────────────────────
class _RedeemCard extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;
  const _RedeemCard({required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const redeemOptions = [
      (Icons.payments_rounded, Color(0xFFF59E0B), 'Cash Out', 'Convert to KSH'),
      (Icons.receipt_long_rounded, Color(0xFF6366F1), 'Pay API Bill', 'Settle billing'),
      (Icons.card_giftcard_rounded, Color(0xFF22C55E), 'Gift Coins', 'Send to pharmacy'),
      (Icons.local_offer_rounded, Color(0xFF8B5CF6), 'Discounts', 'Unlock features'),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.redeem_rounded, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 8),
            const Text('Redeem Coins', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_rounded, size: 16, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Expanded(child: Text('Coming Soon! Keep earning — coins will be redeemable when this feature launches.', style: TextStyle(fontSize: 11, color: cs.onSurface))),
            ]),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: redeemOptions.map((opt) {
              final (icon, color, title, desc) = opt;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 24, color: color.withValues(alpha: 0.5)),
                  const SizedBox(height: 6),
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.5))),
                  Text(desc, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.4)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Referral Tile
// ────────────────────────────────────────────────────
class _ReferralTile extends StatelessWidget {
  final Map r;
  final ColorScheme cs;
  const _ReferralTile({required this.r, required this.cs});

  @override
  Widget build(BuildContext context) {
    final status = '${r['status'] ?? 'pending'}';
    final active = status == 'active';
    final name = '${r['referred_name'] ?? r['referred_tenant_name'] ?? ''}';
    final coins = _fmtCoins(r['coins_from_usage'] ?? 0);
    final requests = int.tryParse('${r['tracked_requests'] ?? 0}') ?? 0;
    final date = r['created_at'] != null ? DateFormat('MMM d, yyyy').format(DateTime.parse('${r['created_at']}')) : '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFF22C55E).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.storefront_rounded, size: 20, color: active ? const Color(0xFF22C55E) : Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _MiniChip(Icons.monetization_on_rounded, '$coins coins', const Color(0xFFF59E0B)),
              _MiniChip(Icons.api_rounded, '${NumberFormat.compact().format(requests)} req', const Color(0xFF3B82F6)),
              if (date.isNotEmpty) _MiniChip(Icons.calendar_today_rounded, date, Colors.grey),
            ]),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? const Color(0xFF22C55E) : const Color(0xFFF59E0B))),
          ),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Transaction Tile
// ────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final Map t;
  final ColorScheme cs;
  const _TransactionTile({required this.t, required this.cs});

  @override
  Widget build(BuildContext context) {
    final type = '${t['type'] ?? ''}';
    final earned = type == 'earned' || type == 'bonus';
    final amount = _fmtCoins(t['amount'] ?? 0);
    final reason = '${t['reason'] ?? ''}';
    final related = '${t['related_tenant_name'] ?? ''}';
    final date = t['created_at'] != null ? DateFormat('MMM d, h:mm a').format(DateTime.parse('${t['created_at']}')) : '';

    final (icon, color) = switch (type) {
      'earned' => (Icons.arrow_downward_rounded, const Color(0xFF22C55E)),
      'bonus' => (Icons.star_rounded, const Color(0xFFF59E0B)),
      'redeemed' => (Icons.arrow_upward_rounded, const Color(0xFF3B82F6)),
      _ => (Icons.swap_horiz_rounded, Colors.grey),
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.1))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ),
              if (related.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(child: Text(related, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ]),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(reason, style: TextStyle(fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (date.isNotEmpty)
              Text(date, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ])),
          const SizedBox(width: 8),
          Text('${earned ? '+' : '-'}$amount', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: earned ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({required this.icon, required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ),
  ]);
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(icon, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.6)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    ]),
  );
}
