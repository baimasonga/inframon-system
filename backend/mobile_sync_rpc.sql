-- ============================================================================
-- 🔃 TRANSACTIONAL FIELD REPORT SUBMISSION (Final Refactored Version)
-- accepts a complex JSON object from the mobile app and performs atomic inserts
-- ============================================================================

CREATE OR REPLACE FUNCTION public.submit_field_report(report jsonb)
RETURNS jsonb AS $$
DECLARE
    new_visit_id UUID;
    milestone RECORD;
    issue RECORD;
    workforce_item RECORD;
    material RECORD;
    inspector_id_val UUID;
BEGIN
    inspector_id_val := (report->>'inspector_id')::UUID;

    -- 1. Insert Master Visit Metadata
    INSERT INTO public.visit_metadata (
        project_id,
        inspector_id,
        visit_date,
        visit_type,
        weather,
        site_supervisor_present,
        gps_lat,
        gps_lng
    ) VALUES (
        report->>'project_id',
        inspector_id_val,
        (report->>'date_time')::TIMESTAMPTZ,
        report->>'visit_type',
        report->>'weather_condition',
        (report->>'site_supervisor_present')::BOOLEAN,
        (report->>'gps_lat')::NUMERIC,
        (report->>'gps_lng')::NUMERIC
    ) RETURNING id INTO new_visit_id;

    -- 2. Insert Progress Record
    INSERT INTO public.progress_records (
        visit_id,
        project_id,
        overall_pct,
        work_since_last_visit
    ) VALUES (
        new_visit_id,
        report->>'project_id',
        (report->>'overall_progress')::INTEGER,
        report->>'notes'
    );

    -- 3. Insert Inspector Summary
    INSERT INTO public.inspector_summaries (
        visit_id,
        overall_status,
        recommendation,
        key_achievements
    ) VALUES (
        new_visit_id,
        report->>'overall_status',
        report->>'recommendation',
        report->>'notes'
    );

    -- 4. Insert Milestone Logs
    FOR milestone IN SELECT * FROM jsonb_to_recordset(report->'milestones') 
        AS (id UUID, status TEXT, pct INTEGER, delay_days INTEGER, reason TEXT) 
    LOOP
        INSERT INTO public.milestone_logs (visit_id, milestone_id, status, completion_pct, delay_days, delay_reason)
        VALUES (new_visit_id, milestone.id, milestone.status, milestone.pct, milestone.delay_days, milestone.reason);
    END LOOP;

    -- 5. Insert Issue/Defect Reports
    FOR issue IN SELECT * FROM jsonb_to_recordset(report->'issues')
    AS (title TEXT, category TEXT, severity TEXT, action TEXT, responsible TEXT, deadline DATE)
    LOOP
        INSERT INTO public.defect_reports (project_id, visit_id, title, category, severity, recommended_action, responsible_party, deadline)
        VALUES (report->>'project_id', new_visit_id, issue.title, issue.category, issue.severity, issue.action, issue.responsible, issue.deadline);
    END LOOP;

    -- 6. Insert Workforce Records
    FOR workforce_item IN SELECT * FROM jsonb_to_recordset(report->'workforce_details')
    AS (role TEXT, count INTEGER, gender TEXT, is_youth BOOLEAN)
    LOOP
        INSERT INTO public.workforce_records (project_id, visit_id, record_date, role_category, count, gender, is_youth)
        VALUES (report->>'project_id', new_visit_id, (report->>'date_time')::DATE, workforce_item.role, workforce_item.count, workforce_item.gender, workforce_item.is_youth);
    END LOOP;

    -- 7. Insert Materials Records
    FOR material IN SELECT * FROM jsonb_to_recordset(report->'materials')
    AS (item TEXT, pass BOOLEAN, notes TEXT)
    LOOP
        INSERT INTO public.materials_records (project_id, visit_id, material_name, status, notes)
        VALUES (report->>'project_id', new_visit_id, material.item, CASE WHEN material.pass THEN 'Good' ELSE 'Substandard' END, material.notes);
    END LOOP;

    RETURN jsonb_build_object('success', true, 'visit_id', new_visit_id);

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Field report sync failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
