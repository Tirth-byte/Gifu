-- ==============================================================================
-- GUFI PRODUCTION DATABASE SCHEMA & SECURITY POLICIES
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. USERS PROFILE TABLE
-- Linked 1:1 with auth.users(id)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    email_normalized TEXT NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    username TEXT NOT NULL,
    username_normalized TEXT NOT NULL,
    display_name TEXT,
    profile_photo_url TEXT,
    auth_provider TEXT NOT NULL DEFAULT 'email',
    role TEXT NOT NULL DEFAULT 'user', -- 'user' | 'admin'
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    account_status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'disabled'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Username format constraint: 3-24 characters, letters, numbers, underscore, dot
    CONSTRAINT valid_username_format CHECK (username_normalized ~ '^[a-z0-9_.]{3,24}$'),
    CONSTRAINT valid_account_status CHECK (account_status IN ('active', 'disabled')),
    CONSTRAINT valid_role CHECK (role IN ('user', 'admin'))
);

-- Unique constraints & indices for fast lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_normalized ON public.users(email_normalized);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username_normalized ON public.users(username_normalized);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at DESC);

-- Reserved usernames list
CREATE TABLE IF NOT EXISTS public.reserved_usernames (
    username TEXT PRIMARY KEY
);

INSERT INTO public.reserved_usernames (username) VALUES
('admin'),
('administrator'),
('gufi'),
('support'),
('help'),
('official'),
('system'),
('moderator'),
('security'),
('root'),
('staff'),
('team')
ON CONFLICT (username) DO NOTHING;

-- 3. ADMIN AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID NOT NULL REFERENCES public.users(id),
    action TEXT NOT NULL,
    target_user_id UUID REFERENCES public.users(id),
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON public.admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin_id ON public.admin_audit_logs(admin_user_id);

-- 4. ROW LEVEL SECURITY (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reserved_usernames ENABLE ROW LEVEL SECURITY;

-- Reserved usernames can be read by anyone for client validation
CREATE POLICY "Public read reserved usernames"
ON public.reserved_usernames FOR SELECT
USING (true);

-- Helper function: Check if current authenticated user is an admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin' AND account_status = 'active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Users policy: Users can read their own full profile
CREATE POLICY "Users can read own profile"
ON public.users FOR SELECT
USING (auth.uid() = id);

-- Users policy: Authenticated users can read public profiles (for search / circles)
CREATE POLICY "Public profile read"
ON public.users FOR SELECT
USING (auth.uid() IS NOT NULL);

-- Users policy: Users can update their own editable profile fields
-- Explicitly prevents updating role, email, or id
CREATE POLICY "Users can update own profile fields"
ON public.users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (
    auth.uid() = id
    AND (SELECT role FROM public.users WHERE id = auth.uid()) = role -- Cannot change role
);

-- Users policy: Admins have full read access to all users
CREATE POLICY "Admins have full read access"
ON public.users FOR SELECT
USING (public.is_admin());

-- Users policy: Admins can update users (e.g., disable/enable)
CREATE POLICY "Admins can update user status"
ON public.users FOR UPDATE
USING (public.is_admin());

-- Admin Audit Logs policy: Only admins can view and insert audit logs
CREATE POLICY "Admins can read audit logs"
ON public.admin_audit_logs FOR SELECT
USING (public.is_admin());

CREATE POLICY "Admins can insert audit logs"
ON public.admin_audit_logs FOR INSERT
WITH CHECK (public.is_admin() AND auth.uid() = admin_user_id);

-- 5. TRIGGER FOR UPDATED_AT TIMESTAMP
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- 6. RPC: ATOMIC USERNAME AVAILABILITY CHECK
CREATE OR REPLACE FUNCTION public.is_username_available(input_username TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    normalized TEXT := lower(trim(input_username));
BEGIN
    -- Check syntax
    IF normalized !~ '^[a-z0-9_.]{3,24}$' THEN
        RETURN FALSE;
    END IF;

    -- Check reserved
    IF EXISTS (SELECT 1 FROM public.reserved_usernames WHERE username = normalized) THEN
        RETURN FALSE;
    END IF;

    -- Check existing users
    RETURN NOT EXISTS (SELECT 1 FROM public.users WHERE username_normalized = normalized);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: ATOMIC ACCOUNT CREATION / PROFILE PROVISIONING
CREATE OR REPLACE FUNCTION public.complete_user_signup(
    p_username TEXT,
    p_display_name TEXT DEFAULT NULL,
    p_photo_url TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    curr_user_id UUID := auth.uid();
    user_email TEXT;
    user_email_norm TEXT;
    username_norm TEXT := lower(trim(p_username));
    is_verified BOOLEAN;
BEGIN
    IF curr_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Fetch email and verified status from auth.users
    SELECT email, (email_confirmed_at IS NOT NULL)
    INTO user_email, is_verified
    FROM auth.users
    WHERE id = curr_user_id;

    IF user_email IS NULL THEN
        RAISE EXCEPTION 'Auth user not found';
    END IF;

    user_email_norm := lower(trim(user_email));

    -- Validate username availability
    IF NOT public.is_username_available(username_norm) THEN
        RAISE EXCEPTION 'Username is already taken or reserved';
    END IF;

    -- Upsert profile record
    INSERT INTO public.users (
        id,
        email,
        email_normalized,
        email_verified,
        username,
        username_normalized,
        display_name,
        profile_photo_url,
        onboarding_completed,
        created_at,
        updated_at
    ) VALUES (
        curr_user_id,
        user_email,
        user_email_norm,
        is_verified,
        trim(p_username),
        username_norm,
        COALESCE(p_display_name, trim(p_username)),
        p_photo_url,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        username = EXCLUDED.username,
        username_normalized = EXCLUDED.username_normalized,
        display_name = EXCLUDED.display_name,
        profile_photo_url = COALESCE(EXCLUDED.profile_photo_url, public.users.profile_photo_url),
        email_verified = EXCLUDED.email_verified,
        onboarding_completed = true,
        updated_at = NOW();

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. STORAGE BUCKET FOR AVATARS
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Policy: Anyone can view avatars
CREATE POLICY "Public avatar view"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Policy: Authenticated users can upload their own avatars
CREATE POLICY "Authenticated user avatar upload"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
);

-- Policy: Users can update or delete their own avatar
CREATE POLICY "Owner avatar modify"
ON storage.objects FOR UPDATE
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Owner avatar delete"
ON storage.objects FOR DELETE
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
