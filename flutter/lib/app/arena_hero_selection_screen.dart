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
    final roster = _visibleHeroes;
    final selectedHero = ArenaHeroCatalog.byId(widget.selectedHeroId) ??
        ArenaHeroCatalog.fallback;
    final totalIndex =
        ArenaHeroCatalog.playable.indexWhere((hero) => hero.id == selectedHero.id) + 1;

    return LayoutBuilder(
      builder: (context, viewport) {
        final compact =
            widget.compact || viewport.maxHeight < 440 || viewport.maxWidth < 720;
        final narrow = viewport.maxWidth < 820;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: narrow ? 11 : 13,
              child: _HeroSpotlight(
                hero: selectedHero,
                index: totalIndex,
                total: ArenaHeroCatalog.playable.length,
                compact: compact,
              ),
            ),
            SizedBox(width: compact ? 10 : 16),
            Expanded(
              flex: narrow ? 9 : 8,
              child: _HeroRosterPanel(
                heroes: roster,
                selectedHeroId: selectedHero.id,
                speciesFilter: _speciesFilter,
                compact: compact,
                onSelect: widget.onSelect,
                onFilter: _setSpeciesFilter,
                onBack: widget.onBack,
                onConfirm: widget.onConfirm,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroSpotlight extends StatelessWidget {
  const _HeroSpotlight({
    required this.hero,
    required this.index,
    required this.total,
    required this.compact,
  });

  final ArenaHeroDefinition hero;
  final int index;
  final int total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x465C8590)),
          gradient: const RadialGradient(
            center: Alignment(0, -0.1),
            radius: 1.0,
            colors: [
              Color(0xFF263E48),
              Color(0xFF15232D),
              Color(0xFF0D151D),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ArenaHeroPreview(heroId: hero.id),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.36, 0.72, 1],
                    colors: [
                      Color(0x60101A22),
                      Color(0x000E1720),
                      Color(0x16101820),
                      Color(0xD90A1219),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: compact ? 12 : 18,
              left: compact ? 14 : 20,
              right: compact ? 14 : 20,
              child: Row(
                children: [
                  const Icon(
                    Icons.hub_outlined,
                    size: 15,
                    color: Color(0xFF80DCC5),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'ARENA  /  SELEÇÃO DE COMBATENTE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFD9E6E8),
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  _StageCounter(index: index, total: total),
                ],
              ),
            ),
            Positioned(
              left: compact ? 16 : 24,
              right: compact ? 16 : 24,
              bottom: compact ? 14 : 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hero.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFF2F7F6),
                      fontSize: compact ? 25 : 34,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                      shadows: const [
                        Shadow(
                          color: Color(0xAA000000),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 7 : 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      _HeroInfoTag(label: hero.species.label),
                      _HeroInfoTag(label: hero.role),
                    ],
                  ),
                  SizedBox(height: compact ? 6 : 9),
                  Text(
                    hero.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFC5D1D4),
                      fontSize: compact ? 10 : 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageCounter extends StatelessWidget {
  const _StageCounter({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xA916252F),
        border: Border.all(color: const Color(0x6079D6BD)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          '\${index.toString().padLeft(2, '0')}  /  \${total.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Color(0xFFE3F3EF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _HeroInfoTag extends StatelessWidget {
  const _HeroInfoTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xA81A3039),
        border: Border.all(color: const Color(0x7779D6BD)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9CE1D1),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
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
    required this.compact,
    required this.onSelect,
    required this.onFilter,
    required this.onBack,
    required this.onConfirm,
  });

  final List<ArenaHeroDefinition> heroes;
  final String selectedHeroId;
  final ArenaHeroSpecies? speciesFilter;
  final bool compact;
  final ValueChanged<String> onSelect;
  final ValueChanged<ArenaHeroSpecies?> onFilter;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ELENCO DE COMBATENTES',
          style: TextStyle(
            color: const Color(0xFF79D6BD),
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.7,
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
        SizedBox(height: compact ? 10 : 16),
        Text(
          'ESPÉCIE',
          style: TextStyle(
            color: const Color(0xFF9BAAB0),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: compact ? 5 : 8),
        _SpeciesFilters(
          selected: speciesFilter,
          onSelect: onFilter,
          compact: compact,
        ),
        SizedBox(height: compact ? 10 : 15),
        Row(
          children: [
            const Text(
              'PERSONAGENS',
              style: TextStyle(
                color: Color(0xFFD5E0E1),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Text(
              '\${heroes.length.toString().padLeft(2, '0')} DISPONÍVEIS',
              style: const TextStyle(
                color: Color(0xFF91A3AA),
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
            separatorBuilder: (_, __) => SizedBox(height: compact ? 5 : 8),
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
                foregroundColor: const Color(0xFFB7C4C9),
                minimumSize: const Size(84, 48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'VOLTAR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              width: compact ? 132 : 158,
              child: FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF79D6BD),
                  foregroundColor: const Color(0xFF102B2B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'CONFIRMAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
          _SpeciesFilterChip(
            label: 'TODOS',
            selected: selected == null,
            compact: compact,
            onTap: () => onSelect(null),
          ),
          for (final species in ArenaHeroCatalog.availableSpecies) ...[
            const SizedBox(width: 6),
            _SpeciesFilterChip(
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

class _SpeciesFilterChip extends StatelessWidget {
  const _SpeciesFilterChip({
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
      color: selected ? const Color(0x283B9A84) : const Color(0x141D2B33),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 36 : 40),
          padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFF79D6BD)
                  : const Color(0x604B6069),
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF9CE4D2)
                  : const Color(0xFFB3C0C5),
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
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
    final accent = selected
        ? const Color(0xFF79D6BD)
        : const Color(0xFF52636D);

    return Material(
      color: selected
          ? const Color(0x273C8C7B)
          : const Color(0x171E2B33),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 58 : 66),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 12,
            vertical: compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.95 : 0.42),
              width: selected ? 1.4 : 0.9,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 39,
                height: compact ? 34 : 39,
                decoration: BoxDecoration(
                  color: const Color(0x332D4952),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: selected
                        ? const Color(0x8879D6BD)
                        : const Color(0x445F7780),
                  ),
                ),
                child: Icon(
                  _speciesIcon,
                  size: compact ? 18 : 20,
                  color: selected
                      ? const Color(0xFF94E0CD)
                      : const Color(0xFF9AAEB4),
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
                            ? const Color(0xFFB1EBDD)
                            : const Color(0xFFE1E8E9),
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${hero.species.label}  ·  ${hero.role}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF9DADB3),
                        fontSize: compact ? 8 : 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 5 : 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: compact ? 17 : 19,
                color: selected
                    ? const Color(0xFF79D6BD)
                    : const Color(0xFF687981),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
