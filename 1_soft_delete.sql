create table public.events (
    id uuid not null default gen_random_uuid (),
    created_at timestamp(3) with time zone not null default now(),
    updated_at timestamp(3) with time zone not null default now(),
    deleted_at timestamp(3) with time zone null,
    deleted_by_user_id uuid null,
    constraint events_pkey primary key (id),
    constraint events_deleted_by_user_id_fkey foreign key (deleted_by_user_id) references auth.users (id) on delete set null
)
tablespace pg_default;

alter table public.events enable row level security;

-- Restrictive policies always apply, opposite of permissive
create policy soft_deleted_events on public.events as restrictive
    for all to public
        using (deleted_at is null)
        with check (deleted_at is null
            and deleted_by_user_id is null);

create policy restrict_delete_events on public.events as restrictive
    for delete to public
        using (false);

-- Notes:
-- security definer
-- need to recode the RLS permissions to only allow soft delete of certain records
create or replace function soft_delete_event (id uuid)
    returns void
    language plpgsql
    security definer
    set search_path = ''
    as $function$
begin
    update
        public.events
    set
        deleted_at = now(),
        deleted_by_user_id = (
            select
                auth.uid () as uid)
    where
        events.id = $1
        and events.deleted_at is null
        and public.user_can_read_event (events.id);
end;
$function$;
