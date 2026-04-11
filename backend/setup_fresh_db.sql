-- ============================================================================
-- InfraMon — Fresh Database Setup (Combined Schema)
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/xmkbgqniylgrcudqmkca/sql/new
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Core Tables ─────────────────────────────────────────────────────────────

-- Users (standalone, no auth FK for now)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name TEXT NOT NULL,
  role TEXT CHECK (role IN ('admin', 'manager', 'inspector')) NOT NULL DEFAULT 'inspector',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Projects
CREATE TABLE IF NOT EXISTS public.projects (
  id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
  name TEXT NOT NULL,
  description TEXT,
  type TEXT DEFAULT 'Infrastructure',
  district TEXT,
  status TEXT CHECK (status IN ('Active', 'Completed', 'Suspended')) DEFAULT 'Active',
  completion_percentage INTEGER DEFAULT 0,
  project_type TEXT CHECK (project_type IN (
    'Feeder Road', 'Building', 'Borehole + Solar',
    'Bridge / Culvert', 'Grain Store / Drying Floor', 'Public Toilet'
  )),
  contractor_name TEXT,
  start_date DATE,
  estimated_end_date DATE,
  location_lat NUMERIC,
  location_lng NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inspections (legacy)
CREATE TABLE IF NOT EXISTS public.inspections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  inspector_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  inspection_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT CHECK (status IN ('draft', 'submitted', 'reviewed')) DEFAULT 'draft',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Issues
CREATE TABLE IF NOT EXISTS public.issues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  reported_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
  status TEXT CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')) DEFAULT 'open',
  location_lat NUMERIC,
  location_lng NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Media
CREATE TABLE IF NOT EXISTS public.media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  entity_type TEXT CHECK (entity_type IN ('inspection', 'issue', 'progress')),
  entity_id UUID,
  uploaded_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  file_url TEXT NOT NULL,
  file_type TEXT NOT NULL,
  location_lat NUMERIC,
  location_lng NUMERIC,
  captured_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Timelines
CREATE TABLE IF NOT EXISTS public.timelines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  phase_name TEXT NOT NULL,
  start_date DATE,
  end_date DATE,
  status TEXT CHECK (status IN ('pending', 'active', 'completed', 'delayed')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Milestones (legacy)
CREATE TABLE IF NOT EXISTS public.milestones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  timeline_id UUID REFERENCES public.timelines(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  due_date DATE,
  is_completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workforce Records
CREATE TABLE IF NOT EXISTS public.workforce_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  recorded_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  record_date DATE NOT NULL DEFAULT CURRENT_DATE,
  role_category TEXT NOT NULL,
  gender TEXT CHECK (gender IN ('male', 'female', 'other')),
  is_youth BOOLEAN DEFAULT FALSE,
  count INTEGER DEFAULT 1,
  visit_id UUID,
  ppe_compliance_pct INTEGER DEFAULT 0,
  community_participation TEXT,
  local_labor_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Framework Extension Tables ──────────────────────────────────────────────

-- §1 — Visit Metadata
CREATE TABLE IF NOT EXISTS public.visit_metadata (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  inspector_id UUID REFERENCES public.users(id),
  visit_type TEXT NOT NULL CHECK (visit_type IN ('Routine', 'Follow-up', 'Final', 'Emergency')),
  visit_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  gps_lat NUMERIC,
  gps_lng NUMERIC,
  weather TEXT,
  site_supervisor_present BOOLEAN DEFAULT false,
  contractor_name TEXT,
  team_members TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §2 — Visual Evidence
CREATE TABLE IF NOT EXISTS public.visit_evidence (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_type TEXT CHECK (file_type IN ('photo', 'video', 'drone')),
  category TEXT CHECK (category IN ('Before', 'During', 'After', 'Defect', 'Material', 'Workforce', 'Milestone Proof')),
  caption TEXT,
  gps_lat NUMERIC,
  gps_lng NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §3 — Progress Records
CREATE TABLE IF NOT EXISTS public.progress_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  overall_pct INTEGER DEFAULT 0 CHECK (overall_pct >= 0 AND overall_pct <= 100),
  work_since_last_visit TEXT,
  planned_vs_actual TEXT CHECK (planned_vs_actual IN ('On Schedule', 'Delayed')),
  delay_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §4 — Milestone Definitions
CREATE TABLE IF NOT EXISTS public.milestone_definitions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  milestone_name TEXT NOT NULL,
  sort_order INTEGER DEFAULT 0,
  planned_completion_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §4B — Milestone Logs
CREATE TABLE IF NOT EXISTS public.milestone_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  milestone_id UUID REFERENCES public.milestone_definitions(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('Not Started', 'In Progress', 'Completed')),
  completion_pct INTEGER DEFAULT 0 CHECK (completion_pct >= 0 AND completion_pct <= 100),
  date_achieved DATE,
  delay_days INTEGER DEFAULT 0,
  delay_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §4D — Milestone Evidence
CREATE TABLE IF NOT EXISTS public.milestone_evidence (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  milestone_id UUID REFERENCES public.milestone_definitions(id) ON DELETE CASCADE,
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  category TEXT CHECK (category IN ('Before', 'After', 'Close-up', 'GPS Proof')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §4F — Milestone Actions
CREATE TABLE IF NOT EXISTS public.milestone_actions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  milestone_id UUID REFERENCES public.milestone_definitions(id) ON DELETE CASCADE,
  action_description TEXT NOT NULL,
  responsible_person TEXT,
  deadline DATE,
  follow_up_required BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Resolved', 'Ignored')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §5 — Quality Checks
CREATE TABLE IF NOT EXISTS public.quality_checks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  check_item TEXT NOT NULL,
  category TEXT,
  pass BOOLEAN NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §6 — Materials Records
CREATE TABLE IF NOT EXISTS public.materials_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  material_name TEXT NOT NULL,
  status TEXT CHECK (status IN ('Good', 'Acceptable', 'Substandard', 'Expired', 'Not Checked')),
  notes TEXT,
  testing_evidence_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §7 — Defect Reports
CREATE TABLE IF NOT EXISTS public.defect_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  category TEXT CHECK (category IN ('Structural defects', 'Poor workmanship', 'Safety hazards', 'Environmental risks', 'Design deviations')),
  severity TEXT CHECK (severity IN ('Low', 'Medium', 'High', 'Critical')),
  recommended_action TEXT,
  responsible_party TEXT,
  deadline DATE,
  status TEXT DEFAULT 'Open' CHECK (status IN ('Open', 'Under Review', 'Resolved', 'Closed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §9 — Equipment Records
CREATE TABLE IF NOT EXISTS public.equipment_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  machinery_available TEXT,
  equipment_condition TEXT,
  fuel_availability TEXT CHECK (fuel_availability IN ('Adequate', 'Low', 'Critical', 'None')),
  work_stoppages TEXT,
  logistics_issues TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §10 — HSE Records
CREATE TABLE IF NOT EXISTS public.hse_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  ppe_usage_pct INTEGER DEFAULT 0,
  first_aid_available BOOLEAN DEFAULT false,
  incident_reports TEXT,
  waste_management TEXT,
  environmental_protection TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §11 — Community Feedback
CREATE TABLE IF NOT EXISTS public.community_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  satisfaction_level TEXT CHECK (satisfaction_level IN ('Very Satisfied', 'Satisfied', 'Neutral', 'Dissatisfied', 'Very Dissatisfied')),
  complaints TEXT,
  land_disputes TEXT,
  social_inclusion_issues TEXT,
  local_authority_feedback TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §12 — Compliance Records
CREATE TABLE IF NOT EXISTS public.compliance_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  approved_drawings_on_site BOOLEAN DEFAULT false,
  work_permits_valid BOOLEAN DEFAULT false,
  inspection_approvals_current BOOLEAN DEFAULT false,
  contractor_reports_submitted BOOLEAN DEFAULT false,
  previous_issues_resolved BOOLEAN DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- §13 — Action Items
CREATE TABLE IF NOT EXISTS public.action_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  responsible_person TEXT,
  deadline DATE,
  status TEXT DEFAULT 'Pending' CHECK (status IN ('Resolved', 'Pending', 'Ignored')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- §14 — Inspector Summaries
CREATE TABLE IF NOT EXISTS public.inspector_summaries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
  overall_status TEXT CHECK (overall_status IN ('Good', 'Fair', 'Poor')),
  key_achievements TEXT,
  milestones_reached TEXT,
  delays_and_risks TEXT,
  critical_issues TEXT,
  required_actions TEXT,
  recommendation TEXT CHECK (recommendation IN ('Continue work', 'Proceed with caution', 'Stop work')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── RLS (enable but allow anon read/write for demo) ─────────────────────────

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workforce_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visit_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visit_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.milestone_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.milestone_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.milestone_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.milestone_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quality_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.defect_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hse_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.action_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspector_summaries ENABLE ROW LEVEL SECURITY;

-- ── Open RLS Policies (Allow anon access for demo — restrict later) ─────────

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN
    SELECT unnest(ARRAY[
      'users','projects','inspections','issues','media','timelines','milestones',
      'workforce_records','visit_metadata','visit_evidence','progress_records',
      'milestone_definitions','milestone_logs','milestone_evidence','milestone_actions',
      'quality_checks','materials_records','defect_reports','equipment_records',
      'hse_records','community_feedback','compliance_records','action_items','inspector_summaries'
    ])
  LOOP
    EXECUTE format('CREATE POLICY "Allow anon select on %I" ON public.%I FOR SELECT USING (true)', tbl, tbl);
    EXECUTE format('CREATE POLICY "Allow anon insert on %I" ON public.%I FOR INSERT WITH CHECK (true)', tbl, tbl);
    EXECUTE format('CREATE POLICY "Allow anon update on %I" ON public.%I FOR UPDATE USING (true)', tbl, tbl);
    EXECUTE format('CREATE POLICY "Allow anon delete on %I" ON public.%I FOR DELETE USING (true)', tbl, tbl);
  END LOOP;
END $$;

-- ── Seed Data ───────────────────────────────────────────────────────────────

-- Seed user
INSERT INTO public.users (id, full_name, role) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Eng. Mohamed Kamara', 'inspector'),
  ('a0000000-0000-0000-0000-000000000002', 'Eng. Aminata Sesay', 'inspector'),
  ('a0000000-0000-0000-0000-000000000003', 'Eng. Ibrahim Koroma', 'inspector'),
  ('a0000000-0000-0000-0000-000000000004', 'Admin User', 'admin');

-- Seed projects
INSERT INTO public.projects (id, name, type, district, status, completion_percentage, project_type, contractor_name) VALUES
  ('proj-road-01', 'Moyamba–Njala Feeder Road', 'Infrastructure', 'Moyamba', 'Active', 48, 'Feeder Road', 'Salone BuildTech Ltd'),
  ('proj-bh-01', 'Kailahun Water Supply Borehole', 'Infrastructure', 'Kailahun', 'Active', 72, 'Borehole + Solar', 'Kenema Construction Corp'),
  ('proj-bldg-01', 'Bo District Health Centre', 'Infrastructure', 'Bo', 'Active', 35, 'Building', 'West Coast Infrastructure');
