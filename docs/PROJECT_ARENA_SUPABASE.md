# Project Arena — Supabase environment

Status: **security baseline applied; gameplay integration not started**  
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

The remote migration history contains these successful versions:

1. `20261107224227_project_arena_api_security_defaults`
2. `20261107224259_project_arena_revoke_residual_default_grants`

The security baseline is:

```sql
-- Internal-only RLS event-trigger function.
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable()
  FROM PUBLIC, anon, authenticated, service_role;

-- Functions created by postgres do not become public RPC endpoints by default.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE EXECUTE ON FUNCTIONS
  FROM PUBLIC, anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS
  FROM anon, authenticated, service_role;

-- Public API roles receive no implicit access to future tables/sequences.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON TABLES
  FROM anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON SEQUENCES
  FROM anon, authenticated, service_role;
```

The first migration initially revoked the CRUD and sequence permissions, then the second removed the remaining low-level table/sequence grants as well. Both migrations include transient assertions executed in the migration transaction; the probes were dropped before completion.

## Verification

Verified after both migrations:

- `public.rls_auto_enable()` remains owned by `postgres` and is still bound to the `ensure_rls` DDL event trigger.
- `anon`, `authenticated`, and `service_role` cannot execute that internal function.
- Temporary table probe confirmed the event trigger still enables RLS on newly created `public` tables.
- Temporary table/identity-sequence probe confirmed no implicit table or sequence privileges for the three API roles, including `TRUNCATE`, `REFERENCES`, `TRIGGER`, and `MAINTAIN`.
- Temporary RPC probe confirmed no implicit `EXECUTE` for the API roles.
- Security, performance, and health Advisors returned no findings.
- The `public` schema currently has no application tables.

## Integration boundary

Supabase is not yet connected to the Flutter client. No API keys were copied into the repository, and no Auth, Storage, Realtime, Edge Function, leaderboard, cloud-save, or remote-profile feature was invented.

The current player profile remains local/offline. Keep gameplay usable without a network connection. A future online feature must define its data model, ownership model, RLS policies, and minimum explicit grants before adding tables or client code. Never embed a `service_role` or secret key in the Android client.

## Repository synchronization

The successful migrations are present in the remote Supabase migration history. Their local CLI-generated migration files still need to be synchronized into `supabase/migrations/` before this repository can reproduce the database from scratch. Do not assume the remote migration history alone is a committed local migration source.
