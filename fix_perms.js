const url = 'https://xfynwiyungfkckhjhzsg.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhmeW53aXl1bmdma2NraGpoenNnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjAzNjIwMSwiZXhwIjoyMDk3NjEyMjAxfQ.H-Qau-JaOSGRF8-hpjLXUGBS5EluIDcP5okrZS4AMJs';

// Run a raw SQL statement via Supabase Management API
async function runSQL(statement) {
  const res = await fetch(`${url}/rest/v1/rpc/exec_sql`, {
    method: 'POST',
    headers: {
      'apikey': serviceKey,
      'Authorization': `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    },
    body: JSON.stringify({ query: statement })
  });
  return { status: res.status, text: await res.text() };
}

// Try using pg_net or direct approach
async function tryDirectSQL(sql) {
  // Supabase REST doesn't support DDL directly.
  // We'll use the pg_dump workaround: insert via a function or use the admin endpoint.
  // Actually, let's use fetch to call Supabase's internal database endpoint
  const res = await fetch(`${url}/pg`, {
    method: 'POST',
    headers: {
      'apikey': serviceKey,
      'Authorization': `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql })
  });
  return { status: res.status, text: await res.text() };
}

async function main() {
  const grants = [
    'GRANT SELECT, INSERT, UPDATE ON public.user_settings TO authenticated;',
    'GRANT SELECT, INSERT, DELETE ON public.blocked_users TO authenticated;',
    'GRANT USAGE ON SCHEMA public TO authenticated;',
  ];

  console.log('=== Attempting to fix RLS permissions ===\n');

  for (const sql of grants) {
    const r1 = await runSQL(sql);
    const r2 = await tryDirectSQL(sql);
    console.log(`SQL: ${sql}`);
    console.log(`  via rpc: ${r1.status} ${r1.text}`);
    console.log(`  via pg:  ${r2.status} ${r2.text}`);
  }

  console.log('\n=== IMPORTANT ===');
  console.log('If the above did not work (Supabase REST API does not support DDL directly),');
  console.log('please paste and run this SQL in your Supabase Dashboard > SQL Editor:\n');
  console.log(`GRANT SELECT, INSERT, UPDATE ON public.user_settings TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.blocked_users TO authenticated;`);
}

main().catch(console.error);
