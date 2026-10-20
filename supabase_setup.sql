-- YECO Boshqaruv — Supabase sozlamasi (bir marta ishga tushiriladi)
-- Supabase → SQL Editor → New query → shu matnni qo'yib "Run" bosing.

create extension if not exists pgcrypto;

-- 1. Asosiy jadval
create table if not exists public.yeco (
  col text not null,
  id text not null,
  data jsonb not null,
  updated_at timestamptz default now(),
  primary key (col, id)
);
alter table public.yeco enable row level security;
drop policy if exists "xodimlar" on public.yeco;
create policy "xodimlar" on public.yeco for all to authenticated using (true) with check (true);
alter publication supabase_realtime add table public.yeco;

-- 2. Rasm va video ombori
insert into storage.buckets (id, name, public) values ('media','media', false) on conflict do nothing;
drop policy if exists "media_xodimlar" on storage.objects;
create policy "media_xodimlar" on storage.objects for all to authenticated
  using (bucket_id = 'media') with check (bucket_id = 'media');

-- 3. 12 ta xodim akkaunti (login@yeco.app)
do $$
declare r record; uid uuid;
begin
  for r in select * from (values
    ('shaxzod','Ycvs7qgr'),('hujjat','Yccpm85k'),('sotuv1','Ycesdym7'),('sotuv2','Ycjb29p2'),
    ('usta1','Ycc754bd'),('usta2','Yccxxb9d'),('usta3','Yc66zpz2'),('usta4','Ycrtac3p'),
    ('usta5','Yczh9jxz'),('usta6','Ycdfds6w'),('usta7','Ycs92c7r'),('usta8','Yc3dmqzn')
  ) as t(login, pw)
  loop
    if not exists (select 1 from auth.users where email = r.login || '@yeco.app') then
      uid := gen_random_uuid();
      insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
        confirmation_token, recovery_token, email_change_token_new, email_change)
      values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
        r.login || '@yeco.app', crypt(r.pw, gen_salt('bf')), now(), now(), now(),
        '{"provider":"email","providers":["email"]}', '{}', '', '', '', '');
      insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (gen_random_uuid(), uid, uid::text,
        jsonb_build_object('sub', uid::text, 'email', r.login || '@yeco.app', 'email_verified', true),
        'email', now(), now(), now());
    end if;
  end loop;
end $$;

-- 4. CEO boshqa xodimlar parolini o'zgartira olishi uchun
create or replace function public.admin_set_password(p_login text, p_password text)
returns void language plpgsql security definer set search_path = public, auth, extensions as $$
begin
  if auth.jwt() ->> 'email' <> 'shaxzod@yeco.app' then
    raise exception 'Faqat CEO';
  end if;
  update auth.users set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now()
  where email = lower(p_login) || '@yeco.app';
end $$;
revoke all on function public.admin_set_password(text, text) from public, anon;
grant execute on function public.admin_set_password(text, text) to authenticated;
