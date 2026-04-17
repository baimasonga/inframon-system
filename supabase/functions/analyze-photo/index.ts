// InfraMon — AI Photo Analysis Edge Function
// Deploy: supabase functions deploy analyze-photo
// Secret: supabase secrets set OPENAI_API_KEY=sk-...
//
// This function accepts a site photo URL, sends it to OpenAI Vision (gpt-4o),
// and stores the structured result in the analysis_results table.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { image_url, visit_id, project_id } = await req.json();
    if (!image_url) {
      return new Response(JSON.stringify({ error: 'image_url is required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const openaiKey = Deno.env.get('OPENAI_API_KEY');
    if (!openaiKey) {
      return new Response(JSON.stringify({ error: 'OPENAI_API_KEY not configured' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Call OpenAI Vision API (gpt-4o)
    const openaiRes = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        max_tokens: 500,
        messages: [{
          role: 'user',
          content: [
            {
              type: 'text',
              text: `You are an infrastructure quality assessment AI for a civil engineering monitoring system in Sierra Leone.
Analyze this construction site photo and return a JSON object with exactly these fields:
{
  "progress_score": <integer 0-100, estimated completion percentage of visible work>,
  "quality_score": <integer 0-100, quality/workmanship assessment>,
  "findings": [<array of up to 5 short strings describing key observations, issues, or positives>],
  "safety_compliance": <integer 0-100, PPE and safety compliance estimate>,
  "summary": "<one sentence overall assessment>"
}
Return ONLY valid JSON, no markdown.`,
            },
            {
              type: 'image_url',
              image_url: { url: image_url, detail: 'high' },
            },
          ],
        }],
      }),
    });

    if (!openaiRes.ok) {
      const err = await openaiRes.text();
      return new Response(JSON.stringify({ error: `OpenAI error: ${err}` }), {
        status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const openaiData = await openaiRes.json();
    const rawContent = openaiData.choices?.[0]?.message?.content ?? '{}';
    let analysisPayload: Record<string, unknown>;
    try {
      analysisPayload = JSON.parse(rawContent);
    } catch {
      analysisPayload = { progress_score: 0, quality_score: 0, findings: [rawContent], summary: 'Parse error' };
    }

    // Store result in Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { data: inserted, error: dbErr } = await supabase
      .from('analysis_results')
      .insert({
        visit_id: visit_id ?? null,
        project_id: project_id ?? null,
        image_url,
        analysis_payload: analysisPayload,
      })
      .select()
      .single();

    if (dbErr) {
      console.error('DB insert error:', dbErr);
    }

    return new Response(JSON.stringify({ success: true, result: analysisPayload, id: inserted?.id }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (err) {
    console.error('Edge function error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
