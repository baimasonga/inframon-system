# InfraMon: SQL Execution Order 🚀

To ensure all database features (Governance, AI, and Sync) work correctly, please run the scripts in your **Supabase SQL Editor** in the following order.

> [!NOTE]
> If you have already run some of these, you can safely run them again. Most scripts use `CREATE OR REPLACE` or `ADD COLUMN IF NOT EXISTS` to prevent data loss.

---

### Phase 1: Core & Identity (MANDATORY)
These scripts create the foundation of the system.
1. **[setup_fresh_db.sql](file:///c:/InfraMon/backend/setup_fresh_db.sql)**: Creates Projects, Users, and the detailed 10-step inspection tables.
2. **[secure_rls.sql](file:///c:/InfraMon/backend/secure_rls.sql)**: Sets up the triggers that sync Supabase Auth users with your `public.users` table.

### Phase 2: Intelligence & Governance
These scripts add the "Smart" layers to the foundation.
3. **[governance_schema.sql](file:///c:/InfraMon/backend/governance_schema.sql)**: Adds Districts/Chiefdoms and the "Manager" roles.
4. **[operational_expansion.sql](file:///c:/InfraMon/backend/operational_expansion.sql)**: Adds the Risk Register, Contractor Metrics, and Audit Logs.

### Phase 3: Field Operations (SYNC)
This is the "Engine" that powers the mobile app.
5. **[mobile_sync_rpc.sql](file:///c:/InfraMon/backend/mobile_sync_rpc.sql)**: The atomic function that allows the mobile app to upload everything in one transaction.
6. **[ai_trigger.sql](file:///c:/InfraMon/backend/ai_trigger.sql)**: Hooks that automatically alert the dashbord when a new visit is uploaded.

### Phase 4: Managerial Reporting
Powers the Web Dashboard.
7. **[analytics_views.sql](file:///c:/InfraMon/backend/analytics_views.sql)**: Aggregates all site data into the "Project Pulse" cards.

---

### ✅ Success Verification
After running all scripts:
- In the **Table Editor**, you should see `project_analytics` in the Views dropdown.
- In the **Database > Functions** section, you should see `submit_field_report` and `trigger_ai_analysis`.

**You are now ready for full-scale production deployment.**
