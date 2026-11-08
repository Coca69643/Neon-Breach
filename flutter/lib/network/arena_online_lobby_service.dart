import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'arena_lobby_code.dart';

class ArenaOnlineLobbyService {
  ArenaOnlineLobbyService._();

  static const String _url = String.fromEnvironment(
    'ARENA_SUPABASE_URL',
    defaultValue: 'https://yduxkvscdahzmmfamvmr.supabase.co',
  );
  static const String _publishableKey = String.fromEnvironment(
    'ARENA_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_slgeksFs5agwljJ_QcYhMA_rqADaaiB',
  );

  static bool _initialized = false;

  static Future<SupabaseClient> _client() async {
    if (!_initialized) {
      await Supabase.initialize(
        url: _url,
        publishableKey: _publishableKey,
      );
      _initialized = true;
    }
    return Supabase.instance.client;
  }

  /// Initializes only the client object; no auth, room or Realtime presence.
  static Future<bool> prepareClient() async {
    try {
      await _client();
      return true;
    } on Object {
      _initialized = false;
      return false;
    }
  }

  static Future<void> _ensureGuest(SupabaseClient client) async {
    if (client.auth.currentUser != null) return;
    final response = await client.auth.signInAnonymously();
    if (response.user == null) {
      throw StateError('O Supabase não retornou uma sessão de convidado.');
    }
  }

  static Future<ArenaOnlineLobbySession> createRoom({
    required String displayName,
  }) async {
    final client = await _client();
    await _ensureGuest(client);
    final code = ArenaLobbyCode.generate();
    return _join(
      client,
      roomCode: code,
      displayName: displayName,
      isHost: true,
    );
  }

  static Future<ArenaOnlineLobbySession> joinRoom({
    required String roomCode,
    required String displayName,
  }) async {
    final normalizedCode = roomCode.trim().toLowerCase();
    if (!ArenaLobbyCode.isValid(normalizedCode)) {
      throw const FormatException('Código de sala inválido.');
    }
    final client = await _client();
    await _ensureGuest(client);
    return _join(
      client,
      roomCode: normalizedCode,
      displayName: displayName,
      isHost: false,
    );
  }

  static Future<ArenaOnlineLobbySession> _join(
    SupabaseClient client, {
    required String roomCode,
    required String displayName,
    required bool isHost,
  }) async {
    final name = ArenaLobbyCode.normalizeDisplayName(displayName);
    final channel = client.channel(
      'arena:lobby:$roomCode',
      opts: const RealtimeChannelConfig(private: true),
    );
    final memberCount = StreamController<int>.broadcast();
    final ready = Completer<void>();

    void emitMemberCount() {
      if (!memberCount.isClosed) {
        memberCount.add(channel.presenceState().length);
      }
    }

    channel.onPresenceSync((_) => emitMemberCount());

    channel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await channel.track({
            'display_name': name,
            'joined_at': DateTime.now().toUtc().toIso8601String(),
            'client_kind': 'mobile',
          });
          emitMemberCount();
          if (!ready.isCompleted) ready.complete();
        } catch (exception, stackTrace) {
          if (!ready.isCompleted) {
            ready.completeError(exception, stackTrace);
          }
        }
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        if (!ready.isCompleted) {
          ready.completeError(
            error ?? StateError('Não foi possível entrar na sala online.'),
          );
        }
      }
    });

    try {
      await ready.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      await channel.unsubscribe();
      await memberCount.close();
      rethrow;
    }

    return ArenaOnlineLobbySession._(
      roomCode: roomCode,
      isHost: isHost,
      displayName: name,
      channel: channel,
      memberCount: memberCount,
    );
  }
}

class ArenaOnlineLobbySession {
  ArenaOnlineLobbySession._({
    required this.roomCode,
    required this.isHost,
    required this.displayName,
    required RealtimeChannel channel,
    required StreamController<int> memberCount,
  })  : _channel = channel,
        _memberCount = memberCount;

  final String roomCode;
  final bool isHost;
  final String displayName;
  final RealtimeChannel _channel;
  final StreamController<int> _memberCount;

  Stream<int> get memberCountStream => _memberCount.stream;
  int get currentMemberCount => _channel.presenceState().length;

  Future<void> leave() async {
    await _channel.untrack();
    await _channel.unsubscribe();
    if (!_memberCount.isClosed) {
      await _memberCount.close();
    }
  }
}
