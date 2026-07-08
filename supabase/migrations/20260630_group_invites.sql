-- Create group_invites table
CREATE TABLE IF NOT EXISTS public.group_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  token TEXT UNIQUE NOT NULL,
  created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create group_join_requests table
CREATE TABLE IF NOT EXISTS public.group_join_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(chat_id, user_id)
);

-- Enable RLS
ALTER TABLE public.group_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_join_requests ENABLE ROW LEVEL SECURITY;

-- Policies for group_invites
-- Anyone can read an invite link by token to preview the group
CREATE POLICY "Anyone can read group invites" ON public.group_invites FOR SELECT USING (true);
-- Only group participants can create an invite link
CREATE POLICY "Group participants can create invites" ON public.group_invites 
FOR ALL USING (
  EXISTS (SELECT 1 FROM public.chat_participants WHERE chat_id = group_invites.chat_id AND user_id = auth.uid())
);

-- Policies for group_join_requests
-- Users can see their own requests and admins can see all requests for their chat
CREATE POLICY "Users can view their requests and admins can view all" ON public.group_join_requests
FOR SELECT USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.chat_participants WHERE chat_id = group_join_requests.chat_id AND user_id = auth.uid() AND role = 'admin')
);

-- Users can insert their own requests
CREATE POLICY "Users can create join requests" ON public.group_join_requests
FOR INSERT WITH CHECK (user_id = auth.uid());

-- Admins can update request status
CREATE POLICY "Admins can update join requests" ON public.group_join_requests
FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.chat_participants WHERE chat_id = group_join_requests.chat_id AND user_id = auth.uid() AND role = 'admin')
);

-- Admins can delete requests (or users cancel their own)
CREATE POLICY "Admins or users can delete requests" ON public.group_join_requests
FOR DELETE USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.chat_participants WHERE chat_id = group_join_requests.chat_id AND user_id = auth.uid() AND role = 'admin')
);
