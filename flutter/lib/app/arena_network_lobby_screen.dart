import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/arena_lan_lobby.dart';
import '../network/arena_lobby_code.dart';
import '../network/arena_online_lobby_service.dart';

class ArenaNetworkLobbyScreen extends StatefulWidget {
  const ArenaNetworkLobbyScreen({
    super.key,
    required this.displayName,
  });

  final String displayName;

  @override
  State<ArenaNetworkLobbyScreen> createState() => _ArenaNetworkLobbyScreenState();
}

class _ArenaNetworkLobbyScreenState extends State<ArenaNetworkLobbyScreen> {
  late final TextEditingController _name;
  late final TextEditingController _onlineCode;
  late final TextEditingController _lanAddress;
  late final TextEditingController _lanPort;
  late final TextEditingController _lanCode;

  ArenaOnlineLobbySession? _online;
  StreamSubscription<int>? _onlineSub;
  int _onlineCount = 0;

  ArenaLanLobbyHost? _host;
  ArenaLanLobbyClient? _client;
  ArenaLanEndpoint? _endpoint;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.displayName);
    _onlineCode = TextEditingController();
    _lanAddress = TextEditingController();
    _lanPort = TextEditingController();
    _lanCode = TextEditingController();
  }

  String get _displayName => ArenaLobbyCode.normalizeDisplayName(_name.text);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '');
    if (value.toLowerCase().contains('anonymous') ||
        value.contains('signups_not_allowed')) {
      return 'Ative o login anônimo em Supabase → Authentication → Sign In / Providers.';
    }
    if (value.contains('SocketException')) {
      return 'Host LAN inacessível. Verifique se os aparelhos estão no mesmo Wi-Fi e confira IP/porta.';
    }
    return value.length > 220 ? '${value.substring(0, 220)}…' : value;
  }

  Future<void> _createOnline() async {
    await _run(() async {
      await _leaveOnline();
      final session = await ArenaOnlineLobbyService.createRoom(
        displayName: _displayName,
      );
      if (!mounted) {
        await session.leave();
        return;
      }
      setState(() {
        _online = session;
        _onlineCount = session.currentMemberCount;
        _onlineCode.text = session.roomCode;
      });
      _onlineSub = session.memberCountStream.listen((count) {
        if (mounted) setState(() => _onlineCount = count);
      });
    });
  }

  Future<void> _joinOnline() async {
    await _run(() async {
      await _leaveOnline();
      final session = await ArenaOnlineLobbyService.joinRoom(
        roomCode: _onlineCode.text,
        displayName: _displayName,
      );
      if (!mounted) {
        await session.leave();
        return;
      }
      setState(() {
        _online = session;
        _onlineCount = session.currentMemberCount;
      });
      _onlineSub = session.memberCountStream.listen((count) {
        if (mounted) setState(() => _onlineCount = count);
      });
    });
  }

  Future<void> _leaveOnline() async {
    await _onlineSub?.cancel();
    _onlineSub = null;
    final session = _online;
    _online = null;
    _onlineCount = 0;
    await session?.leave();
  }

  Future<void> _hostLan() async {
    await _run(() async {
      await _leaveLan();
      final host = ArenaLanLobbyHost(
        displayName: _displayName,
        roomCode: ArenaLobbyCode.generate(),
      );
      final endpoint = await host.start();
      if (endpoint.addresses.isEmpty) {
        await host.close();
        throw StateError('Nenhum endereço IPv4 local foi encontrado.');
      }
      if (!mounted) {
        await host.close();
        return;
      }
      setState(() {
        _host = host;
        _endpoint = endpoint;
        _lanCode.text = endpoint.roomCode;
        _lanPort.text = endpoint.port.toString();
      });
    });
  }

  Future<void> _joinLan() async {
    await _run(() async {
      await _leaveLan();
      final port = int.tryParse(_lanPort.text.trim());
      if (port == null) throw const FormatException('Porta inválida.');
      final client = await ArenaLanLobbyClient.join(
        address: _lanAddress.text,
        port: port,
        roomCode: _lanCode.text,
        displayName: _displayName,
      );
      if (!mounted) {
        await client.close();
        return;
      }
      setState(() => _client = client);
    });
  }

  Future<void> _leaveLan() async {
    final host = _host;
    final client = _client;
    _host = null;
    _client = null;
    _endpoint = null;
    await host?.close();
    await client?.close();
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copiado.')),
      );
    }
  }

  Future<void> _closeAll() async {
    await _onlineSub?.cancel();
    await _online?.leave();
    await _host?.close();
    await _client?.close();
  }

  @override
  void dispose() {
    unawaited(_closeAll());
    _name.dispose();
    _onlineCode.dispose();
    _lanAddress.dispose();
    _lanPort.dispose();
    _lanCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF79D6BD);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF101820),
        appBar: AppBar(
          title: const Text('SALAS DE REDE'),
          backgroundColor: const Color(0xFF101820),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.public), text: 'ONLINE'),
              Tab(icon: Icon(Icons.wifi), text: 'REDE LOCAL'),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _name,
                      maxLength: 18,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Colors.white),
                      decoration: _input('Nome do jogador', Icons.person).copyWith(
                        counterText: '',
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _onlinePane(accent),
                        _lanPane(accent),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF422A2A),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFFD6D6)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _onlinePane(Color accent) {
    final session = _online;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Heading(
          'PARTIDA PELA INTERNET',
          'Salas privadas por código, com presença em tempo real.',
        ),
        const SizedBox(height: 14),
        if (session == null) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _createOnline,
            icon: const Icon(Icons.add_link),
            label: const Text('CRIAR SALA ONLINE'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: const Color(0xFF102027),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _onlineCode,
            maxLength: 32,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: Colors.white, letterSpacing: 1.1),
            decoration: _input('Código de convite (32 caracteres)', Icons.key)
                .copyWith(counterText: ''),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _joinOnline,
            icon: const Icon(Icons.login),
            label: const Text('ENTRAR NA SALA'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Requer internet e login anônimo habilitado no Supabase. '
            'Esta fatia sincroniza somente presença no lobby.',
            style: TextStyle(color: Color(0xFF9BAEB8), height: 1.4),
          ),
        ] else ...[
          _copyRow('Código', session.roomCode, () => _copy(session.roomCode)),
          const SizedBox(height: 12),
          _counter(_onlineCount),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(_leaveOnline),
            icon: const Icon(Icons.logout),
            label: const Text('SAIR DA SALA'),
          ),
        ],
      ],
    );
  }

  Widget _lanPane(Color accent) {
    final endpoint = _endpoint;
    final host = _host;
    final client = _client;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Heading(
          'PARTIDA NA MESMA REDE',
          'Host por IP e porta; os aparelhos precisam estar no mesmo Wi-Fi.',
        ),
        const SizedBox(height: 14),
        if (endpoint != null && host != null) ...[
          _copyRow(
            'Código',
            endpoint.roomCode,
            () => _copy(endpoint.roomCode),
          ),
          _copyRow(
            'Porta',
            endpoint.port.toString(),
            () => _copy(endpoint.port.toString()),
          ),
          ...endpoint.addresses.map(
            (address) => _copyRow(
              'IP',
              address,
              () => _copy(address + ':' + endpoint.port.toString()),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<String>>(
            stream: host.members,
            initialData: host.currentMembers,
            builder: (context, snapshot) => _members(
              snapshot.data ?? const <String>[],
              accent,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(_leaveLan),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('ENCERRAR SALA'),
          ),
        ] else if (client != null) ...[
          StreamBuilder<List<String>>(
            stream: client.members,
            initialData: client.currentMembers,
            builder: (context, snapshot) => _members(
              snapshot.data ?? const <String>[],
              accent,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(_leaveLan),
            icon: const Icon(Icons.link_off),
            label: const Text('SAIR DA SALA'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: _busy ? null : _hostLan,
            icon: const Icon(Icons.router),
            label: const Text('HOSPEDAR NESTE APARELHO'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: const Color(0xFF102027),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lanAddress,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: const TextStyle(color: Colors.white),
            decoration: _input('IP do aparelho anfitrião', Icons.computer),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lanPort,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _input('Porta', Icons.numbers),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _lanCode,
                  maxLength: 32,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: _input('Código LAN', Icons.key).copyWith(
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _joinLan,
            icon: const Icon(Icons.login),
            label: const Text('CONECTAR AO HOST'),
          ),
          const SizedBox(height: 12),
          const Text(
            'O host apresenta IP, porta e código. A conexão nesta fatia '
            'transporta apenas presença; a simulação 3D permanece offline.',
            style: TextStyle(color: Color(0xFF9BAEB8), height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _members(List<String> names, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JOGADORES (' + names.length.toString() + ')',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 6),
        ...names.map(
          (name) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person, color: Color(0xFF9BAEB8)),
            title: Text(name, style: const TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _counter(int count) => Row(
        children: [
          const Icon(Icons.people_alt_outlined, color: Color(0xFF79D6BD)),
          const SizedBox(width: 8),
          Text(
            count.toString() + ' conectado(s)',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      );

  Widget _copyRow(String label, String value, VoidCallback onCopy) => Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(color: Color(0xFF9BAEB8))),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            onPressed: onCopy,
            icon: const Icon(Icons.copy, color: Color(0xFF79D6BD)),
          ),
        ],
      );

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF9BAEB8)),
        labelStyle: const TextStyle(color: Color(0xFF9BAEB8)),
        filled: true,
        fillColor: const Color(0xFF111B22),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0x334D7382)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF79D6BD), width: 1.4),
          borderRadius: BorderRadius.circular(10),
        ),
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE5D5AA),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF9BAEB8), height: 1.4),
          ),
        ],
      );
}
