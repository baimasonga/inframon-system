-- Migration: Add status to visit_metadata to support Draft/Submitted states
ALTER TABLE public.visit_metadata 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Draft' 
CHECK (status IN ('Draft', 'Submitted'));

-- Also ensure project_type is accessible in projects for filtering
-- (Already exists but ensuring constraint for safety)
ALTER TABLE public.projects
DROP CONSTRAINT IF EXISTS projects_project_type_check;

ALTER TABLE public.projects
ADD CONSTRAINT projects_project_type_check 
CHECK (project_type IN (
  'Feeder Road', 'Building', 'Borehole + Solar',
  'Bridge / Culvert', 'Grain Store / Drying Floor', 'Public Toilet'
));
