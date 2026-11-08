-- Private Realtime channels reserved for Project Arena lobby presence.
-- No combat, weapon, damage, or attack messages are part of this channel policy.
create policy "arena_lobby_channels_receive"
on realtime.messages
for select
to authenticated
using ((select realtime.topic()) like 'arena:lobby:%');

create policy "arena_lobby_channels_send"
on realtime.messages
for insert
to authenticated
with check ((select realtime.topic()) like 'arena:lobby:%');
