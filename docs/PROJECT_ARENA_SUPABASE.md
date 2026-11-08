# Project Arena — Supabase environment

Status: security baseline and lobby Realtime policies applied; guest authentication setting and two-device acceptance remain pending.
Project display name: **Projeto Arena** (the game's final name is still undecided)

## Project identity

- Project ref: `yduxkvscdahzmmfamvmr`
- API URL: `https://yduxkvscdahzmmfamvmr.supabase.co`
- Region: `us-east-2`
- PostgreSQL: `17.11.0.018`
- Platform status at verification: `ACTIVE_HEALTHY`
- Created: `2026-11-07T19:28:47Z`

This is the dedicated Project Arena project. The older unrelated project `qttjtvfbsdvcqjyfaxnh` remains inactive and was not modified.

## Applied database migrations

The live remote migration history contains these successful versions:

1. `20261107224227_project_arena_api_security_defaults`
2. `20261107224259_project_arena_revoke_residual_default_grants`
3. `20261108013340_arena_lobby_private_channels`

The third migration creates two policies on `realtime.messages` for authenticated users and topics beginning with `arena:lobby:`:
- SELECT / receive policy: `arena_lobby_channels_receive`
- INSERT / send policy: `arena_lobby_channels_send`

The repository migration file is synchronized to the already-applied remote version:
`supabase/migrations/20261108013340_arena_lobby_private_channels.sql`.
Do not apply it again as a new migration.

## Security and database verification

At the last live check:
- `public` contains no application tables.
- The `ensure_rls` event trigger and its internal function privileges remain restricted.
- The two lobby policies exist on `realtime.messages` with the expected role, command and topic predicate.
- Security, performance and health Advisors returned no findings.

## Flutter integration in the 1.8.3 candidate

- `ArenaOnlineLobbyService` initializes the Supabase client lazily.
- Guest sign-in and private Realtime subscription start only after the player chooses to create or join an online room.
- Presence carries lobby display name, join timestamp and client kind.
- The lobby channel does not transmit combat, movement, damage, weapon or objective state.
- The match simulation remains local/offline. Lobby presence is not full multiplayer synchronization.
- The client uses only the project publishable key. Never embed `service_role` or a secret key in the Android client.
- Offline and LAN modes must remain usable without a Supabase session.

## Blocker: Anonymous Sign-Ins

The Supabase Auth **Anonymous Sign-Ins** provider still needs to be enabled in the Dashboard before two-device online lobby tests can succeed:
https://supabase.com/dashboard/project/yduxkvscdahzmmfamvmr/auth/providers

Official instructions: https://supabase.com/docs/guides/auth/auth-anonymous

Anonymous users use the PostgreSQL `authenticated` role, so policies must be designed with that behavior in mind. The current Realtime topic policies intentionally grant only the private lobby topic prefix.

## Acceptance still pending

- Enable Anonymous Sign-Ins in Auth providers.
- Test guest create/join on two physical installations.
- Verify presence updates, leave/cleanup, reconnect and switching networks.
- Confirm a Supabase outage or auth failure does not block local gameplay.
- Keep the LAN transport and online lobby limited to non-sensitive presence metadata.

