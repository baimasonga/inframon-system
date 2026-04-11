-- ============================================================================
-- 🤖 AI ANALYSIS AUTOMATION
-- Automatically triggers analysis when a field visit is synced
-- ============================================================================

-- Function to notify web dashboard / trigger AI
CREATE OR REPLACE FUNCTION public.trigger_ai_analysis()
RETURNS TRIGGER AS $$
BEGIN
    -- We perform an HTTP call to our Next.js API or just log it for the worker
    -- In a real Supabase setup, you'd use 'net.http_post' or a webhook
    
    INSERT INTO public.audit_logs (
        project_id, 
        event_type, 
        description, 
        severity
    ) VALUES (
        NEW.project_id,
        'AI_ANALYSIS_QUEUED',
        'System automatically queued AI analysis for visit: ' || NEW.id,
        'Low'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger definition
DROP TRIGGER IF EXISTS on_visit_inserted ON public.visit_metadata;
CREATE TRIGGER on_visit_inserted
AFTER INSERT ON public.visit_metadata
FOR EACH ROW EXECUTE FUNCTION public.trigger_ai_analysis();
