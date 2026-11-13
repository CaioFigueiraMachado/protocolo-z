import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme.dart';
import '../../models/ranking.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/faction_badge.dart';
import '../../widgets/player_avatar.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RANKING'),
          bottom: const TabBar(tabs: [Tab(text: 'Sobreviventes'), Tab(text: 'Facções')]),
        ),
        body: const TabBarView(children: [_SurvivorsTab(), _FactionsTab()]),
      ),
    );
  }
}

Color _medal(int position) => switch (position) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      3 => AppColors.bronze,
      _ => AppColors.outline,
    };

class _SurvivorsTab extends ConsumerWidget {
  const _SurvivorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(survivorRankingProvider);
    final uid = ref.watch(currentUserIdProvider);
    ref.watch(factionsProvider);

    return AsyncValueView(
      value: ranking,
      onRetry: () => ref.invalidate(survivorRankingProvider),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(icon: Icons.leaderboard, title: 'Ranking vazio');
        }
        final me = list.where((r) => r.id == uid).firstOrNull;
        return Column(children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(survivorRankingProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _SurvivorRow(rank: list[i], isMe: list[i].id == uid),
              ),
            ),
          ),
          if (me != null)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.cobalt,
                  border: Border(top: BorderSide(color: AppColors.cobaltLight)),
                ),
                child: Row(children: [
                  const Icon(Icons.person_pin, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Sua posição: ${me.position}º de ${list.length}',
                        style: AppText.display(size: 16, color: Colors.white)),
                  ),
                  Text('${me.reputation} pts', style: AppText.display(size: 16, color: AppColors.signal)),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _SurvivorRow extends ConsumerWidget {
  const _SurvivorRow({required this.rank, required this.isMe});
  final SurvivorRank rank;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faction = ref.watch(factionByIdProvider(rank.factionId));
    final top3 = rank.position <= 3;
    final medal = _medal(rank.position);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: top3 ? 14 : 10),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.cobalt.withValues(alpha: 0.35)
            : top3
                ? Color.lerp(AppColors.surface, medal, 0.12)
                : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? AppColors.cobaltLight : (top3 ? medal : AppColors.outline), width: isMe || top3 ? 2 : 1),
      ),
      child: Row(children: [
        SizedBox(
          width: 40,
          child: top3
              ? Icon(Icons.emoji_events, color: medal, size: 30)
              : Text('${rank.position}º', textAlign: TextAlign.center, style: AppText.display(size: 16)),
        ),
        const SizedBox(width: 8),
        PlayerAvatar(nickname: rank.nickname, url: rank.avatarUrl, size: top3 ? 46 : 38, borderColor: faction?.color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isMe ? '${rank.nickname} (você)' : rank.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: top3 ? 16 : 14),
            ),
            if (faction != null) ...[const SizedBox(height: 4), FactionBadge(faction: faction)],
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${rank.reputation}', style: AppText.display(size: top3 ? 22 : 18, color: AppColors.signal)),
          const Text('reputação', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

class _FactionsTab extends ConsumerWidget {
  const _FactionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(factionRankingProvider);
    final myFaction = ref.watch(currentProfileProvider).value?.factionId;

    return AsyncValueView(
      value: ranking,
      onRetry: () => ref.invalidate(factionRankingProvider),
      data: (list) {
        final maxRep = list.isEmpty ? 1 : list.map((f) => f.totalReputation).reduce((a, b) => a > b ? a : b);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(factionRankingProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _FactionRow(
              rank: list[i],
              position: i + 1,
              maxRep: maxRep,
              isMine: list[i].id == myFaction,
            ),
          ),
        );
      },
    );
  }
}

class _FactionRow extends StatelessWidget {
  const _FactionRow({required this.rank, required this.position, required this.maxRep, required this.isMine});
  final FactionRank rank;
  final int position;
  final int maxRep;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF${rank.colorHex.substring(1)}', radix: 16));
    final ratio = maxRep <= 0 ? 0.0 : rank.totalReputation / maxRep;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.surface, color, 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMine ? color : AppColors.outline, width: isMine ? 2 : 1),
      ),
      child: Column(children: [
        Row(children: [
          Text('$positionº', style: AppText.display(size: 22, color: _medal(position) == AppColors.outline ? AppColors.text : _medal(position))),
          const SizedBox(width: 12),
          SvgPicture.asset('assets/factions/${rank.symbol}.svg', width: 48, height: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rank.name.toUpperCase() + (isMine ? '  · SUA FACÇÃO' : ''), style: AppText.display(size: 16)),
              Text('${rank.members} membro(s)', style: const TextStyle(color: AppColors.textMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${rank.totalReputation}', style: AppText.display(size: 22, color: AppColors.signal)),
            const Text('reputação total', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: ratio, minHeight: 8, color: color, backgroundColor: AppColors.surfaceHigh),
        ),
      ]),
    );
  }
}
