import 'dart:io';

import 'package:flutter/material.dart';

import '../game/rendering/arena_main_menu_scene.dart';
import 'arena_hub_progress.dart';
import 'arena_player_profile.dart';

class ArenaPlayerProfileScreen extends StatefulWidget {
  const ArenaPlayerProfileScreen({
    super.key,
    required this.profile,
    required this.progression,
    required this.onSaveName,
    required this.onPickAvatar,
  });

  final ArenaPlayerProfile profile;
  final ArenaHubProgressStore progression;
  final Future<ArenaPlayerProfile> Function(String) onSaveName;
  final Future<ArenaPlayerProfile?> Function() onPickAvatar;

  @override
  State<ArenaPlayerProfileScreen> createState() =>
      _ArenaPlayerProfileScreenState();
}

class _ArenaPlayerProfileScreenState extends State<ArenaPlayerProfileScreen> {
  late final TextEditingController _nameController;
  late ArenaPlayerProfile _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _nameController = TextEditingController(text: _profile.displayName);
  }

  @override
  void didUpdateWidget(covariant ArenaPlayerProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.displayName != widget.profile.displayName) {
      _profile = widget.profile;
      if (!_saving) _nameController.text = _profile.displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.onSaveName(_nameController.text);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do jogador atualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o nome: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeAvatar() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.onPickAvatar();
      if (updated != null && mounted) {
        setState(() => _profile = updated);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar a foto: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1720),
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
                  Color(0xD8091722),
                  Color(0xC5111D28),
                  Color(0xF20B121B),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final compact = viewport.maxHeight < 470 ||
                    viewport.maxWidth < 760;
                final horizontal = viewport.maxWidth < 700 ? 16.0 : 32.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    compact ? 10 : 20,
                    horizontal,
                    compact ? 10 : 22,
                  ),
                  child: Column(
                    children: [
                      _ProfileScreenHeader(
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      SizedBox(height: compact ? 12 : 24),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1080),
                            child: compact
                                ? _buildCompactContent()
                                : _buildWideContent(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideContent() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _ProfileIdentityPanel(
            profile: _profile,
            progression: widget.progression,
            onChangeAvatar: _changeAvatar,
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          flex: 6,
          child: _ProfileEditorPanel(
            nameController: _nameController,
            saving: _saving,
            progression: widget.progression,
            onSaveName: _saveName,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 194,
            child: _ProfileIdentityPanel(
              profile: _profile,
              progression: widget.progression,
              onChangeAvatar: _changeAvatar,
              compact: true,
            ),
          ),
          const SizedBox(height: 12),
          _ProfileEditorPanel(
            nameController: _nameController,
            saving: _saving,
            progression: widget.progression,
            onSaveName: _saveName,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _ProfileScreenHeader extends StatelessWidget {
  const _ProfileScreenHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: const Color(0xA91B2B36),
          shape: const CircleBorder(
            side: BorderSide(color: Color(0x668FB8B9)),
          ),
          child: IconButton(
            onPressed: onBack,
            tooltip: 'Voltar ao hub',
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFFE8F0EC),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PERFIL DO JOGADOR',
              style: TextStyle(
                color: Color(0xFFF1D18B),
                fontSize: 12,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Sua identidade na Arena',
              style: TextStyle(
                color: Color(0xFFB5C6C9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileIdentityPanel extends StatelessWidget {
  const _ProfileIdentityPanel({
    required this.profile,
    required this.progression,
    required this.onChangeAvatar,
    this.compact = false,
  });

  final ArenaPlayerProfile profile;
  final ArenaHubProgressStore progression;
  final VoidCallback onChangeAvatar;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progression,
      builder: (context, _) {
        final frame = progression.equippedFrame;
        final size = compact ? 78.0 : 142.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 12 : 24),
          decoration: BoxDecoration(
            color: const Color(0xB9162732),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x666E9095)),
          ),
          child: compact
              ? Row(
                  children: [
                    _AvatarButton(
                      path: profile.avatarPath,
                      size: size,
                      frame: frame,
                      onTap: onChangeAvatar,
                    ),
                    const SizedBox(width: 15),
                    Expanded(child: _identityText()),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AvatarButton(
                      path: profile.avatarPath,
                      size: size,
                      frame: frame,
                      onTap: onChangeAvatar,
                    ),
                    const SizedBox(height: 20),
                    _identityText(),
                    const SizedBox(height: 18),
                    _ProfileCounterStrip(
                      matches: progression.completedMatches,
                      wins: progression.wins,
                      credits: progression.credits,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _identityText() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFFF3F5EC),
            fontSize: compact ? 18 : 27,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'JOGADOR LOCAL',
          style: TextStyle(
            color: const Color(0xFF93D6C7),
            fontSize: compact ? 8 : 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Nome, foto e moldura são salvos neste aparelho.',
          textAlign: compact ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB8C6C9),
            fontSize: 10,
            height: 1.45,
          ),
        ),
        if (compact) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onChangeAvatar,
            icon: const Icon(Icons.photo_camera_outlined, size: 15),
            label: const Text('ALTERAR FOTO'),
          ),
        ],
      ],
    );
  }
}

class _ProfileCounterStrip extends StatelessWidget {
  const _ProfileCounterStrip({
    required this.matches,
    required this.wins,
    required this.credits,
  });

  final int matches;
  final int wins;
  final int credits;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ProfileCounter(label: 'PARTIDAS', value: '$matches')),
        Expanded(child: _ProfileCounter(label: 'VITÓRIAS', value: '$wins')),
        Expanded(child: _ProfileCounter(label: 'CRÉDITOS', value: '$credits')),
      ],
    );
  }
}

class _ProfileCounter extends StatelessWidget {
  const _ProfileCounter({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF1D18B),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFAFC2C5),
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.path,
    required this.size,
    required this.frame,
    required this.onTap,
  });

  final String? path;
  final double size;
  final ArenaProfileFrameStyle frame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF14242D),
      shape: CircleBorder(
        side: BorderSide(color: frame.color, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipOval(
            child: SizedBox(
              width: size - 8,
              height: size - 8,
              child: path == null
                  ? const ColoredBox(
                      color: Color(0xFF233A45),
                      child: Icon(
                        Icons.person_rounded,
                        color: Color(0xFFEAD4A0),
                        size: 48,
                      ),
                    )
                  : Image.file(
                      File(path!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                        color: Color(0xFF233A45),
                        child: Icon(
                          Icons.person_rounded,
                          color: Color(0xFFEAD4A0),
                          size: 48,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileEditorPanel extends StatelessWidget {
  const _ProfileEditorPanel({
    required this.nameController,
    required this.saving,
    required this.progression,
    required this.onSaveName,
    this.compact = false,
  });

  final TextEditingController nameController;
  final bool saving;
  final ArenaHubProgressStore progression;
  final VoidCallback onSaveName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progression,
      builder: (context, _) {
        final frame = progression.equippedFrame;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 24),
          decoration: BoxDecoration(
            color: const Color(0xD0192A36),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x66708E95)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IDENTIDADE',
                style: TextStyle(
                  color: Color(0xFF86D7C8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: nameController,
                maxLength: ArenaPlayerProfile.maxDisplayNameLength,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  labelText: 'Nome do jogador',
                  hintText: 'Digite seu nome',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0x8023313B),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0x555E7D84)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF8ADCCB),
                      width: 1.4,
                    ),
                  ),
                ),
                onSubmitted: (_) => onSaveName(),
              ),
              const SizedBox(height: 7),
              const Text(
                'O nome aparece no hub e nas salas de sessão.',
                style: TextStyle(
                  color: Color(0xFFAFC0C4),
                  fontSize: 10,
                ),
              ),
              SizedBox(height: compact ? 12 : 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: frame.color, width: 3),
                      color: const Color(0xFF213640),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFFE9D7AB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MOLDURA EQUIPADA',
                          style: TextStyle(
                            color: Color(0xFFAFC0C4),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          frame.name,
                          style: TextStyle(
                            color: frame.highlight,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('FECHAR'),
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: saving ? null : onSaveName,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(saving ? 'SALVANDO' : 'SALVAR ALTERAÇÕES'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE4BB63),
                    foregroundColor: const Color(0xFF352719),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
