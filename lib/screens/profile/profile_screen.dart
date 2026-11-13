import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_actions.dart';
import '../../providers/game_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/faction_badge.dart';
import '../../widgets/image_source_sheet.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/shelter_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  Future<void> _changeAvatar() async {
    final img = await pickImage(context);
    if (img == null || !mounted) return;
    setState(() => _uploading = true);
    await runAction(context, () => ref.read(gameActionsProvider).updateAvatar(img), success: 'Avatar atualizado!');
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _logout() async {
    final ok = await confirmAction(
      context,
      title: 'Sair da conta?',
      message: 'Seus dados ficam salvos no servidor. É só entrar de novo para continuar.',
      confirmLabel: 'Sair',
    );
    if (ok && mounted) await runAction(context, () => ref.read(authControllerProvider).signOut());
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final email = ref.watch(currentEmailProvider);
    final stats = ref.watch(profileStatsProvider);
    final myShelters = ref.watch(myShelterListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('PERFIL')),
      body: AsyncValueView(
        value: profileAsync,
        onRetry: () => ref.invalidate(currentProfileProvider),
        data: (profile) {
          if (profile == null) return const LoadingState();
          final faction = profile.faction;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentProfileProvider);
              ref.invalidate(profileStatsProvider);
              ref.invalidate(myShelterListProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(children: [
                    PlayerAvatar(
                      nickname: profile.nickname,
                      url: profile.avatarUrl,
                      size: 112,
                      borderColor: faction?.color,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: AppColors.signal,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Trocar avatar',
                          onPressed: _uploading ? null : _changeAvatar,
                          icon: _uploading
                              ? const SizedBox(
                                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                              : const Icon(Icons.photo_camera, color: AppColors.ink),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Center(child: Text(profile.nickname, style: AppText.display(size: 26))),
                Center(child: Text(email ?? '', style: const TextStyle(color: AppColors.textMuted))),
                const SizedBox(height: 12),
                if (faction != null) Center(child: FactionBadge(faction: faction)),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Icon(Icons.star_rounded, color: AppColors.signal, size: 36),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Reputação acumulada')),
                      Text('${profile.reputation}', style: AppText.display(size: 30, color: AppColors.signal)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle('Estatísticas'),
                AsyncValueView(
                  value: stats,
                  onRetry: () => ref.invalidate(profileStatsProvider),
                  loading: const LinearProgressIndicator(),
                  data: (s) => GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      _Stat(icon: Icons.explore, label: 'Expedições concluídas', value: s.expeditionsCompleted),
                      _Stat(icon: Icons.handshake, label: 'Trocas realizadas', value: s.tradesCompleted),
                      _Stat(icon: Icons.house_siding, label: 'Abrigos cadastrados', value: s.sheltersCreated),
                      _Stat(icon: Icons.visibility, label: 'Alertas confirmados', value: s.alertsConfirmed),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle('Meus abrigos'),
                AsyncValueView(
                  value: myShelters,
                  onRetry: () => ref.invalidate(myShelterListProvider),
                  loading: const LinearProgressIndicator(),
                  data: (list) => list.isEmpty
                      ? const Text('Você ainda não cadastrou abrigos.', style: TextStyle(color: AppColors.textMuted))
                      : Column(children: [
                          for (final s in list) ...[
                            ShelterCard(shelter: s, onTap: () => context.push('/abrigos/${s.id}')),
                            const SizedBox(height: 8),
                          ],
                        ]),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('SAIR'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.cobaltLight, size: 20),
              const Spacer(),
              Text('$value', style: AppText.display(size: 24)),
            ]),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
