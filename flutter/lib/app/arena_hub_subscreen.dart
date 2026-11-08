import 'package:flutter/material.dart';

import '../game/arena_hero_catalog.dart';
import '../game/rendering/arena_main_menu_scene.dart';
import 'arena_hub_progress.dart';

enum ArenaHubSection { chests, challenges, merchant }

class ArenaHubSubscreen extends StatelessWidget {
  const ArenaHubSubscreen({
    super.key,
    required this.section,
    required this.progression,
    required this.onOpenHeroes,
  });

  final ArenaHubSection section;
  final ArenaHubProgressStore progression;
  final VoidCallback onOpenHeroes;

  String get _title => switch (section) {
        ArenaHubSection.chests => 'BAÚS',
        ArenaHubSection.challenges => 'DESAFIOS',
        ArenaHubSection.merchant => 'MERCADOR',
      };

  String get _subtitle => switch (section) {
        ArenaHubSection.chests => 'Recompensas garantidas e coleção.',
        ArenaHubSection.challenges => 'Objetivos que acompanham suas partidas.',
        ArenaHubSection.merchant => 'Personalização visual do seu perfil.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1720),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ArenaMainMenuScene(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xD7091722),
                  Color(0xC8111C27),
                  Color(0xF10A121A),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: const Color(0xA91C2D38),
                        shape: const CircleBorder(
                          side: BorderSide(color: Color(0x668FB8B9)),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          tooltip: 'Voltar ao hub',
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFFE8F0EC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: const TextStyle(
                                color: Color(0xFFF2D28B),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB7C6C9),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedBuilder(
                        animation: progression,
                        builder: (context, _) => _CreditsPill(
                          amount: progression.credits,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: progression,
                      builder: (context, _) => switch (section) {
                        ArenaHubSection.chests => _ChestPage(
                            progression: progression,
                            onOpenHeroes: onOpenHeroes,
                          ),
                        ArenaHubSection.challenges => _ChallengesPage(
                            progression: progression,
                          ),
                        ArenaHubSection.merchant => _MerchantPage(
                            progression: progression,
                          ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChestPage extends StatelessWidget {
  const _ChestPage({
    required this.progression,
    required this.onOpenHeroes,
  });

  final ArenaHubProgressStore progression;
  final VoidCallback onOpenHeroes;

  Future<void> _claim(BuildContext context) async {
    final claimed = await progression.claimDailyChest();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          claimed
              ? '+${ArenaHubProgressStore.dailyChestCredits} créditos adicionados ao seu saldo.'
              : 'O baú diário já foi resgatado hoje.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = progression.canClaimDailyChest;
    return LayoutBuilder(
      builder: (context, viewport) {
        final compact = viewport.maxWidth < 760 || viewport.maxHeight < 390;

        final chest = _SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow('RECOMPENSA DIÁRIA'),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: compact ? 84 : 108,
                        height: compact ? 84 : 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x2BE4BB63),
                          border: Border.all(
                            color: const Color(0x88E4BB63),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22E4BB63),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: const Color(0xFFF0D08A),
                          size: compact ? 42 : 54,
                        ),
                      ),
                      const SizedBox(height: 13),
                      const Text(
                        'BAÚ DE SUPRIMENTOS',
                        style: TextStyle(
                          color: Color(0xFFF5F0E4),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '100 CRÉDITOS DE ARENA',
                        style: TextStyle(
                          color: Color(0xFFF0CC7C),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Conteúdo fixo, sem sorteio.',
                        style: TextStyle(
                          color: Color(0xFFB8C7CA),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: available ? () => _claim(context) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE4BB63),
                    disabledBackgroundColor: const Color(0xFF34414A),
                    foregroundColor: const Color(0xFF352719),
                    disabledForegroundColor: const Color(0xFFAFBDC0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(
                    available ? 'RESGATAR RECOMPENSA' : 'JÁ RESGATADO HOJE',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final collection = _SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow('SUA COLEÇÃO'),
              const SizedBox(height: 10),
              Text(
                '${ArenaHeroCatalog.playable.length} heróis disponíveis',
                style: const TextStyle(
                  color: Color(0xFFF1F2E9),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Veja os personagens que já fazem parte do elenco jogável e escolha quem vai representar você na próxima partida.',
                style: TextStyle(
                  color: Color(0xFFB9C7C9),
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  for (final hero in ArenaHeroCatalog.playable) ...[
                    Expanded(
                      child: Container(
                        height: 62,
                        margin: const EdgeInsets.only(right: 7),
                        decoration: BoxDecoration(
                          color: const Color(0x44304A53),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x557EAAA9)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              color: Color(0xFFE2C58A),
                              size: 20,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hero.name,
                              style: const TextStyle(
                                color: Color(0xFFE5ECE7),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 13),
              SizedBox(
                height: 44,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenHeroes,
                  icon: const Icon(Icons.groups_rounded, size: 17),
                  label: const Text('ABRIR SELEÇÃO DE HERÓIS'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBCE8DC),
                    side: const BorderSide(color: Color(0x7785CFC0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (compact) {
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 250, child: chest),
                const SizedBox(height: 12),
                SizedBox(height: 250, child: collection),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 6, child: chest),
            const SizedBox(width: 14),
            Expanded(flex: 5, child: collection),
          ],
        );
      },
    );
  }
}

class _ChallengesPage extends StatelessWidget {
  const _ChallengesPage({required this.progression});

  final ArenaHubProgressStore progression;

  Future<void> _claim(BuildContext context, ArenaHubChallenge challenge) async {
    final claimed = await progression.claimChallenge(challenge.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          claimed
              ? '+${challenge.reward} créditos adicionados.'
              : 'Esse desafio ainda não pode ser resgatado.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        final compact = viewport.maxHeight < 390 || viewport.maxWidth < 740;
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'PARTIDAS CONCLUÍDAS',
                          value: '${progression.completedMatches}',
                          icon: Icons.sports_esports_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          title: 'VITÓRIAS',
                          value: '${progression.wins}',
                          icon: Icons.emoji_events_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  for (final challenge in progression.challenges)
                    Padding(
                      padding: EdgeInsets.only(bottom: compact ? 8 : 11),
                      child: _ChallengeCard(
                        challenge: challenge,
                        compact: compact,
                        onClaim: () => _claim(context, challenge),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'O progresso é salvo neste aparelho e atualizado ao concluir uma partida.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9FB2B6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MerchantPage extends StatelessWidget {
  const _MerchantPage({required this.progression});

  final ArenaHubProgressStore progression;

  Future<void> _purchase(BuildContext context, ArenaProfileFrameStyle frame) async {
    final purchased = await progression.purchaseFrame(frame.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          purchased
              ? 'Moldura ${frame.name} adicionada à coleção.'
              : 'Créditos insuficientes ou item já adquirido.',
        ),
      ),
    );
  }

  Future<void> _equip(BuildContext context, ArenaProfileFrameStyle frame) async {
    final equipped = await progression.equipFrame(frame.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          equipped
              ? 'Moldura ${frame.name} equipada no perfil.'
              : 'Não foi possível equipar essa moldura.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final frames = ArenaHubProgressStore.profileFrames
        .where((frame) => frame.id != 'standard')
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, viewport) {
        final compact = viewport.maxWidth < 760 || viewport.maxHeight < 390;
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: _Eyebrow('PERSONALIZAÇÃO COSMÉTICA'),
                      ),
                      _CosmeticOnlyTag(),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Personalize sua identidade',
                    style: TextStyle(
                      color: Color(0xFFF2F0E6),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'As molduras alteram somente a aparência do perfil. Não mudam atributos nem desempenho dos heróis.',
                    style: TextStyle(
                      color: Color(0xFFB8C7C9),
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  if (compact)
                    Column(
                      children: [
                        for (final frame in frames) ...[
                          _FrameShopCard(
                            frame: frame,
                            progression: progression,
                            onBuy: () => _purchase(context, frame),
                            onEquip: () => _equip(context, frame),
                          ),
                          const SizedBox(height: 9),
                        ],
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final frame in frames)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _FrameShopCard(
                                frame: frame,
                                progression: progression,
                                onBuy: () => _purchase(context, frame),
                                onEquip: () => _equip(context, frame),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FrameShopCard extends StatelessWidget {
  const _FrameShopCard({
    required this.frame,
    required this.progression,
    required this.onBuy,
    required this.onEquip,
  });

  final ArenaProfileFrameStyle frame;
  final ArenaHubProgressStore progression;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final owned = progression.ownsFrame(frame.id);
    final equipped = progression.equippedFrame.id == frame.id;
    final compact = MediaQuery.sizeOf(context).height < 390;

    return Container(
      padding: EdgeInsets.all(compact ? 11 : 15),
      decoration: BoxDecoration(
        color: const Color(0xB91A2A35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: equipped ? frame.color : const Color(0x55718E95),
          width: equipped ? 1.5 : 1,
        ),
      ),
      child: compact
          ? Row(
              children: [
                _FramePreview(frame: frame, size: 54),
                const SizedBox(width: 12),
                Expanded(child: _frameDescription(owned, equipped)),
                const SizedBox(width: 10),
                SizedBox(width: 112, child: _frameAction(owned, equipped)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _FramePreview(frame: frame, size: 86)),
                const SizedBox(height: 13),
                _frameDescription(owned, equipped),
                const SizedBox(height: 14),
                _frameAction(owned, equipped),
              ],
            ),
    );
  }

  Widget _frameDescription(bool owned, bool equipped) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          frame.name,
          style: TextStyle(
            color: frame.highlight,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          frame.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFB9C8CA),
            fontSize: 9,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          owned ? (equipped ? 'EM USO' : 'ADQUIRIDA') : '${frame.price} CRÉDITOS',
          style: const TextStyle(
            color: Color(0xFFE8C578),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _frameAction(bool owned, bool equipped) {
    if (equipped) {
      return const SizedBox(
        width: double.infinity,
        height: 40,
        child: Center(
          child: Text(
            'EQUIPADA',
            style: TextStyle(
              color: Color(0xFF93D6C7),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 40,
      child: FilledButton(
        onPressed: owned ? onEquip : onBuy,
        style: FilledButton.styleFrom(
          backgroundColor:
              owned ? const Color(0xFF76C7B4) : const Color(0xFFE4BB63),
          foregroundColor: const Color(0xFF182B2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          owned ? 'EQUIPAR' : 'ADQUIRIR',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _FramePreview extends StatelessWidget {
  const _FramePreview({required this.frame, required this.size});

  final ArenaProfileFrameStyle frame;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF263E49),
        border: Border.all(color: frame.color, width: 4),
        boxShadow: [
          BoxShadow(
            color: frame.color.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.person_rounded,
        color: frame.highlight,
        size: size * 0.5,
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.compact,
    required this.onClaim,
  });

  final ArenaHubChallenge challenge;
  final bool compact;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xB91A2A35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: challenge.canClaim
              ? const Color(0x99D9B56E)
              : const Color(0x55718E95),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 44,
            height: compact ? 36 : 44,
            decoration: BoxDecoration(
              color: const Color(0x332A7D72),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: Color(0xFF9ADBCB),
            ),
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(
                    color: Color(0xFFF1F2E8),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  challenge.description,
                  style: const TextStyle(
                    color: Color(0xFFB6C5C8),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: challenge.fraction,
                    minHeight: 5,
                    backgroundColor: const Color(0x553F5059),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF83CDBB),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${challenge.progress.clamp(0, challenge.target)} / ${challenge.target}',
                  style: const TextStyle(
                    color: Color(0xFF9EAFB4),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 8 : 15),
          SizedBox(
            width: compact ? 105 : 132,
            height: 39,
            child: challenge.claimed
                ? const Center(
                    child: Text(
                      'RESGATADO',
                      style: TextStyle(
                        color: Color(0xFF8DCEBE),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : challenge.canClaim
                    ? FilledButton(
                        onPressed: onClaim,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE4BB63),
                          foregroundColor: const Color(0xFF352719),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'RESGATAR +${challenge.reward}',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : Text(
                        '+${challenge.reward} CRÉDITOS',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE2C57E),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xAB1B2B36),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55718E95)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE4BB63), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFF4E8C9),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFB1C1C4),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditsPill extends StatelessWidget {
  const _CreditsPill({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xB91D2E37),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x88D8B66E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.toll_rounded,
            color: Color(0xFFE5C474),
            size: 15,
          ),
          const SizedBox(width: 7),
          Text(
            '$amount',
            style: const TextStyle(
              color: Color(0xFFF2D48F),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CosmeticOnlyTag extends StatelessWidget {
  const _CosmeticOnlyTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x332AA18B),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x777ACDBC)),
      ),
      child: const Text(
        'SÓ VISUAL',
        style: TextStyle(
          color: Color(0xFFAEE8D8),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF8AD5C5),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xD0192A36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66708E95)),
      ),
      child: child,
    );
  }
}
