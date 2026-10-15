-- ============================================================================
-- ระบบออกใบเสร็จรับเงิน มหาวิทยาลัยเทคโนโลยีราชมงคลสุวรรณภูมิ (RMUTSB Receipt System)
-- Supabase Database Schema, RLS Policies, Triggers & Atomic RPC Functions
-- ============================================================================

-- เปิดใช้งาน Extension สำหรับสร้าง UUID
create extension if not exists "pgcrypto";

-- ============================================================================
-- 1. ตาราง profiles สำหรับเก็บสิทธิ์และข้อมูลผู้ใช้งาน (ผูกกับ auth.users)
-- ============================================================================
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text default '',
  role text not null default 'user' check (role in ('admin', 'user')),
  permission_level text not null default 'issuer' check (permission_level in ('full', 'issuer', 'viewer')),
  display_name text not null,
  staff_code text not null default '',
  position text not null default 'นักวิชาการเงินและบัญชีชำนาญการ',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ฟังก์ชันและ Trigger อัปเดตเวลา updated_at อัตโนมัติ
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- ============================================================================
-- 2. ตาราง app_state สำหรับเก็บข้อมูลระบบกลางแบบ JSONB
-- ============================================================================
create table if not exists public.app_state (
  id text primary key default 'main',
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_app_state_updated_at on public.app_state;
create trigger trg_app_state_updated_at
before update on public.app_state
for each row execute function public.set_updated_at();

-- ข้อมูลตั้งต้น (Seed Data) สำหรับ app_state แถว 'main'
insert into public.app_state (id, data, updated_at)
values (
  'main',
  jsonb_build_object(
    'officeInfo', jsonb_build_object(
      'universityName', 'มหาวิทยาลัยเทคโนโลยีราชมงคลสุวรรณภูมิ',
      'universityNameEn', 'Rajamangala University of Technology Suvarnabhumi',
      'headerSubTitle', 'ในราชการมหาวิทยาลัยเทคโนโลยีราชมงคลสุวรรณภูมิ',
      'officeAddress', 'หันตรา เลขที่ 60 หมู่ 3 ต.หันตรา อ.พระนครศรีอยุธยา จ.พระนครศรีอยุธยา 13000',
      'defaultSignerName', 'นางสาวอภิญญา สกุลพราหมณ์',
      'defaultPosition', 'นักวิชาการเงินและบัญชีชำนาญการ',
      'defaultActingPosition', 'รักษาการในตำแหน่งผู้อำนวยการกองคลัง',
      'showSignature', true
    ),
    'admin', jsonb_build_object(
      'systemName', 'ระบบออกใบเสร็จรับเงิน มหาวิทยาลัยเทคโนโลยีราชมงคลสุวรรณภูมิ',
      'allowDecimalInReceipt', true
    ),
    'users', '[]'::jsonb,
    'titles', jsonb_build_array(
      'นาย',
      'นาง',
      'นางสาว',
      'ดร.',
      'ผู้ช่วยศาสตราจารย์',
      'รองศาสตราจารย์',
      'ศาสตราจารย์',
      'ผศ.ดร.',
      'รศ.ดร.'
    ),
    'paymentItems', jsonb_build_array(
      'ค่าลงทะเบียน',
      'ค่าธรรมเนียม',
      'ค่าธรรมเนียมแรกเข้า',
      'ค่าบำรุงการศึกษา',
      'ค่าปรับ',
      'ค่าเอกสาร'
    ),
    'projects', jsonb_build_array(
      jsonb_build_object('id', 'proj-none', 'name', 'ไม่ระบุโครงการ', 'active', true),
      jsonb_build_object('id', 'proj-1', 'name', 'ภาคเรียนที่ 1 ปีการศึกษา 2570', 'active', true),
      jsonb_build_object('id', 'proj-2', 'name', 'โครงการฝึกอบรม หลักสูตร "เชิงปฏิบัติการ ฉบับจับมือทำด้วยระบบ AI สำหรับการบริหารจัดการยุคดิจิทัล"', 'active', true),
      jsonb_build_object('id', 'proj-3', 'name', 'โครงการอบรมเชิงปฏิบัติการพัฒนาทักษะวิชาชีพ', 'active', true)
    ),
    'payerBanks', jsonb_build_array(
      'ธนาคารกรุงไทย',
      'ธนาคารกสิกรไทย',
      'ธนาคารกรุงเทพ',
      'ธนาคารไทยพาณิชย์',
      'ธนาคารกรุงศรีอยุธยา',
      'ธนาคารทหารไทยธนชาต (ttb)',
      'ธนาคารออมสิน',
      'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร (ธ.ก.ส.)'
    ),
    'universityBanks', jsonb_build_array(
      jsonb_build_object(
        'id', 'ubank-1',
        'bankName', 'ธนาคารกรุงไทย',
        'accountName', 'มหาวิทยาลัยเทคโนโลยีราชมงคลสุวรรณภูมิ',
        'accountNo', '101-0-XXXXX-X'
      ),
      jsonb_build_object(
        'id', 'ubank-2',
        'bankName', 'ธนาคารกสิกรไทย',
        'accountName', 'มทร.สุวรรณภูมิ (รายได้มหาวิทยาลัย)',
        'accountNo', '202-2-XXXXX-X'
      )
    ),
    'books', jsonb_build_array(
      jsonb_build_object(
        'id', 'book-1',
        'bookNo', 'AN704001',
        'start', 1,
        'end', 100,
        'latest', 0,
        'digits', 3,
        'active', true,
        'closed', false,
        'createdAt', now()
      ),
      jsonb_build_object(
        'id', 'book-2',
        'bookNo', 'RUS69001',
        'start', 1,
        'end', 100,
        'latest', 0,
        'digits', 3,
        'active', false,
        'closed', false,
        'createdAt', now()
      )
    ),
    'receipts', '[]'::jsonb
  ),
  now()
)
on conflict (id) do nothing;

-- ============================================================================
-- 3. ตั้งค่า Row Level Security (RLS)
-- ============================================================================
alter table public.profiles enable row level security;
alter table public.app_state enable row level security;

-- Helper function ตรวจสอบว่าผู้ใช้ปัจจุบันเป็น Admin และ Active หรือไม่
create or replace function public.is_active_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where user_id = auth.uid()
      and role = 'admin'
      and active = true
  );
$$;

-- Helper function ตรวจสอบว่าผู้ใช้ปัจจุบัน Active หรือไม่
create or replace function public.is_active_user()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where user_id = auth.uid()
      and active = true
  );
$$;

-- Policies สำหรับตาราง profiles
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);

drop policy if exists "profiles_insert_admin" on public.profiles;
create policy "profiles_insert_admin"
on public.profiles
for insert
to authenticated
with check (public.is_active_admin() or auth.uid() = user_id);

drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin"
on public.profiles
for update
to authenticated
using (public.is_active_admin() or auth.uid() = user_id)
with check (public.is_active_admin() or auth.uid() = user_id);

drop policy if exists "profiles_delete_admin" on public.profiles;
create policy "profiles_delete_admin"
on public.profiles
for delete
to authenticated
using (public.is_active_admin());

-- Policies สำหรับตาราง app_state
drop policy if exists "app_state_select_authenticated" on public.app_state;
create policy "app_state_select_authenticated"
on public.app_state
for select
to authenticated
using (true);

drop policy if exists "app_state_insert_authenticated" on public.app_state;
create policy "app_state_insert_authenticated"
on public.app_state
for insert
to authenticated
with check (public.is_active_user());

drop policy if exists "app_state_update_authenticated" on public.app_state;
create policy "app_state_update_authenticated"
on public.app_state
for update
to authenticated
using (public.is_active_user())
with check (public.is_active_user());

-- ============================================================================
-- 4. RPC Function: issue_receipt(p_receipt jsonb)
-- ออกเลขใบเสร็จอัตโนมัติแบบ Atomic (FOR UPDATE lock) ป้องกันเลขซ้ำเมื่อออกพร้อมกันหลายคน
-- ============================================================================
create or replace function public.issue_receipt(p_receipt jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_profile public.profiles%rowtype;
  v_state jsonb;
  v_books jsonb;
  v_receipts jsonb;
  v_book jsonb;
  v_active_idx int := -1;
  v_i int;
  v_start int;
  v_end int;
  v_latest int;
  v_next int;
  v_digits int;
  v_book_no text;
  v_receipt_no text;
  v_new_receipt jsonb;
  v_updated_books jsonb := '[]'::jsonb;
begin
  -- 1. ตรวจสอบว่าผู้ใช้ Login แล้ว
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'กรุณาเข้าสู่ระบบก่อนออกใบเสร็จ';
  end if;

  -- 2. ตรวจสอบสิทธิ์และสถานะ Active จากตาราง profiles
  select * into v_profile
  from public.profiles
  where user_id = v_uid;

  if not found then
    raise exception 'บัญชีนี้ยังไม่ได้กำหนดสิทธิ์ในตาราง profiles';
  end if;

  if v_profile.active is false then
    raise exception 'บัญชีผู้ใช้งานของคุณถูกปิดการใช้งาน ไม่สามารถออกใบเสร็จได้';
  end if;

  if v_profile.permission_level = 'viewer' and v_profile.role <> 'admin' then
    raise exception 'บัญชีเจ้าหน้าที่ของคุณมีสิทธิ์สำหรับเรียกดูและพิมพ์ใบเสร็จเท่านั้น ไม่สามารถออกใบเสร็จใหม่ได้';
  end if;

  -- 3. ล็อกแถว app_state ('main') ด้วย FOR UPDATE เพื่อป้องกัน Race Condition / เลขซ้ำ
  select data into v_state
  from public.app_state
  where id = 'main'
  for update;

  if v_state is null then
    raise exception 'ไม่พบข้อมูลตั้งต้นของระบบ (app_state)';
  end if;

  v_books := coalesce(v_state->'books', '[]'::jsonb);
  v_receipts := coalesce(v_state->'receipts', '[]'::jsonb);

  -- 4. ค้นหาเล่มใบเสร็จที่ active = true และ closed = false
  for v_i in 0 .. jsonb_array_length(v_books) - 1 loop
    v_book := v_books->v_i;
    if coalesce((v_book->>'active')::boolean, false) = true
       and coalesce((v_book->>'closed')::boolean, false) = false then
      v_active_idx := v_i;
      exit;
    end if;
  end loop;

  if v_active_idx = -1 then
    raise exception 'ไม่พบเล่มใบเสร็จที่เปิดใช้งาน (Active) กรุณาแจ้ง Admin ให้เปิดใช้งานเล่มใบเสร็จ';
  end if;

  v_book := v_books->v_active_idx;
  v_book_no := v_book->>'bookNo';
  v_start := coalesce((v_book->>'start')::int, 1);
  v_end := coalesce((v_book->>'end')::int, 100);
  v_latest := coalesce((v_book->>'latest')::int, 0);
  v_digits := greatest(coalesce((v_book->>'digits')::int, 3), 3);

  -- 5. คำนวณเลขใบเสร็จถัดไป
  if v_latest < v_start then
    v_next := v_start;
  else
    v_next := v_latest + 1;
  end if;

  -- ตรวจสอบว่าเกินเลขสิ้นสุดของเล่มหรือไม่
  if v_next > v_end then
    raise exception 'เลขที่ใบเสร็จในเล่ม % ครบจำนวนแล้ว (% / %) กรุณาแจ้ง Admin เพื่อเปลี่ยนเล่มใบเสร็จใหม่', v_book_no, v_latest, v_end;
  end if;

  v_receipt_no := lpad(v_next::text, v_digits, '0');

  -- ตรวจสอบซ้ำอีกครั้งใน receipts ว่าไม่มี (bookNo, no) ซ้ำ
  while exists (
    select 1
    from jsonb_array_elements(v_receipts) as r
    where r->>'bookNo' = v_book_no
      and r->>'no' = v_receipt_no
  ) loop
    v_next := v_next + 1;
    if v_next > v_end then
      raise exception 'เลขที่ใบเสร็จในเล่ม % ครบจำนวนแล้ว กรุณาเปลี่ยนเล่มใหม่', v_book_no;
    end if;
    v_receipt_no := lpad(v_next::text, v_digits, '0');
  end loop;

  -- 6. สร้างข้อมูลใบเสร็จใหม่พร้อมเลขที่ใบเสร็จที่ได้
  v_new_receipt := p_receipt || jsonb_build_object(
    'id', coalesce(p_receipt->>'id', 'rcp-' || extract(epoch from clock_timestamp())::bigint::text || '-' || floor(random()*1000)::int::text),
    'bookNo', v_book_no,
    'no', v_receipt_no,
    'status', 'ปกติ',
    'cancelReason', '',
    'issuerId', v_uid::text,
    'issuerName', coalesce(nullif(p_receipt->>'issuerName', ''), v_profile.display_name),
    'issuerStaffCode', coalesce(nullif(p_receipt->>'issuerStaffCode', ''), v_profile.staff_code),
    'issuerPosition', coalesce(nullif(p_receipt->>'issuerPosition', ''), v_profile.position),
    'createdAt', now()
  );

  -- 7. อัปเดต latest ในเล่มใบเสร็จ
  for v_i in 0 .. jsonb_array_length(v_books) - 1 loop
    if v_i = v_active_idx then
      v_updated_books := v_updated_books || jsonb_build_array(
        (v_books->v_i) || jsonb_build_object('latest', v_next)
      );
    else
      v_updated_books := v_updated_books || jsonb_build_array(v_books->v_i);
    end if;
  end loop;

  -- 8. เพิ่มใบเสร็จใหม่เข้าสู่รายการ receipts (เรียงใบใหม่ล่าสุดไว้บนสุด)
  v_receipts := jsonb_build_array(v_new_receipt) || v_receipts;

  v_state := v_state || jsonb_build_object(
    'books', v_updated_books,
    'receipts', v_receipts
  );

  update public.app_state
  set data = v_state,
      updated_at = now()
  where id = 'main';

  return jsonb_build_object(
    'receipt', v_new_receipt,
    'state', v_state
  );
end;
$$;

-- ============================================================================
-- 5. RPC Function: cancel_receipt(p_receipt_id text, p_reason text)
-- ยกเลิกใบเสร็จและบันทึกเหตุผลการยกเลิกแบบ Atomic
-- ============================================================================
create or replace function public.cancel_receipt(p_receipt_id text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_profile public.profiles%rowtype;
  v_state jsonb;
  v_receipts jsonb;
  v_updated_receipts jsonb := '[]'::jsonb;
  v_r jsonb;
  v_found boolean := false;
  v_i int;
begin
  -- 1. ตรวจสอบว่าผู้ใช้ Login แล้ว
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'กรุณาเข้าสู่ระบบก่อนยกเลิกใบเสร็จ';
  end if;

  select * into v_profile
  from public.profiles
  where user_id = v_uid;

  if not found or v_profile.active is false then
    raise exception 'บัญชีผู้ใช้งานไม่มีสิทธิ์หรือถูกระงับการใช้งาน';
  end if;

  if v_profile.permission_level = 'viewer' and v_profile.role <> 'admin' then
    raise exception 'บัญชีเจ้าหน้าที่ของคุณมีสิทธิ์เรียกดูและพิมพ์ใบเสร็จเท่านั้น ไม่สามารถยกเลิกใบเสร็จได้';
  end if;

  -- 2. ตรวจสอบเหตุผลการยกเลิก
  if trim(coalesce(p_reason, '')) = '' then
    raise exception 'กรุณาระบุเหตุผลการยกเลิกใบเสร็จ';
  end if;

  -- 3. ล็อกแถว app_state ('main')
  select data into v_state
  from public.app_state
  where id = 'main'
  for update;

  v_receipts := coalesce(v_state->'receipts', '[]'::jsonb);

  -- 4. ค้นหาและเปลี่ยนสถานะเป็น "ยกเลิก"
  for v_i in 0 .. jsonb_array_length(v_receipts) - 1 loop
    v_r := v_receipts->v_i;
    if (v_r->>'id') = p_receipt_id
       or ((v_r->>'bookNo') || ':' || (v_r->>'no')) = p_receipt_id then
      v_found := true;
      v_r := v_r || jsonb_build_object(
        'status', 'ยกเลิก',
        'cancelReason', trim(p_reason),
        'cancelledAt', now(),
        'cancelledBy', v_profile.display_name
      );
    end if;
    v_updated_receipts := v_updated_receipts || jsonb_build_array(v_r);
  end loop;

  if not v_found then
    raise exception 'ไม่พบใบเสร็จที่ต้องการยกเลิก (% )', p_receipt_id;
  end if;

  v_state := v_state || jsonb_build_object('receipts', v_updated_receipts);

  update public.app_state
  set data = v_state,
      updated_at = now()
  where id = 'main';

  return jsonb_build_object('state', v_state);
end;
$$;

-- กำหนดสิทธิ์ให้ authenticated เรียกใช้งาน RPC ได้
grant execute on function public.issue_receipt(jsonb) to authenticated;
grant execute on function public.cancel_receipt(text, text) to authenticated;

-- เปิดใช้งาน Realtime บนตาราง app_state และ profiles
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'app_state'
  ) then
    alter publication supabase_realtime add table public.app_state;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
exception when others then
  null;
end $$;
