-- ============================================================================
-- InfraMon — Phase 7: Governance & Scoped User Management
-- ============================================================================

-- 1. Extend Users with Territory and Purview
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS assigned_districts TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS assigned_chiefdoms TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS specializations TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- 2. Extend Projects with Community Context
ALTER TABLE public.projects 
ADD COLUMN IF NOT EXISTS chiefdom TEXT,
ADD COLUMN IF NOT EXISTS community TEXT;

-- 3. Project Assignments (Explicit Junction Table)
CREATE TABLE IF NOT EXISTS public.project_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES public.users(id),
    role_on_project TEXT CHECK (role_on_project IN ('Lead Inspector', 'Support', 'Auditor')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_id, user_id)
);

-- 4. Inspection Tasks (Engineering Instructions)
CREATE TABLE IF NOT EXISTS public.inspection_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
    assignee_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    creator_id UUID REFERENCES public.users(id),
    title TEXT NOT NULL,
    description TEXT,
    deadline DATE,
    priority TEXT CHECK (priority IN ('Normal', 'High', 'Urgent')) DEFAULT 'Normal',
    status TEXT CHECK (status IN ('Pending', 'In Progress', 'Completed', 'Flagged')) DEFAULT 'Pending',
    completion_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── RLS UPDATES ────────────────────────────────────────────────────────────

-- Note: We first drop existing policies before re-creating the restricted versions
DROP POLICY IF EXISTS "Authenticated users can view projects" ON public.projects;

-- PROJECT VISIBILITY: 
-- 1. Anyone in the assigned district can SEE the project.
-- 2. Admin/Manager can see all.
CREATE POLICY "Scoped project visibility" ON public.projects
FOR SELECT TO authenticated USING (
    role IN ('admin', 'manager') OR
    district = ANY(
        SELECT unnest(assigned_districts) 
        FROM public.users 
        WHERE id = auth.uid()
    ) OR
    EXISTS (
        SELECT 1 FROM public.project_assignments 
        WHERE project_id = projects.id AND user_id = auth.uid()
    )
);

-- VISIT PERMISSION (REPORTING PURVIEW):
-- Only allowed if project type matches specialization OR explicit assignment exists
ALTER TABLE public.visit_metadata ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Inspectors can create visits" ON public.visit_metadata;

CREATE POLICY "Restricted field reporting" ON public.visit_metadata
FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = inspector_id AND (
        EXISTS (
            SELECT 1 FROM public.projects p
            JOIN public.users u ON u.id = auth.uid()
            WHERE p.id = project_id 
            AND (
                p.project_type = ANY(u.specializations) OR
                EXISTS (SELECT 1 FROM public.project_assignments pa WHERE pa.project_id = p.id AND pa.user_id = u.id)
            )
        )
    )
);

-- RLS for Assignments & Tasks
ALTER TABLE public.project_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own assignments" ON public.project_assignments
FOR SELECT TO authenticated USING (user_id = auth.uid() OR assigned_by = auth.uid());

CREATE POLICY "Users can view their tasks" ON public.inspection_tasks
FOR SELECT TO authenticated USING (assignee_id = auth.uid() OR creator_id = auth.uid());

CREATE POLICY "Admins manage assignments" ON public.project_assignments 
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'manager')));

CREATE POLICY "Engineers manage tasks" ON public.inspection_tasks 
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'manager')));
