-- =====================================================================
-- CIMA 360° · Esquema de base de datos (Supabase)
-- Proyecto: el mismo del Aula y el Plan de Vida (siaykigdlgnjjcklxaoc).
-- Todo usa el prefijo e360_ y NO toca tablas existentes.
-- Se puede correr más de una vez (idempotente).
-- =====================================================================

-- ---------- Tablas ----------
create table if not exists public.e360_members (
  id text primary key,
  email text not null unique,
  org_id text,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.e360_orgs (
  id text primary key, org_id text, data jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table if not exists public.e360_people (
  id text primary key, org_id text not null, data jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table if not exists public.e360_models (
  id text primary key, org_id text, data jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table if not exists public.e360_campaigns (
  id text primary key, org_id text not null, data jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table if not exists public.e360_assignments (
  id text primary key, org_id text not null, campaign_id text not null, token text not null unique,
  data jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table if not exists public.e360_coaching (
  id text primary key, org_id text, data jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table if not exists public.e360_proposals (
  id text primary key, org_id text, data jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table if not exists public.e360_settings (
  id text primary key, data jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);

create index if not exists e360_people_org on public.e360_people(org_id);
create index if not exists e360_campaigns_org on public.e360_campaigns(org_id);
create index if not exists e360_assignments_org on public.e360_assignments(org_id);
create index if not exists e360_assignments_campaign on public.e360_assignments(campaign_id);

-- ---------- Quién soy (por el correo de la sesión) ----------
create or replace function public.e360_me_role() returns text
language sql stable security definer set search_path = public as $$
  select data->>'role' from public.e360_members where email = lower(coalesce(auth.jwt()->>'email', '')) limit 1
$$;
create or replace function public.e360_me_org() returns text
language sql stable security definer set search_path = public as $$
  select org_id from public.e360_members where email = lower(coalesce(auth.jwt()->>'email', '')) limit 1
$$;
create or replace function public.e360_is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.e360_me_role() in ('admin', 'coach'), false)
$$;
create or replace function public.e360_rh_sees_reports(p_org text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select (data->>'rhSeesIndividual')::boolean from public.e360_orgs where id = p_org), false)
$$;

-- ---------- Seguridad por fila (RLS) ----------
alter table public.e360_members     enable row level security;
alter table public.e360_orgs        enable row level security;
alter table public.e360_people      enable row level security;
alter table public.e360_models      enable row level security;
alter table public.e360_campaigns   enable row level security;
alter table public.e360_assignments enable row level security;
alter table public.e360_coaching    enable row level security;
alter table public.e360_proposals   enable row level security;
alter table public.e360_settings    enable row level security;

do $$
declare r record;
begin
  -- limpia políticas previas para poder re-ejecutar el script
  for r in select policyname, tablename from pg_policies
           where schemaname = 'public' and tablename like 'e360\_%' loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Usuarios: cada quien lee su propio registro; el equipo CIMA lee todos; sólo el admin modifica.
create policy e360_members_read  on public.e360_members for select to authenticated
  using (public.e360_is_staff() or email = lower(coalesce(auth.jwt()->>'email', '')));
create policy e360_members_admin on public.e360_members for all to authenticated
  using (public.e360_me_role() = 'admin') with check (public.e360_me_role() = 'admin');

-- Empresas: CIMA todo; Capital Humano sólo lee la suya.
create policy e360_orgs_staff on public.e360_orgs for all to authenticated
  using (public.e360_is_staff()) with check (public.e360_is_staff());
create policy e360_orgs_rh on public.e360_orgs for select to authenticated
  using (public.e360_me_role() = 'rh' and id = public.e360_me_org());

-- Colaboradores y procesos: CIMA todo; Capital Humano todo dentro de su empresa.
create policy e360_people_staff on public.e360_people for all to authenticated
  using (public.e360_is_staff()) with check (public.e360_is_staff());
create policy e360_people_rh on public.e360_people for all to authenticated
  using (public.e360_me_role() = 'rh' and org_id = public.e360_me_org())
  with check (public.e360_me_role() = 'rh' and org_id = public.e360_me_org());
create policy e360_campaigns_staff on public.e360_campaigns for all to authenticated
  using (public.e360_is_staff()) with check (public.e360_is_staff());
create policy e360_campaigns_rh on public.e360_campaigns for all to authenticated
  using (public.e360_me_role() = 'rh' and org_id = public.e360_me_org())
  with check (public.e360_me_role() = 'rh' and org_id = public.e360_me_org());

-- Asignaciones (respuestas): CIMA todo. Capital Humano: lee respuestas sólo si su empresa
-- tiene encendido "reportes individuales"; puede agregar/quitar evaluadores pendientes,
-- pero nunca modificar respuestas.
create policy e360_asg_staff on public.e360_assignments for all to authenticated
  using (public.e360_is_staff()) with check (public.e360_is_staff());
create policy e360_asg_rh_read on public.e360_assignments for select to authenticated
  using (public.e360_me_role() = 'rh' and org_id = public.e360_me_org() and public.e360_rh_sees_reports(org_id));
create policy e360_asg_rh_read_pending on public.e360_assignments for select to authenticated
  using (public.e360_me_role() = 'rh' and org_id = public.e360_me_org() and coalesce(data->>'status', 'pendiente') = 'pendiente');
create policy e360_asg_rh_insert on public.e360_assignments for insert to authenticated
  with check (public.e360_me_role() = 'rh' and org_id = public.e360_me_org() and coalesce(data->>'status', 'pendiente') = 'pendiente');
create policy e360_asg_rh_delete on public.e360_assignments for delete to authenticated
  using (public.e360_me_role() = 'rh' and org_id = public.e360_me_org() and coalesce(data->>'status', 'pendiente') = 'pendiente');

-- Modelos: todos los usuarios dados de alta los leen; sólo CIMA los edita.
create policy e360_models_read on public.e360_models for select to authenticated
  using (public.e360_me_role() is not null);
create policy e360_models_staff on public.e360_models for all to authenticated
  using (public.e360_is_staff()) with check (public.e360_is_staff());

-- Coaching, propuestas y precios: sólo equipo CIMA.
create policy e360_coaching_staff on public.e360_coaching for all to authenticated
  using (public.e360_is_staff()) with check (public.e360_is_staff());
create policy e360_proposals_staff on public.e360_proposals for all to authenticated
  using (public.e360_is_staff()) with check (public.e360_is_staff());
create policy e360_settings_staff on public.e360_settings for all to authenticated
  using (public.e360_is_staff()) with check (public.e360_is_staff());

-- ---------- Avance para Capital Humano sin respuestas ----------
create or replace function public.e360_assignments_progress()
returns table(id text, data jsonb)
language sql stable security definer set search_path = public as $$
  select a.id, (a.data - 'answers' - 'open') as data
  from public.e360_assignments a
  where public.e360_me_role() = 'rh' and a.org_id = public.e360_me_org()
$$;

-- ---------- Cuestionario público por enlace (sin cuenta) ----------
create or replace function public.e360_q_get(p_token text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare a record; c record; result jsonb;
begin
  if p_token is null or length(p_token) < 20 then return null; end if;
  select * into a from public.e360_assignments where token = p_token;
  if not found then return null; end if;
  select * into c from public.e360_campaigns where id = a.campaign_id;
  if not found then return null; end if;
  select jsonb_build_object(
    'assignment', jsonb_build_object('rel', a.data->>'rel', 'status', coalesce(a.data->>'status', 'pendiente')),
    'campaign',   jsonb_build_object('name', c.data->>'name', 'status', c.data->>'status'),
    'org',        (select o.data->>'name' from public.e360_orgs o where o.id = c.org_id),
    'evaluatee',  (select p.data->>'name' from public.e360_people p where p.id = a.data->>'evaluateeId'),
    'rater',      (select p.data->>'name' from public.e360_people p where p.id = a.data->>'raterId'),
    'model',      (select m.data from public.e360_models m where m.id = c.data->>'modelId')
  ) into result;
  return result;
end $$;

create or replace function public.e360_q_submit(p_token text, p_answers jsonb, p_open jsonb)
returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare a record; c record;
begin
  if p_token is null or length(p_token) < 20 then return false; end if;
  if jsonb_typeof(p_answers) <> 'object' or jsonb_typeof(coalesce(p_open, '{}'::jsonb)) <> 'object' then return false; end if;
  if length(p_answers::text) > 20000 or length(coalesce(p_open, '{}'::jsonb)::text) > 8000 then return false; end if;
  select * into a from public.e360_assignments where token = p_token for update;
  if not found or coalesce(a.data->>'status', 'pendiente') = 'completada' then return false; end if;
  select * into c from public.e360_campaigns where id = a.campaign_id;
  if not found or c.data->>'status' <> 'activa' then return false; end if;
  update public.e360_assignments
     set data = data || jsonb_build_object('answers', p_answers, 'open', coalesce(p_open, '{}'::jsonb),
                                           'status', 'completada', 'submittedAt', to_char(now() at time zone 'America/Mexico_City', 'YYYY-MM-DD')),
         updated_at = now()
   where id = a.id;
  return true;
end $$;

revoke all on function public.e360_q_get(text) from public;
revoke all on function public.e360_q_submit(text, jsonb, jsonb) from public;
revoke all on function public.e360_assignments_progress() from public;
grant execute on function public.e360_q_get(text) to anon, authenticated;
grant execute on function public.e360_q_submit(text, jsonb, jsonb) to anon, authenticated;
grant execute on function public.e360_assignments_progress() to authenticated;
revoke execute on function public.e360_me_role() from public, anon;
revoke execute on function public.e360_me_org() from public, anon;
revoke execute on function public.e360_is_staff() from public, anon;
revoke execute on function public.e360_rh_sees_reports(text) from public, anon;
grant execute on function public.e360_me_role(), public.e360_me_org(), public.e360_is_staff(), public.e360_rh_sees_reports(text) to authenticated;

-- ---------- Primeros usuarios (admin y coach) ----------
-- Cambia el correo si es otro. Los demás usuarios se agregan desde la plataforma.
insert into public.e360_members (id, email, org_id, data)
values ('u_admin_simon', 'simon@cimaleadership.com.mx', null,
        jsonb_build_object('name', 'Simón Salido', 'email', 'simon@cimaleadership.com.mx', 'role', 'admin'))
on conflict (email) do nothing;
insert into public.e360_members (id, email, org_id, data)
values ('u_coach_marcelo', 'marcelo@cimaleadership.com.mx', null,
        jsonb_build_object('name', 'Marcelo Michel Leaño', 'email', 'marcelo@cimaleadership.com.mx', 'role', 'coach'))
on conflict (email) do nothing;

-- ---------- Permisos de tabla (sólo usuarios con sesión; RLS decide qué filas) ----------
grant usage on schema public to authenticated, anon;
grant select, insert, update, delete on
  public.e360_members, public.e360_orgs, public.e360_people, public.e360_models, public.e360_campaigns,
  public.e360_assignments, public.e360_coaching, public.e360_proposals, public.e360_settings
  to authenticated;
revoke all on
  public.e360_members, public.e360_orgs, public.e360_people, public.e360_models, public.e360_campaigns,
  public.e360_assignments, public.e360_coaching, public.e360_proposals, public.e360_settings
  from anon;
