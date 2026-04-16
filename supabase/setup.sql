-- =============================================================================
-- InfraMon Supabase Setup — Run once in the Supabase SQL Editor
-- Dashboard: https://supabase.com/dashboard/project/xmkbgqniylgrcudqmkca/sql
-- =============================================================================

-- ── 1. Add missing columns to visit_metadata ────────────────────────────────
ALTER TABLE public.visit_metadata
  ADD COLUMN IF NOT EXISTS overall_progress  INTEGER,
  ADD COLUMN IF NOT EXISTS overall_status    TEXT,
  ADD COLUMN IF NOT EXISTS recommendation    TEXT,
  ADD COLUMN IF NOT EXISTS notes             TEXT;

-- ── 2. Add missing columns to inspection_tasks ──────────────────────────────
ALTER TABLE public.inspection_tasks
  ADD COLUMN IF NOT EXISTS field_notes TEXT,
  ADD COLUMN IF NOT EXISTS gps_lat     NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS gps_lng     NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS updated_at  TIMESTAMPTZ;

-- ── 3. Create attendance_logs table ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.attendance_logs (
  id             TEXT PRIMARY KEY,
  project_id     TEXT,
  inspector_id   TEXT REFERENCES public.users(id) ON DELETE SET NULL,
  check_in_time  TIMESTAMPTZ,
  check_out_time TIMESTAMPTZ,
  total_hours    NUMERIC(5, 2),
  gps_lat        NUMERIC(10, 7),
  gps_lng        NUMERIC(10, 7),
  verified_gps   INTEGER DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.attendance_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users full access" ON public.attendance_logs;
CREATE POLICY "Authenticated users full access"
  ON public.attendance_logs
  USING (auth.role() = 'authenticated');

-- ── 4. Create analysis_results table (AI photo analysis history) ─────────────
CREATE TABLE IF NOT EXISTS public.analysis_results (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id         TEXT REFERENCES public.visit_metadata(id) ON DELETE SET NULL,
  project_id       TEXT,
  image_url        TEXT,
  analysis_payload JSONB,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.analysis_results ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users full access" ON public.analysis_results;
CREATE POLICY "Authenticated users full access"
  ON public.analysis_results
  USING (auth.role() = 'authenticated');

-- ── 5. Create submit_field_report RPC ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_field_report(report JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_visit_id TEXT;
BEGIN
  v_visit_id := (report->>'id')::TEXT;

  -- Upsert core visit record
  INSERT INTO public.visit_metadata (
    id, project_id, inspector_id, visit_type, visit_date,
    weather, site_supervisor_present, gps_lat, gps_lng,
    overall_progress, overall_status, recommendation, notes
  ) VALUES (
    v_visit_id,
    (report->>'project_id')::TEXT,
    (report->>'inspector_id')::TEXT,
    (report->>'visit_type')::TEXT,
    COALESCE(
      (report->>'date_time')::TIMESTAMPTZ,
      (report->>'visit_date')::TIMESTAMPTZ,
      NOW()
    ),
    COALESCE(report->>'weather_condition', report->>'weather'),
    COALESCE((report->>'site_supervisor_present')::BOOLEAN, false),
    (report->>'gps_lat')::NUMERIC,
    (report->>'gps_lng')::NUMERIC,
    (report->>'overall_progress')::INTEGER,
    (report->>'overall_status')::TEXT,
    (report->>'recommendation')::TEXT,
    (report->>'notes')::TEXT
  )
  ON CONFLICT (id) DO UPDATE SET
    overall_progress       = EXCLUDED.overall_progress,
    overall_status         = EXCLUDED.overall_status,
    recommendation         = EXCLUDED.recommendation,
    notes                  = EXCLUDED.notes,
    gps_lat                = EXCLUDED.gps_lat,
    gps_lng                = EXCLUDED.gps_lng;

  -- Insert defects / issues from the report
  IF report->'issues' IS NOT NULL
     AND jsonb_array_length(report->'issues') > 0 THEN
    INSERT INTO public.defect_reports (
      project_id, visit_id, title, category,
      severity, recommended_action, created_at
    )
    SELECT
      (report->>'project_id')::TEXT,
      v_visit_id,
      item->>'title',
      item->>'category',
      item->>'severity',
      COALESCE(item->>'action', item->>'recommended_action'),
      NOW()
    FROM jsonb_array_elements(report->'issues') AS item
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN jsonb_build_object('success', true, 'visit_id', v_visit_id);
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.submit_field_report(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_field_report(JSONB) TO service_role;
