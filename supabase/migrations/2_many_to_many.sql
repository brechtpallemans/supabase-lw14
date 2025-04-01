create table public.events (
    id uuid not null default gen_random_uuid () primary key
)
tablespace pg_default;

alter table public.events enable row level security;

create table public.profiles (
    id uuid not null default auth.uid () primary key,
    constraint profiles_id_fkey foreign key (id) references auth.users (id) on delete cascade
)
tablespace pg_default;

alter table public.profiles enable row level security;

create table public.participants (
    user_id uuid not null,
    event_id uuid not null,
    constraint participants_pkey primary key (event_id, user_id),
    constraint participants_user_id_fkey foreign key (user_id) references public.profiles (id) on delete cascade,
    constraint participants_event_id_fkey foreign key (event_id) references public.events (id) on delete cascade
);

alter table public.participants enable row level security;

-- Goal: user can read all participants of an event where they are participating in.
-- Notes:
-- security definer
create or replace function public.user_is_participant (event_id uuid, user_id uuid)
    returns boolean
    language plpgsql
    security definer
    set search_path = ''
    as $function$
begin
    return exists (
        select
            *
        from
            public.participants p
        where
            p.event_id = $1
            and p.user_id = $2);
end;
$function$;

create policy participant_can_read_events on public.events as permissive
    for select to public
        using (public.user_is_participant (id, (
            select
                auth.uid () as uid)));

-- Notes:
-- security invoker (default)
create or replace function public.user_can_read_event (event_id uuid)
    returns boolean
    language plpgsql
    security invoker
    set search_path = ''
    as $function$
begin
    return exists (
        select
            *
        from
            public.events e
        where
            e.id = $1);
end;
$function$;

create policy participants_read_participants on public.participants as permissive
    for select to public
        using (public.user_can_read_event (event_id));
