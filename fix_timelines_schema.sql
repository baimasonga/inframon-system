-- InfraMon Sierra Leone - Phase 3 Timelines Fix
-- The 'projects' table uses TEXT for the 'id' column. 
-- The following recreates the timelines and milestones tables to match that data type.

DROP TABLE IF EXISTS public.milestones CASCADE;
DROP TABLE IF EXISTS public.timelines CASCADE;

-- Timelines (Phases)
CREATE TABLE public.timelines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
  phase_name TEXT NOT NULL,
  start_date DATE,
  end_date DATE,
  status TEXT CHECK (status IN ('pending', 'active', 'completed', 'delayed')) DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Milestones (Sub-tasks within a phase, if needed later)
CREATE TABLE public.milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timeline_id UUID REFERENCES public.timelines(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  due_date DATE,
  is_completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure RLS is enabled if policies exist, otherwise we can just create them
-- ALTER TABLE public.timelines ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.milestones ENABLE ROW LEVEL SECURITY;
