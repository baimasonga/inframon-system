# InfraMon Edge Functions

## analyze-photo

Analyzes site photos using OpenAI gpt-4o Vision and stores results in `analysis_results`.

### Deploy

```bash
# Install Supabase CLI
npm install -g supabase

# Link to project
supabase link --project-ref xmkbgqniylgrcudqmkca

# Set OpenAI key as Supabase secret
supabase secrets set OPENAI_API_KEY=sk-your-key-here

# Deploy function
supabase functions deploy analyze-photo
```

### Test

```bash
curl -X POST https://xmkbgqniylgrcudqmkca.supabase.co/functions/v1/analyze-photo \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"image_url":"https://...","visit_id":"123","project_id":"abc"}'
```
