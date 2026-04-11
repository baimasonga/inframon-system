-- ============================================================================
-- InfraMon — Operational Expansion (Phase 5)
-- Run this in Supabase SQL Editor
-- ============================================================================

-- 1. Project Comments (Discussions)
CREATE TABLE IF NOT EXISTS public.project_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  author_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Risk Register
CREATE TABLE IF NOT EXISTS public.risks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('Weather', 'Contractor', 'Supply Chain', 'Design Change', 'Safety', 'Financial')),
  probability INTEGER DEFAULT 1 CHECK (probability >= 1 AND probability <= 5),
  impact INTEGER DEFAULT 1 CHECK (impact >= 1 AND impact <= 5),
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'mitigated', 'monitoring')),
  mitigation_plan TEXT,
  contingency_plan TEXT,
  owner_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Audit Logs (Anomalies & Security)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  anomaly_type TEXT NOT NULL CHECK (anomaly_type IN ('Duplicate Photo', 'GPS Mismatch', 'Missed Visit', 'Threshold Breach', 'Unauthorized Access')),
  severity TEXT DEFAULT 'Medium' CHECK (severity IN ('Low', 'Medium', 'High', 'Critical')),
  details TEXT,
  clerk_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'Flagged' CHECK (status IN ('Flagged', 'Investigating', 'Resolved', 'Ignored')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Contractor Performance (Metrics)
CREATE TABLE IF NOT EXISTS public.contractor_metrics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contractor_name TEXT UNIQUE NOT NULL,
  timeliness_score INTEGER DEFAULT 0,
  quality_score INTEGER DEFAULT 0,
  compliance_score INTEGER DEFAULT 0,
  responsiveness_score INTEGER DEFAULT 0,
  active_projects INTEGER DEFAULT 0,
  trend TEXT CHECK (trend IN ('up', 'down', 'stable')) DEFAULT 'stable',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Enable RLS ─────────────────────────────────────────────────────────────

ALTER TABLE public.project_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contractor_metrics ENABLE ROW LEVEL SECURITY;

-- ── RLS Policies (Allow authenticated access) ─────────────────────────────

-- Project Comments
CREATE POLICY "Allow authenticated select on comments" ON public.project_comments FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert on comments" ON public.project_comments FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Risks
CREATE POLICY "Allow authenticated select on risks" ON public.risks FOR SELECT USING (true);
CREATE POLICY "Allow admin managed risks" ON public.risks FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'manager'))
);

-- Audit Logs
CREATE POLICY "Allow manager select on audit_logs" ON public.audit_logs FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'manager'))
);

-- Contractor Metrics
CREATE POLICY "Allow authenticated select on contractor_metrics" ON public.contractor_metrics FOR SELECT USING (true);

-- ── Seed Data ──────────────────────────────────────────────────────────────

-- Seed Contractors
INSERT INTO public.contractor_metrics (contractor_name, timeliness_score, quality_score, compliance_score, responsiveness_score, active_projects, trend)
VALUES 
  ('Salone BuildTech Ltd', 92, 88, 95, 90, 4, 'up'),
  ('West Coast Infrastructure', 65, 72, 80, 60, 2, 'down'),
  ('Kenema Construction Corp', 85, 82, 90, 85, 5, 'up');

-- Seed initial risks
INSERT INTO public.risks (project_id, description, category, probability, impact, status, mitigation_plan)
SELECT id, 'Heavy rainfall may halt excavation', 'Weather', 4, 4, 'open', 'Schedule critical work before April'
FROM public.projects WHERE id = 'proj-road-01' LIMIT 1;
