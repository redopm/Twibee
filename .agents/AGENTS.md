# Project-Scoped Rules for MissMe App

The following are strict guidelines and best practices derived from past implementations and bug fixes in this project. All AI agents MUST follow these rules to ensure high performance, security, and stability.

## 1. Database Security & RLS (Row Level Security)
- **Prevent "Admin Breeding"**: Only the Channel Owner (Boss) should have the authority to distribute admin privileges. In `channel_admins` INSERT policies, NEVER allow existing admins to create new admins.
- **Short-Circuit Recursion**: When dealing with interrelated tables (e.g., `channels` and `channel_subscribers`), RLS policies can cause infinite recursion. Always use a short-circuit check at the top of the policy (e.g., `user_id = auth.uid() OR ...`) so PostgreSQL instantly returns TRUE for the owner/current user without reading other tables.
- **Security Definer Functions**: When bypassing RLS for raw performance (e.g., tracking views via UUID), it's safe if the UUID is mathematically unguessable. Avoid unnecessary `JOIN` checks on memberships inside `SECURITY DEFINER` functions if they introduce massive performance bottlenecks for high-volume actions.

## 2. Database Performance & Operations
- **Bulk Insert over Loops**: NEVER use `FOREACH` loops in PL/pgSQL for bulk inserts. Always pass an array (e.g., `UUID[]`) and use the `unnest()` function for a Set-Based operation (e.g., `INSERT INTO table (col1) SELECT col FROM unnest(array_param)`). This is 10x-20x faster.

## 3. Flutter Frontend Architecture
- **API Batching (Debouncing)**: NEVER spam the backend with individual API calls for rapid, high-volume events (like scrolling through messages and marking them as viewed). Always queue/batch the events in a `Set` or `List` and use a `Timer` (e.g., 2 seconds) to send a single bulk RPC call to Supabase.
- **Accurate Visibility Tracking**: Do NOT rely on `ListView.builder` building items as a proxy for "viewing". Flutter caches items off-screen. Use the `visibility_detector` package and check if `visibilityInfo.visibleFraction > 0.5` to guarantee accurate, Telegram-like view tracking.
- **Filter Own Actions**: When tracking views or similar metrics, always filter out the current user's own actions on the frontend (e.g., `post['sender_id'] != currentUserId`) to save unnecessary API calls and database space.
