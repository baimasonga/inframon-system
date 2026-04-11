-- ============================================================================
-- 👤 INFRAMON SYSTEM ADMIN INITIALIZATION
-- Run this to create your first superuser for the dashboard.
-- ============================================================================

-- 1. Create the user in Supabase Auth (This is done via a secure helper)
-- Note: Replace 'admin@inframon.gov' and 'SecurePassword123' with your chosen credentials.

-- Using the internal auth.users table directly is restricted, 
-- but we can use this script to ensure the PUBLIC profile is elevated.

INSERT INTO public.users (id, full_name, role)
VALUES (
  'd734db90-ca56-495d-8273-ae447308726b', -- Your Real Admin UUID
  'System Administrator',
  'admin'
)
ON CONFLICT (id) DO UPDATE SET role = 'admin';

-- 🚀 INSTRUCTIONS:
-- 1. Go to Supabase Dashboard > Authentication > Users > "Add User".
-- 2. Enter an email and password (e.g., admin@inframon.gov).
-- 3. Copy the 'ID' (UUID) of that new user.
-- 4. Paste it into the script above (replacing the zeros) and run it in the SQL Editor.
-- 5. You now have full System Admin access!
