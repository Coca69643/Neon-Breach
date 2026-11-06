import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/arena_hero_catalog.dart';
import '../game/rendering/arena_hero_preview.dart';

class ArenaHeroSelectionScreen extends StatefulWidget {
  const ArenaHeroSelectionScreen({
    super.key,
    required this.selectedHeroId,
    required this.onSelect,
    required this.onBack,
    required this.onConfirm,
    this.compact = false,
  });

  final String selectedHeroId;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback onConfirm;
  final bool compact;

  @override
  State<ArenaHeroSelectionScreen> createState() =>
      _ArenaHeroSelectionScreenState();
}

class _ArenaHeroSelectionScreenState extends State<ArenaHeroSelectionScreen> {
  ArenaHeroSpecies? _speciesFilter;

  List<ArenaHeroDefinition> get _visibleHeroes {
    final heroes = ArenaHeroCatalog.playable;
    final filter = _speciesFilter;
    if (filter == null) return heroes;
    return heroes.where((hero) => hero.species == filter).toList();
  }

  void _setSpeciesFilter(ArenaHeroSpecies? species) {
    final nextHeroes = species == null
        ? ArenaHeroCatalog.playable
        : ArenaHeroCatalog.playable
            .where((hero) => hero.species == species)
            .toList(growable: false);
    if (nextHeroes.isEmpty) return;

    setState(() => _speciesFilter = species);
    if (!nextHeroes.any((hero) => hero.id == widget.selectedHeroId)) {
      widget.onSelect(nextHeroes.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedHero = ArenaHeroCatalog.byId(widget.selectedHeroId) ??
        ArenaHeroCatalog.fallback;
    final roster = _visibleHeroes;
    final total = ArenaHeroCatalog.playable.length;
    final selectedIndex =
        ArenaHeroCatalog.playable.indexWhere((hero) => hero.id == selectedHero.id) + 1;

    return LayoutBuilder(
      builder: (context, viewport) {
        final compact = widget.compact ||
            viewport.maxHeight < 440 ||
            viewport.maxWidth < 760;
        final panelWidth = math.min(
          420.0,
          math.max(286.0, viewport.maxWidth * 0.34),
        ).toDouble();

        return Stack(
          fit: StackFit.expand,
          children: [
            ArenaHeroPreview(heroId: selectedHero.id),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.40, 0.60, 1.0],
                    colors: [
                      Color(0x18101A22),
                      Color(0x00101820),
                      Color(0x80101820),
                      Color(0xF0101820),
                    ],
                  ),
                ),
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.18, 0.72, 1.0],
                    colors: [
                      Color(0x50101A22),
                      Color(0x000E1720),
                      Color(0x000E1720),
                      Color(0xA90A1219),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: compact ? 16 : 26,
                    top: compact ? 10 : 18,
                    right: panelWidth + (compact ? 30 : 42),
                    child: _StageTopline(
                      index: selectedIndex,
                      total: total,
                      compact: compact,
                    ),
                  ),
                  Positioned(
                    left: compact ? 18 : 30,
                    bottom: compact ? 16 : 24,
                    right: panelWidth + (compact ? 34 : 52),
                    child: _SelectedHeroIdentity(
                      hero: selectedHero,
                      compact: compact,
                    ),
                  ),
                  Positioned(
                    top: compact ? 8 : 18,
                    bottom: compact ? 8 : 18,
                    right: compact ? 8 : 22,
                    width: panelWidth,
                    child: _HeroRosterPanel(
                      heroes: roster,
                      selectedHeroId: selectedHero.id,
                      speciesFilter: _speciesFilter,
                      showSpeciesFilters: ArenaHeroCatalog.hasMultipleSpecies,
                      compact: compact,
                      onSelect: widget.onSelect,
                      onFilter: _setSpeciesFilter,
                      onBack: widget.onBack,
                      onConfirm: widget.onConfirm,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StageTopline extends StatelessWidget {
  const _StageTopline({
    required this.index,
    required this.total,
    required this.compact,
  });

  final int index;
  final int total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.shield_outlined, color: Color(0xFF8DDBC7), size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'PROJETO ARENA  /  SELEÇÃO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFDCE8E8),
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.25,
              shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)],
            ),
          ),
        ),
        const Spacer(),
        Text(
          '${index.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Color(0xFFE6F0EF),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            shadows: [Shadow(color: Color(0xAA000000), blurRadius: 7)],
          ),
        ),
      ],
    );
  }
}

class _SelectedHeroIdentity extends StatelessWidget {
  const _SelectedHeroIdentity({
    required this.hero,
    required this.compact,
  });

  final ArenaHeroDefinition hero;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final nonHuman = hero.species != ArenaHeroSpecies.human;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hero.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFFF4F7F4),
            fontSize: compact ? 28 : 39,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            shadows: const [
              Shadow(
                color: Color(0xC9000000),
                blurRadius: 14,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 7 : 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IdentityTag(label: hero.role),
            if (nonHuman) ...[
              const SizedBox(width: 7),
              _IdentityTag(label: hero.species.label),
            ],
          ],
        ),
        SizedBox(height: compact ? 5 : 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Text(
            hero.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFD5DFE0),
              fontSize: compact ? 10 : 12,
              height: 1.3,
              shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 8)],
            ),
          ),
        ),
      ],
    );
  }
}

class _IdentityTag extends StatelessWidget {
  const _IdentityTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xA51A3037),
        border: Border.all(color: const Color(0x9879D6BD)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFA9E7D7),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.85,
          ),
        ),
      ),
    );
  }
}

class _HeroRosterPanel extends StatelessWidget {
  const _HeroRosterPanel({
    required this.heroes,
    required this.selectedHeroId,
    required this.speciesFilter,
    required this.showSpeciesFilters,
    required this.compact,
    required this.onSelect,
    required this.onFilter,
    required this.onBack,
    required this.onConfirm,
  });

  final List<ArenaHeroDefinition> heroes;
  final String selectedHeroId;
  final ArenaHeroSpecies? speciesFilter;
  final bool showSpeciesFilters;
  final bool compact;
  final ValueChanged<String> onSelect;
  final ValueChanged<ArenaHeroSpecies?> onFilter;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HERÓIS',
            style: TextStyle(
              color: const Color(0xFF8DDBC7),
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          SizedBox(height: compact ? 4 : 7),
          Text(
            'Escolha seu herói',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFF0F4F4),
              fontSize: compact ? 19 : 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          if (showSpeciesFilters) ...[
            _SpeciesFilters(
              selected: speciesFilter,
              onSelect: onFilter,
              compact: compact,
            ),
            SizedBox(height: compact ? 8 : 12),
          ],
          Row(
            children: [
              Text(
                'ELENCO',
                style: TextStyle(
                  color: const Color(0xFFD5E0E1),
                  fontSize: compact ? 8 : 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                '${heroes.length.toString().padLeft(2, '0')} DISPONÍVEIS',
                style: const TextStyle(
                  color: Color(0xFF9DADB3),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 9),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: heroes.length,
              separatorBuilder: (_, __) => SizedBox(height: compact ? 5 : 7),
              itemBuilder: (context, index) {
                final hero = heroes[index];
                return _HeroRosterCard(
                  hero: hero,
                  selected: hero.id == selectedHeroId,
                  compact: compact,
                  onTap: () => onSelect(hero.id),
                );
              },
            ),
          ),
          SizedBox(height: compact ? 7 : 10),
          Row(
            children: [
              TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD0DADD),
                  minimumSize: const Size(74, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Text(
                  'VOLTAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 46,
                width: compact ? 128 : 150,
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF83D6C1),
                    foregroundColor: const Color(0xFF122C2C),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'CONFIRMAR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeciesFilters extends StatelessWidget {
  const _SpeciesFilters({
    required this.selected,
    required this.onSelect,
    required this.compact,
  });

  final ArenaHeroSpecies? selected;
  final ValueChanged<ArenaHeroSpecies?> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SpeciesChip(
            label: 'TODOS',
            selected: selected == null,
            compact: compact,
            onTap: () => onSelect(null),
          ),
          for (final species in ArenaHeroCatalog.availableSpecies) ...[
            const SizedBox(width: 6),
            _SpeciesChip(
              label: species.pluralLabel,
              selected: selected == species,
              compact: compact,
              onTap: () => onSelect(species),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0x333F9D88) : const Color(0x22202E34),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 34 : 38),
          padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFF83D6C1)
                  : const Color(0x655D747A),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFACE9D9)
                  : const Color(0xFFC1CCCF),
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.55,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroRosterCard extends StatelessWidget {
  const _HeroRosterCard({
    required this.hero,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final ArenaHeroDefinition hero;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  IconData get _speciesIcon => switch (hero.species) {
        ArenaHeroSpecies.human => Icons.person_outline_rounded,
        ArenaHeroSpecies.synthetic => Icons.memory_rounded,
        ArenaHeroSpecies.creature => Icons.pets_outlined,
        ArenaHeroSpecies.other => Icons.auto_awesome_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final nonHuman = hero.species != ArenaHeroSpecies.human;
    final accent = selected
        ? const Color(0xFF83D6C1)
        : const Color(0xFF53656D);

    return Material(
      color: selected
          ? const Color(0x453A8E7E)
          : const Color(0x30202C33),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 54 : 62),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.95 : 0.48),
              width: selected ? 1.35 : 0.9,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  color: const Color(0x362D454C),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _speciesIcon,
                  size: compact ? 18 : 19,
                  color: selected
                      ? const Color(0xFFA5E7D5)
                      : const Color(0xFFA6B6BA),
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hero.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFB4EBDD)
                            : const Color(0xFFF0F4F4),
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.65,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      nonHuman
                          ? '${hero.species.label}  ·  ${hero.role}'
                          : hero.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFB2BFC2),
                        fontSize: compact ? 8 : 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 5 : 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: compact ? 18 : 19,
                color: selected
                    ? const Color(0xFF83D6C1)
                    : const Color(0xFF72838A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
