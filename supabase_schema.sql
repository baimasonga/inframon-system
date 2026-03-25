-- InfraMon Sierra Leone - Phase 3 Supabase Database Schema

-- Drop existing tables to avoid UUID/TEXT type conflicts from older schemas
DROP TABLE IF EXISTS public.discussions CASCADE;
DROP TABLE IF EXISTS public.issues CASCADE;
DROP TABLE IF EXISTS public.inspections CASCADE;
DROP TABLE IF EXISTS public.templates CASCADE;
DROP TABLE IF EXISTS public.projects CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
-- 1. Users Table (Engineers, M&E, System Admin, Clerks)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('System Admin', 'Engineer', 'M&E Unit', 'Clerk of Works')),
    district TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Projects Table
CREATE TABLE IF NOT EXISTS public.projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('Active', 'Completed', 'Delayed', 'Suspended')),
    district TEXT NOT NULL,
    budget_allocated NUMERIC,
    completion_percentage INTEGER DEFAULT 0,
    contractor_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Templates (Inspection Forms)
CREATE TABLE IF NOT EXISTS public.templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    questions JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'Draft' CHECK (status IN ('Draft', 'Active')),
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Inspections Table
CREATE TABLE IF NOT EXISTS public.inspections (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES public.projects(id),
    inspector_id UUID REFERENCES public.users(id),
    template_id TEXT REFERENCES public.templates(id),
    status TEXT NOT NULL CHECK (status IN ('Submitted', 'Reviewed', 'Flagged')),
    check_data JSONB NOT NULL DEFAULT '[]'::jsonb,
    gps_lat NUMERIC,
    gps_lng NUMERIC,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Issues (Risk/Blocker Reports)
CREATE TABLE IF NOT EXISTS public.issues (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES public.projects(id),
    reported_by UUID REFERENCES public.users(id),
    title TEXT NOT NULL,
    description TEXT,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    status TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'Under Review', 'Resolved')),
    photo_url TEXT,
    gps_lat NUMERIC,
    gps_lng NUMERIC,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Discussions (Threaded Comments mechanism)
CREATE TABLE IF NOT EXISTS public.discussions (
    id TEXT PRIMARY KEY,
    issue_id TEXT REFERENCES public.issues(id) ON DELETE CASCADE,
    author_id UUID REFERENCES public.users(id),
    text_content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Row Level Security (Enable RLS for security rules later if needed)
-- ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.issues ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.discussions ENABLE ROW LEVEL SECURITY;
