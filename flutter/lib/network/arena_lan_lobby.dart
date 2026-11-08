import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'arena_lobby_code.dart';

class ArenaLanEndpoint {
  const ArenaLanEndpoint({
    required this.addresses,
    required this.port,
    required this.roomCode,
  });

  final List<String> addresses;
  final int port;
  final String roomCode;
}

class ArenaLanLobbyHost {
  ArenaLanLobbyHost({
    required this.displayName,
    required this.roomCode,
  }) : _displayName = ArenaLobbyCode.normalizeDisplayName(displayName) {
    if (!ArenaLobbyCode.isValid(roomCode)) {
      throw const FormatException('Código LAN inválido.');
    }
  }

  final String _displayName;
  final String roomCode;
  final Map<Socket, String> _clients = <Socket, String>{};
  final Map<Socket, StreamSubscription<String>> _subscriptions =
      <Socket, StreamSubscription<String>>{};
  final StreamController<List<String>> _members =
      StreamController<List<String>>.broadcast();

  ServerSocket? _server;
  bool _closed = false;

  Stream<List<String>> get members => _members.stream;
  List<String> get currentMembers => List<String>.unmodifiable(_memberNames());
  int get currentMemberCount => 1 + _clients.length;

  Future<ArenaLanEndpoint> start() async {
    if (_server != null) {
      throw StateError('O host LAN já foi iniciado.');
    }
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
      shared: true,
    );
    _server!.listen(_accept);

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final addresses = interfaces
        .expand((interface) => interface.addresses)
        .where((address) =>
            !address.isLoopback && !address.address.startsWith('169.254.'))
        .map((address) => address.address)
        .toSet()
        .toList()
      ..sort();

    _emitMembers();
    return ArenaLanEndpoint(
      addresses: addresses,
      port: _server!.port,
      roomCode: roomCode,
    );
  }

  void _accept(Socket socket) {
    final subscription = socket
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) => _handleMessage(socket, line),
      onDone: () => _removeClient(socket),
      onError: (_) => _removeClient(socket),
      cancelOnError: true,
    );
    _subscriptions[socket] = subscription;
  }

  void _handleMessage(Socket socket, String line) {
    if (line.length > 2048 || _closed) {
      socket.destroy();
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      socket.writeln(jsonEncode({'type': 'error', 'message': 'Mensagem inválida.'}));
      socket.destroy();
      return;
    }

    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'join' ||
        decoded['room_code'] != roomCode) {
      socket.writeln(jsonEncode({'type': 'error', 'message': 'Código de sala inválido.'}));
      socket.destroy();
      return;
    }

    if (_clients.containsKey(socket)) return;
    if (_clients.length >= 7) {
      socket.writeln(jsonEncode({'type': 'error', 'message': 'Sala cheia.'}));
      socket.destroy();
      return;
    }

    final rawName = decoded['display_name'];
    if (rawName is! String) {
      socket.destroy();
      return;
    }

    String name;
    try {
      name = ArenaLobbyCode.normalizeDisplayName(rawName);
    } on ArgumentError {
      socket.destroy();
      return;
    }

    _clients[socket] = name;
    _writeRoster(socket);
    _emitMembers();
    _broadcastRoster();
  }

  List<String> _memberNames() => <String>[
        _displayName,
        ..._clients.values,
      ];

  void _writeRoster(Socket socket) {
    socket.writeln(jsonEncode({
      'type': 'roster',
      'members': _memberNames(),
    }));
  }

  void _broadcastRoster() {
    for (final socket in _clients.keys.toList(growable: false)) {
      try {
        _writeRoster(socket);
      } on SocketException {
        _removeClient(socket);
      }
    }
  }

  void _emitMembers() {
    if (!_members.isClosed) {
      _members.add(List<String>.unmodifiable(_memberNames()));
    }
  }

  void _removeClient(Socket socket) {
    final removed = _clients.remove(socket);
    _subscriptions.remove(socket)?.cancel();
    if (removed != null) {
      socket.destroy();
      _emitMembers();
      _broadcastRoster();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final socket in _clients.keys) {
      socket.destroy();
    }
    _clients.clear();
    await _server?.close();
    if (!_members.isClosed) await _members.close();
  }
}

class ArenaLanLobbyClient {
  ArenaLanLobbyClient._(this._socket);

  final Socket _socket;
  final StreamController<List<String>> _members =
      StreamController<List<String>>.broadcast();
  StreamSubscription<String>? _subscription;
  List<String> _currentMembers = const <String>[];
  bool _closed = false;

  Stream<List<String>> get members => _members.stream;
  List<String> get currentMembers => _currentMembers;

  static Future<ArenaLanLobbyClient> join({
    required String address,
    required int port,
    required String roomCode,
    required String displayName,
  }) async {
    if (!ArenaLobbyCode.isValid(roomCode)) {
      throw const FormatException('Código LAN inválido.');
    }
    if (port < 1 || port > 65535) {
      throw const FormatException('Porta inválida.');
    }

    final name = ArenaLobbyCode.normalizeDisplayName(displayName);
    final socket = await Socket.connect(
      address.trim(),
      port,
      timeout: const Duration(seconds: 6),
    );
    final client = ArenaLanLobbyClient._(socket);
    final ready = Completer<void>();

    client._subscription = socket
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.length > 2048) {
          if (!ready.isCompleted) {
            ready.completeError(const FormatException('Resposta LAN muito grande.'));
          }
          socket.destroy();
          return;
        }
        dynamic decoded;
        try {
          decoded = jsonDecode(line);
        } catch (_) {
          if (!ready.isCompleted) {
            ready.completeError(const FormatException('Resposta LAN inválida.'));
          }
          socket.destroy();
          return;
        }
        if (decoded is! Map<String, dynamic>) return;

        if (decoded['type'] == 'error') {
          final message = decoded['message'];
          if (!ready.isCompleted) {
            ready.completeError(StateError(
              message is String ? message : 'Falha ao entrar na sala LAN.',
            ));
          }
          return;
        }

        final rawMembers = decoded['members'];
        if (decoded['type'] == 'roster' && rawMembers is List) {
          final names = rawMembers.whereType<String>().take(8).toList(growable: false);
          client._currentMembers = List<String>.unmodifiable(names);
          if (!client._members.isClosed) client._members.add(client._currentMembers);
          if (!ready.isCompleted) ready.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!ready.isCompleted) ready.completeError(error, stackTrace);
      },
      onDone: () {
        if (!ready.isCompleted) {
          ready.completeError(StateError('O host LAN encerrou a conexão.'));
        }
      },
      cancelOnError: true,
    );

    socket.writeln(jsonEncode({
      'type': 'join',
      'room_code': roomCode.toLowerCase(),
      'display_name': name,
    }));

    try {
      await ready.future.timeout(const Duration(seconds: 8));
    } catch (_) {
      await client.close();
      rethrow;
    }
    return client;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _socket.destroy();
    if (!_members.isClosed) await _members.close();
  }
}
