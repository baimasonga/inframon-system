-- InfraMon Sierra Leone - Phase 3 Mobile Uplink Migration

-- 7. Workforce Records (Logged by Clerks/Engineers on site)
CREATE TABLE IF NOT EXISTS public.workforce_records (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
    record_date DATE NOT NULL,
    role_category TEXT NOT NULL,
    gender TEXT NOT NULL CHECK (gender IN ('male', 'female')),
    is_youth BOOLEAN NOT NULL DEFAULT false,
    count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Attendance Logs (GPS Verified Check-ins)
CREATE TABLE IF NOT EXISTS public.attendance_logs (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES public.projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    check_in_time TIMESTAMP WITH TIME ZONE NOT NULL,
    check_out_time TIMESTAMP WITH TIME ZONE,
    gps_lat NUMERIC,
    gps_lng NUMERIC,
    verified_gps BOOLEAN DEFAULT true,
    total_hours NUMERIC,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
