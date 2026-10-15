# คู่มือการตั้งค่า Supabase และการนำขึ้น GitHub Pages (SUPABASE_SETUP.md)
## ระบบออกใบเสร็จรับเงิน มหาวิทยาลัยเทคโนโลยีราชมงคลสุวรรณภูมิ

เอกสารฉบับนี้อธิบายขั้นตอนการตั้งค่าฐานข้อมูลกลางด้วย **Supabase** เพื่อให้ระบบออกใบเสร็จรับเงินสามารถใช้งานพร้อมกันได้หลายเครื่อง หลายผู้ใช้งานแบบ Real-time พร้อมระบบล็อกเลขที่ใบเสร็จอัตโนมัติป้องกันเลขซ้ำ

---

## ส่วนที่ 1: การสร้างโปรเจกต์และการรันฐานข้อมูล (Database & RPC Setup)

1. เข้าไปที่เว็บไซต์ [https://supabase.com](https://supabase.com) และเข้าสู่ระบบ
2. กดปุ่ม **New Project** ตั้งชื่อโปรเจกต์ เช่น `rmutsb-receipt-system` ตั้งรหัสผ่านฐานข้อมูล และเลือก Region เป็น `Southeast Asia (Singapore)` จากนั้นรอสร้างโปรเจกต์ประมาณ 1–2 นาที
3. ไปที่เมนูด้านซ้าย เลือก **SQL Editor** -> กด **New query**
4. เปิดไฟล์ `supabase/schema.sql` ในโปรเจกต์นี้ คัดลอกคำสั่ง SQL ทั้งหมดไปวางในหน้าต่าง SQL Editor แล้วกดปุ่ม **Run**
   - ระบบจะสร้างตาราง `public.profiles` และ `public.app_state`
   - ตั้งค่า Row Level Security (RLS)
   - สร้างฟังก์ชัน RPC `public.issue_receipt(p_receipt jsonb)` และ `public.cancel_receipt(p_receipt_id text, p_reason text)` แบบ `SECURITY DEFINER` ที่ล็อกแถวด้วย `FOR UPDATE` เพื่อป้องกันเลขใบเสร็จซ้ำเมื่อออกพร้อมกันหลายคน
   - เพิ่มข้อมูลตั้งต้น (คำนำหน้าชื่อ, รายการชำระเงิน, โครงการ, ธนาคาร, และเล่มใบเสร็จเริ่มต้น)

---

## ส่วนที่ 2: การสร้างบัญชีผู้ใช้งานและกำหนดสิทธิ์ (Authentication & Profiles)

เนื่องจากระบบใช้งานจริงบังคับการเข้าสู่ระบบด้วย **Email และ Password** จาก Supabase Authentication และตรวจสอบสิทธิ์จากตาราง `profiles` (ห้ามใช้รหัสผ่านตัวอย่าง):

1. ไปที่เมนู **Authentication** -> **Providers** -> ตรวจสอบว่าเปิดใช้งาน **Email** แล้ว (แนะนำให้ปิด *Confirm email* ในเมนู Auth Settings หากต้องการสร้างบัญชีให้เจ้าหน้าที่ใช้งานได้ทันทีโดยไม่ต้องกดลิงก์ยืนยันในอีเมล)
2. ไปที่เมนู **Authentication** -> **Users** -> กดปุ่ม **Add user** -> **Create new user**
   - สร้างบัญชีสำหรับ **Admin** (เช่น `admin@rmutsb.ac.th`) และตั้งรหัสผ่าน
   - สร้างบัญชีสำหรับ **เจ้าหน้าที่ (User)** (เช่น `finance01@rmutsb.ac.th`, `auditor01@rmutsb.ac.th`) และตั้งรหัสผ่าน
3. คัดลอก `User UID` ของผู้ใช้ที่สร้าง ไปเพิ่มสิทธิ์ในตาราง `public.profiles` โดยรันคำสั่งใน **SQL Editor** ดังนี้:

```sql
-- 1. กำหนดสิทธิ์ให้บัญชี Admin (จัดการได้ทุกอย่าง: เจ้าหน้าที่, เมนูระบบ, เล่มใบเสร็จ, รายงาน)
insert into public.profiles (user_id, email, role, permission_level, display_name, staff_code, position, active)
values (
  'ใส่-UUID-ของ-ADMIN-ที่นี่',
  'admin@rmutsb.ac.th',
  'admin',
  'full',
  'ผู้ดูแลระบบการเงิน มทร.สุวรรณภูมิ',
  'ADM001',
  'นักวิชาการเงินและบัญชีชำนาญการ',
  true
)
on conflict (user_id) do update
set role = 'admin', permission_level = 'full', active = true;

-- 2. กำหนดสิทธิ์ให้เจ้าหน้าที่ออกใบเสร็จ (บันทึกผู้ชำระเงิน, ออกใบเสร็จ, พิมพ์ใบเสร็จ, ยกเลิกใบเสร็จตามสิทธิ์)
insert into public.profiles (user_id, email, role, permission_level, display_name, staff_code, position, active)
values (
  'ใส่-UUID-ของ-USER-ที่นี่',
  'finance01@rmutsb.ac.th',
  'user',
  'issuer',
  'ปริญญา',
  'STF001',
  'นักวิชาการเงินและบัญชีชำนาญการ',
  true
)
on conflict (user_id) do update
set role = 'user', permission_level = 'issuer', active = true;

-- 3. (ทางเลือก) กำหนดสิทธิ์เจ้าหน้าที่สำหรับเรียกดู/ดาวน์โหลด/สั่งพิมพ์ใบเสร็จอย่างเดียว (ห้ามลบ/เพิ่ม/แก้ไข)
insert into public.profiles (user_id, email, role, permission_level, display_name, staff_code, position, active)
values (
  'ใส่-UUID-ของ-VIEWER-ที่นี่',
  'auditor01@rmutsb.ac.th',
  'user',
  'viewer',
  'เจ้าหน้าที่ตรวจสอบการเงิน',
  'AUD001',
  'นักวิชาการตรวจสอบภายใน',
  true
)
on conflict (user_id) do update
set role = 'user', permission_level = 'viewer', active = true;
```

> **หมายเหตุ:** หลังจากสร้าง Admin คนแรกแล้ว Admin สามารถเข้าสู่ระบบผ่านหน้าเว็บไซต์ไปที่เมนู **"ผู้ใช้งาน"** เพื่อเพิ่ม/แก้ไขชื่อผู้ใช้งาน กำหนดรหัสเจ้าหน้าที่ (`staff_code`) กำหนดสิทธิ์ย่อย และเปิด/ปิดสถานะ (`active`) ได้จากหน้าเว็บทันที

---

## ส่วนที่ 3: การนำค่า URL และ Anon Key มาใส่ในโปรเจกต์

1. ใน Supabase Dashboard ไปที่ **Project Settings (รูปฟันเฟือง)** -> **API**
2. คัดลอกค่า 2 ค่าดังนี้:
   - **Project URL** (เช่น `https://abcdefghijklm.supabase.co`)
   - **Project API Keys -> `anon` `public`**
3. เปิดไฟล์ `supabase-config.js` แล้วนำค่าไปวางในตัวแปร:
   ```javascript
   const DEFAULT_SUPABASE_URL = "https://abcdefghijklm.supabase.co";
   const DEFAULT_SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...";
   ```
   *(หรือสามารถกดปุ่ม **"ตั้งค่าฐานข้อมูล Supabase"** ที่มุมขวาบนของหน้าแรกเว็บไซต์เพื่อบันทึกค่าลงในเบราว์เซอร์ได้ทันที)*

---

## ส่วนที่ 4: การนำขึ้นใช้งานจริงบน GitHub Pages

1. สร้าง Repository ใหม่บน GitHub (เช่น `rmutsb-receipt-system`)
2. อัปโหลดไฟล์ทั้งหมดในโปรเจกต์ขึ้นไปที่ Branch `main`:
   - `index.html`
   - `supabase-config.js`
   - `supabase/schema.sql`
   - `assets/garuda.png`
   - `assets/rmutsb-logo.png`
   - `assets/rmutsb-banner.png`
   - `README.md`
   - `SUPABASE_SETUP.md`
   - `.gitignore`
3. ไปที่เมนู **Settings** ของ Repository บน GitHub -> เลือกเมนู **Pages** ด้านซ้าย
4. ในหัวข้อ **Build and deployment**:
   - **Source**: เลือก `Deploy from a branch`
   - **Branch**: เลือก `main` และโฟลเดอร์ `/ (root)` แล้วกด **Save**
5. รอประมาณ 1 นาที เว็บไซต์จะพร้อมใช้งานที่ `https://<ชื่อผู้ใช้-github>.github.io/<ชื่อ-repo>/`
