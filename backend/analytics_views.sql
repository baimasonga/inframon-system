-- ============================================================================
-- InfraMon — Phase 8: Intelligent Reporting & Aggregation
-- ============================================================================

-- 1. Table for Persisting AI Analysis Results (Bridging Vision API to Dashboard)
CREATE TABLE IF NOT EXISTS public.visit_ai_analysis (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    visit_id UUID REFERENCES public.visit_metadata(id) ON DELETE CASCADE,
    evidence_id UUID REFERENCES public.visit_evidence(id) ON DELETE CASCADE,
    project_id TEXT REFERENCES public.projects(id),
    
    -- AI Findings
    category TEXT, -- e.g. 'Structural', 'Foundation', 'Material'
    completion_pct INTEGER, -- AI estimated progress
    detected_defects TEXT[], -- List of issues found by AI
    confidence_score NUMERIC,
    raw_analysis_json JSONB,
    
    is_flagged BOOLEAN DEFAULT false, -- True if AI suggests immediate review
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Project Analytics View (The Dashboard Engine)
-- This view consolidates multiple tables into a single row per project for the list view.
CREATE OR REPLACE VIEW public.project_analytics AS
SELECT 
    p.id,
    p.name,
    p.district,
    p.status,
    p.project_type,
    p.completion_percentage as base_completion,
    
    -- Visit Counts
    (SELECT COUNT(*) FROM public.visit_metadata v WHERE v.project_id = p.id) as total_visits,
    
    -- Issue Monitoring
    (SELECT COUNT(*) FROM public.issues i WHERE i.project_id = p.id AND i.status != 'closed') as active_issues,
    
    -- Recent Progress (from latest visit)
    COALESCE(
        (SELECT pr.overall_pct 
         FROM public.progress_records pr 
         JOIN public.visit_metadata v ON pr.visit_id = v.id
         WHERE v.project_id = p.id 
         ORDER BY v.visit_date DESC LIMIT 1),
        p.completion_percentage
    ) as actual_progress,
    
    -- Workforce Trends (Latest headcount)
    COALESCE(
        (SELECT wr.count 
         FROM public.workforce_records wr 
         JOIN public.visit_metadata v ON wr.visit_id = v.id
         WHERE v.project_id = p.id 
         ORDER BY v.visit_date DESC LIMIT 1),
        0
    ) as latest_workforce,
    
    -- AI Flags
    (SELECT COUNT(*) FROM public.visit_ai_analysis ai WHERE ai.project_id = p.id AND ai.is_flagged = true) as ai_flags_count

FROM public.projects p;

-- ── Permissions & Security ──────────────────────────────────────────────────
ALTER VIEW public.project_analytics OWNER TO postgres;
GRANT SELECT ON public.project_analytics TO authenticated;

-- RLS for the new AI analysis table
ALTER TABLE public.visit_ai_analysis ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Managers view AI analysis" ON public.visit_ai_analysis 
FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'manager'))
);
