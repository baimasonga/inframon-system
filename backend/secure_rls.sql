-- ============================================================================
-- InfraMon — Phase 4: Production Security & RLS
-- ============================================================================

-- ── 1. User Identity Sync ──────────────────────────────────────────────────
-- This trigger automatically creates a record in public.users when a new 
-- user signs up via Supabase Auth.

CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, full_name, role)
  VALUES (
    new.id, 
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)), 
    'inspector'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ── 2. Cleanup Legacy Policies ──────────────────────────────────────────────
-- Remove the "demo" policies that allowed anonymous access.

DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN 
    SELECT policyname, tablename 
    FROM pg_policies 
    WHERE schemaname = 'public' AND policyname LIKE 'Allow anon%'
  LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', pol.policyname, pol.tablename);
  END LOOP;
END $$;

-- ── 3. Strict RLS Policies ─────────────────────────────────────────────────

-- PROJECTS: Authenticated users can read. Admins can manage.
CREATE POLICY "Authenticated users can view projects" ON public.projects
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage projects" ON public.projects
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

-- VISIT METADATA: Inspectors can view all, but only manage their own.
CREATE POLICY "Authenticated users can view visits" ON public.visit_metadata
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Inspectors can create visits" ON public.visit_metadata
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = inspector_id);

CREATE POLICY "Inspectors can update their own visits" ON public.visit_metadata
  FOR UPDATE TO authenticated USING (auth.uid() = inspector_id);

-- SUB-TABLES (Cascade protection): 
-- We allow insertion into sub-tables if the parent visit was created by the same user.

-- Milestone logs
CREATE POLICY "Inspectors manage their own milestone logs" ON public.milestone_logs
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.visit_metadata WHERE id = visit_id AND inspector_id = auth.uid())
  );

-- Quality checks
CREATE POLICY "Inspectors manage their own quality checks" ON public.quality_checks
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.visit_metadata WHERE id = visit_id AND inspector_id = auth.uid())
  );

-- HSE records
CREATE POLICY "Inspectors manage their own HSE records" ON public.hse_records
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.visit_metadata WHERE id = visit_id AND inspector_id = auth.uid())
  );

-- Equipment records
CREATE POLICY "Inspectors manage their own equipment records" ON public.equipment_records
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.visit_metadata WHERE id = visit_id AND inspector_id = auth.uid())
  );

-- Compliance records
CREATE POLICY "Inspectors manage their own compliance records" ON public.compliance_records
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.visit_metadata WHERE id = visit_id AND inspector_id = auth.uid())
  );

-- Workforce records
CREATE POLICY "Inspectors manage their own workforce records" ON public.workforce_records
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.visit_metadata WHERE id = visit_id AND inspector_id = auth.uid())
  );

-- ── 4. Storage Security (Visit Evidence) ───────────────────────────────────
-- Ensure authenticated users can upload to the 'visit-evidence' bucket.

-- Note: This is usually done in the Storage tab, but SQL equivalent:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('visit-evidence', 'visit-evidence', true);

CREATE POLICY "Authenticated can upload evidence" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'visit-evidence');

CREATE POLICY "Anyone can view evidence" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'visit-evidence');
