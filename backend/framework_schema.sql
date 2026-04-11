-- ============================================================================
-- InfraMon — Rural Infrastructure Inspection & Monitoring Framework
-- Database Schema Extension for Sierra Leone Field Engineering Framework
-- ============================================================================

-- Add project_type to projects table
ALTER TABLE public.projects 
ADD COLUMN IF NOT EXISTS project_type TEXT 
CHECK (project_type IN (
  'Feeder Road', 'Building', 'Borehole + Solar', 
  'Bridge / Culvert', 'Grain Store / Drying Floor', 'Public Toilet'
));

ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS contractor_name TEXT;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS estimated_end_date DATE;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS location_lat NUMERIC;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS location_lng NUMERIC;

-- §1 — Visit Metadata
CREATE TABLE IF NOT EXISTS public.visit_metadata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
    inspector_id UUID REFERENCES public.users(id),
    visit_type TEXT NOT NULL CHECK (visit_type IN ('Routine', 'Follow-up', 'Final', 'Emergency')),
    visit_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    gps_lat NUMERIC,
    gps_lng NUMERIC,
    weather TEXT,
    site_supervisor_present BOOLEAN DEFAULT false,
    contractor_name TEXT,
    team_members TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- §4 — Milestone Definitions (predefined per project type, populated on project creation)
CREATE TABLE IF NOT EXISTS public.milestone_definitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
    milestone_name TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,
    planned_completion_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- §4B — Milestone Logs (per visit)
CREATE TABLE IF NOT EXISTS public.milestone_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
    milestone_id UUID REFERENCES public.milestone_definitions(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('Not Started', 'In Progress', 'Completed')),
    completion_pct INTEGER DEFAULT 0 CHECK (completion_pct >= 0 AND completion_pct <= 100),
    date_achieved DATE,
    delay_days INTEGER DEFAULT 0,
    delay_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- §4D — Milestone Evidence
CREATE TABLE IF NOT EXISTS public.milestone_evidence (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    milestone_id UUID REFERENCES public.milestone_definitions(id) ON DELETE CASCADE,
    visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
    file_url TEXT NOT NULL,
    category TEXT CHECK (category IN ('Before', 'After', 'Close-up', 'GPS Proof')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- §4F — Milestone-Linked Actions
CREATE TABLE IF NOT EXISTS public.milestone_actions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    milestone_id UUID REFERENCES public.milestone_definitions(id) ON DELETE CASCADE,
    action_description TEXT NOT NULL,
    responsible_person TEXT,
    deadline DATE,
    follow_up_required BOOLEAN DEFAULT false,
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Resolved', 'Ignored')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- §5 — Quality Checks (per visit)
CREATE TABLE IF NOT EXISTS public.quality_checks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
    check_item TEXT NOT NULL,
    category TEXT,
    pass BOOLEAN NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- §8 — Enhanced Workforce Records (extends existing)
ALTER TABLE public.workforce_records ADD COLUMN IF NOT EXISTS visit_id UUID;
ALTER TABLE public.workforce_records ADD COLUMN IF NOT EXISTS ppe_compliance_pct INTEGER DEFAULT 0;
ALTER TABLE public.workforce_records ADD COLUMN IF NOT EXISTS community_participation TEXT;
ALTER TABLE public.workforce_records ADD COLUMN IF NOT EXISTS local_labor_count INTEGER DEFAULT 0;

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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- §13 — Action Items (Follow-up Tracking)
CREATE TABLE IF NOT EXISTS public.action_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
    project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    responsible_person TEXT,
    deadline DATE,
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Resolved', 'Pending', 'Ignored')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on new tables
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
