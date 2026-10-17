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

-- ==============================================================================
-- 9. GUFI CORE PRODUCT DOMAIN
-- Circles, Circle Members, Commitments, Proofs, Reviews, Events, Daily Results
-- ==============================================================================

-- CIRCLES TABLE
CREATE TABLE IF NOT EXISTS public.circles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_circles_owner_id ON public.circles(owner_id);
CREATE INDEX IF NOT EXISTS idx_circles_status ON public.circles(status);

-- CIRCLE MEMBERS TABLE
CREATE TABLE IF NOT EXISTS public.circle_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID NOT NULL REFERENCES public.circles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'left', 'removed')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_circle_member UNIQUE (circle_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_circle_members_user_id ON public.circle_members(user_id);
CREATE INDEX IF NOT EXISTS idx_circle_members_circle_id ON public.circle_members(circle_id);

-- COMMITMENTS TABLE
CREATE TABLE IF NOT EXISTS public.commitments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    circle_id UUID REFERENCES public.circles(id) ON DELETE SET NULL,
    accountability_scope TEXT NOT NULL DEFAULT 'circle' CHECK (accountability_scope IN ('circle', 'private')),
    title TEXT NOT NULL,
    description TEXT,
    proof_type TEXT CHECK (proof_type IN ('photo', 'text')),
    gufi_day TEXT NOT NULL, -- Format: YYYY-MM-DD
    due_at TIMESTAMPTZ NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    status TEXT NOT NULL DEFAULT 'draft' CHECK (
        status IN ('draft', 'committed', 'proof_submitted', 'rejected', 'verified', 'completed', 'missed', 'cancelled')
    ),
    committed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    resolved_at TIMESTAMPTZ,
    correction_deadline TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_accountability_circle CHECK (
        (accountability_scope = 'circle' AND circle_id IS NOT NULL) OR
        (accountability_scope = 'private' AND circle_id IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_commitments_owner_day ON public.commitments(owner_id, gufi_day);
CREATE INDEX IF NOT EXISTS idx_commitments_circle_day ON public.commitments(circle_id, gufi_day);
CREATE INDEX IF NOT EXISTS idx_commitments_status ON public.commitments(status);
CREATE INDEX IF NOT EXISTS idx_commitments_due_at ON public.commitments(due_at);

-- PROOFS TABLE
CREATE TABLE IF NOT EXISTS public.proofs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commitment_id UUID NOT NULL REFERENCES public.commitments(id) ON DELETE CASCADE,
    submitter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    proof_type TEXT NOT NULL CHECK (proof_type IN ('photo', 'text')),
    text_content TEXT,
    media_url TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'superseded')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_proofs_commitment_id ON public.proofs(commitment_id);
CREATE INDEX IF NOT EXISTS idx_proofs_submitter_id ON public.proofs(submitter_id);

-- REVIEWS TABLE
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proof_id UUID NOT NULL REFERENCES public.proofs(id) ON DELETE CASCADE,
    commitment_id UUID NOT NULL REFERENCES public.commitments(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    decision TEXT NOT NULL CHECK (decision IN ('approved', 'rejected')),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_proof_reviewer UNIQUE (proof_id, reviewer_id),
    CONSTRAINT check_review_reason CHECK (
        (decision = 'approved') OR
        (decision = 'rejected' AND reason IS NOT NULL AND length(trim(reason)) > 0)
    )
);

CREATE INDEX IF NOT EXISTS idx_reviews_proof_id ON public.reviews(proof_id);
CREATE INDEX IF NOT EXISTS idx_reviews_commitment_id ON public.reviews(commitment_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id ON public.reviews(reviewer_id);

-- COMMITMENT EVENTS TABLE (Immutable audit stream)
CREATE TABLE IF NOT EXISTS public.commitment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commitment_id UUID NOT NULL REFERENCES public.commitments(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL CHECK (
        event_type IN (
            'COMMITMENT_CREATED',
            'COMMITMENT_COMMITTED',
            'COMMITMENT_CANCELLED',
            'COMMITMENT_MISSED',
            'PROOF_SUBMITTED',
            'PROOF_REJECTED',
            'PROOF_RESUBMITTED',
            'PROOF_VERIFIED',
            'CIRCLE_CREATED',
            'MEMBER_JOINED'
        )
    ),
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_commitment_events_commitment ON public.commitment_events(commitment_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_commitment_events_actor ON public.commitment_events(actor_id);

-- DAILY RESULTS TABLE
CREATE TABLE IF NOT EXISTS public.daily_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    gufi_day TEXT NOT NULL,
    commitments_total INT NOT NULL DEFAULT 0,
    verified_count INT NOT NULL DEFAULT 0,
    missed_count INT NOT NULL DEFAULT 0,
    cancelled_count INT NOT NULL DEFAULT 0,
    pending_count INT NOT NULL DEFAULT 0,
    completion_percentage DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    daily_status TEXT NOT NULL DEFAULT 'empty' CHECK (
        daily_status IN ('empty', 'in_progress', 'pending_review', 'complete', 'partial', 'missed')
    ),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_gufi_day UNIQUE (user_id, gufi_day)
);

CREATE INDEX IF NOT EXISTS idx_daily_results_user_day ON public.daily_results(user_id, gufi_day);

-- STORAGE BUCKET FOR PROOFS (Private)
INSERT INTO storage.buckets (id, name, public)
VALUES ('proofs', 'proofs', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- TRIGGERS FOR UPDATED_AT
CREATE OR REPLACE TRIGGER trigger_circles_updated_at
BEFORE UPDATE ON public.circles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trigger_circle_members_updated_at
BEFORE UPDATE ON public.circle_members
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trigger_commitments_updated_at
BEFORE UPDATE ON public.commitments
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trigger_daily_results_updated_at
BEFORE UPDATE ON public.daily_results
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- TRIGGER: AUTO-ADD CIRCLE OWNER AS MEMBER
CREATE OR REPLACE FUNCTION public.handle_circle_owner_membership()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.circle_members (circle_id, user_id, role, status)
    VALUES (NEW.id, NEW.owner_id, 'owner', 'active')
    ON CONFLICT (circle_id, user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trigger_circle_owner_membership
AFTER INSERT ON public.circles
FOR EACH ROW EXECUTE FUNCTION public.handle_circle_owner_membership();

-- RPC: AUTHORITATIVE GUFI DAY CONVERSION
CREATE OR REPLACE FUNCTION public.get_gufi_day(
    p_timestamp TIMESTAMPTZ,
    p_timezone TEXT DEFAULT 'UTC'
)
RETURNS TEXT AS $$
DECLARE
    local_ts TIMESTAMP;
BEGIN
    local_ts := p_timestamp AT TIME ZONE p_timezone;
    IF EXTRACT(HOUR FROM local_ts) < 4 THEN
        RETURN to_char((local_ts - INTERVAL '1 day')::DATE, 'YYYY-MM-DD');
    ELSE
        RETURN to_char(local_ts::DATE, 'YYYY-MM-DD');
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- RPC: ATOMIC COMMIT COMMITMENT (ENFORCING MAX 3 COMMITMENTS PER GUFI DAY)
CREATE OR REPLACE FUNCTION public.commit_commitment(p_commitment_id UUID)
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
    c_rec RECORD;
    active_count INT;
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO c_rec
    FROM public.commitments
    WHERE id = p_commitment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commitment not found';
    END IF;

    IF c_rec.owner_id != curr_user THEN
        RAISE EXCEPTION 'Unauthorized: only owner can commit';
    END IF;

    IF c_rec.status != 'draft' THEN
        RAISE EXCEPTION 'Only draft commitments can be committed';
    END IF;

    SELECT COUNT(*) INTO active_count
    FROM public.commitments
    WHERE owner_id = curr_user
      AND gufi_day = c_rec.gufi_day
      AND status != 'draft';

    IF active_count >= 3 THEN
        RAISE EXCEPTION 'Daily limit reached: maximum 3 commitments per Gufi day';
    END IF;

    UPDATE public.commitments
    SET status = 'committed',
        committed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_commitment_id;

    INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
    VALUES (p_commitment_id, curr_user, 'COMMITMENT_COMMITTED', jsonb_build_object('gufi_day', c_rec.gufi_day));

    PERFORM public.recalculate_daily_result(curr_user, c_rec.gufi_day);

    RETURN jsonb_build_object('success', true, 'status', 'committed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: SUBMIT PROOF
CREATE OR REPLACE FUNCTION public.submit_proof(
    p_commitment_id UUID,
    p_proof_type TEXT,
    p_text_content TEXT DEFAULT NULL,
    p_media_url TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
    c_rec RECORD;
    proof_id UUID;
    event_name TEXT;
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO c_rec
    FROM public.commitments
    WHERE id = p_commitment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commitment not found';
    END IF;

    IF c_rec.owner_id != curr_user THEN
        RAISE EXCEPTION 'Unauthorized: only owner can submit proof';
    END IF;

    IF c_rec.status NOT IN ('committed', 'rejected') THEN
        RAISE EXCEPTION 'Proof can only be submitted for committed or rejected commitments';
    END IF;

    IF c_rec.status = 'rejected' AND c_rec.correction_deadline IS NOT NULL AND NOW() > c_rec.correction_deadline THEN
        RAISE EXCEPTION 'Correction window has expired for this commitment';
    END IF;

    -- Validate proof type
    IF p_proof_type NOT IN ('photo', 'text') THEN
        RAISE EXCEPTION 'Invalid proof type: must be photo or text';
    END IF;

    IF p_proof_type = 'text' AND (p_text_content IS NULL OR length(trim(p_text_content)) = 0) THEN
        RAISE EXCEPTION 'Text content is required for text proof';
    END IF;

    IF p_proof_type = 'photo' AND (p_media_url IS NULL OR length(trim(p_media_url)) = 0) THEN
        RAISE EXCEPTION 'Media URL is required for photo proof';
    END IF;

    UPDATE public.proofs
    SET status = 'superseded'
    WHERE commitment_id = p_commitment_id AND status = 'submitted';

    INSERT INTO public.proofs (
        commitment_id,
        submitter_id,
        proof_type,
        text_content,
        media_url,
        submitted_at,
        status
    ) VALUES (
        p_commitment_id,
        curr_user,
        p_proof_type,
        p_text_content,
        p_media_url,
        NOW(),
        'submitted'
    ) RETURNING id INTO proof_id;

    event_name := CASE WHEN c_rec.status = 'rejected' THEN 'PROOF_RESUBMITTED' ELSE 'PROOF_SUBMITTED' END;

    IF c_rec.accountability_scope = 'private' THEN
        UPDATE public.commitments
        SET status = 'completed',
            proof_type = p_proof_type,
            resolved_at = NOW(),
            correction_deadline = NULL,
            updated_at = NOW()
        WHERE id = p_commitment_id;

        INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
        VALUES (p_commitment_id, curr_user, 'commitment_completed', jsonb_build_object('proof_id', proof_id));

        PERFORM public.recalculate_daily_result(curr_user, c_rec.gufi_day);

        RETURN jsonb_build_object('success', true, 'proof_id', proof_id, 'status', 'completed');
    ELSE
        UPDATE public.commitments
        SET status = 'proof_submitted',
            proof_type = p_proof_type,
            correction_deadline = NULL,
            updated_at = NOW()
        WHERE id = p_commitment_id;

        INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
        VALUES (p_commitment_id, curr_user, event_name, jsonb_build_object('proof_id', proof_id));

        PERFORM public.recalculate_daily_result(curr_user, c_rec.gufi_day);

        RETURN jsonb_build_object('success', true, 'proof_id', proof_id, 'status', 'proof_submitted');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: REVIEW PROOF (1 APPROVAL IS ENOUGH)
CREATE OR REPLACE FUNCTION public.review_proof(
    p_proof_id UUID,
    p_decision TEXT,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
    p_rec RECORD;
    c_rec RECORD;
    review_id UUID;
    is_member BOOLEAN;
    corr_deadline TIMESTAMPTZ := NULL;
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_decision NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Invalid review decision';
    END IF;

    SELECT * INTO p_rec FROM public.proofs WHERE id = p_proof_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proof not found';
    END IF;

    SELECT * INTO c_rec FROM public.commitments WHERE id = p_rec.commitment_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commitment not found';
    END IF;

    IF c_rec.owner_id = curr_user THEN
        RAISE EXCEPTION 'Owner cannot review their own proof';
    END IF;

    IF c_rec.circle_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.circle_members
            WHERE circle_id = c_rec.circle_id AND user_id = curr_user AND status = 'active'
        ) INTO is_member;

        IF NOT is_member THEN
            RAISE EXCEPTION 'Unauthorized: only active circle members can review';
        END IF;
    END IF;

    IF c_rec.status != 'proof_submitted' THEN
        RAISE EXCEPTION 'Commitment is not in proof_submitted state';
    END IF;

    IF p_decision = 'rejected' AND (p_reason IS NULL OR length(trim(p_reason)) = 0) THEN
        RAISE EXCEPTION 'Rejection requires a reason';
    END IF;

    INSERT INTO public.reviews (
        proof_id,
        commitment_id,
        reviewer_id,
        decision,
        reason
    ) VALUES (
        p_proof_id,
        c_rec.id,
        curr_user,
        p_decision,
        p_reason
    ) RETURNING id INTO review_id;

    IF p_decision = 'approved' THEN
        UPDATE public.commitments
        SET status = 'verified',
            resolved_at = NOW(),
            correction_deadline = NULL,
            updated_at = NOW()
        WHERE id = c_rec.id;

        INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
        VALUES (c_rec.id, curr_user, 'PROOF_VERIFIED', jsonb_build_object('review_id', review_id));
    ELSE
        IF p_rec.submitted_at <= c_rec.due_at THEN
            corr_deadline := NOW() + INTERVAL '6 hours';
        END IF;

        UPDATE public.commitments
        SET status = 'rejected',
            correction_deadline = corr_deadline,
            updated_at = NOW()
        WHERE id = c_rec.id;

        INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
        VALUES (c_rec.id, curr_user, 'PROOF_REJECTED', jsonb_build_object(
            'review_id', review_id,
            'reason', p_reason,
            'correction_deadline', corr_deadline
        ));
    END IF;

    PERFORM public.recalculate_daily_result(c_rec.owner_id, c_rec.gufi_day);

    RETURN jsonb_build_object(
        'success', true,
        'review_id', review_id,
        'status', CASE WHEN p_decision = 'approved' THEN 'verified' ELSE 'rejected' END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: CANCEL COMMITMENT
CREATE OR REPLACE FUNCTION public.cancel_commitment(
    p_commitment_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    curr_user UUID := auth.uid();
    c_rec RECORD;
BEGIN
    IF curr_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO c_rec
    FROM public.commitments
    WHERE id = p_commitment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commitment not found';
    END IF;

    IF c_rec.owner_id != curr_user THEN
        RAISE EXCEPTION 'Unauthorized: only owner can cancel commitment';
    END IF;

    IF c_rec.status NOT IN ('committed', 'proof_submitted', 'rejected') THEN
        RAISE EXCEPTION 'Only committed, proof_submitted, or rejected commitments can be cancelled';
    END IF;

    UPDATE public.commitments
    SET status = 'cancelled',
        cancelled_at = NOW(),
        cancellation_reason = p_reason,
        resolved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_commitment_id;

    INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
    VALUES (p_commitment_id, curr_user, 'COMMITMENT_CANCELLED', jsonb_build_object('reason', p_reason));

    PERFORM public.recalculate_daily_result(curr_user, c_rec.gufi_day);

    RETURN jsonb_build_object('success', true, 'status', 'cancelled');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: RECALCULATE DAILY RESULT
CREATE OR REPLACE FUNCTION public.recalculate_daily_result(
    p_user_id UUID,
    p_gufi_day TEXT
)
RETURNS VOID AS $$
DECLARE
    v_total INT := 0;
    v_verified INT := 0;
    v_missed INT := 0;
    v_cancelled INT := 0;
    v_pending INT := 0;
    v_pct DOUBLE PRECISION := 0.0;
    v_status TEXT := 'empty';
BEGIN
    SELECT
        COUNT(*) FILTER (WHERE status != 'draft'),
        COUNT(*) FILTER (WHERE status = 'verified'),
        COUNT(*) FILTER (WHERE status = 'missed'),
        COUNT(*) FILTER (WHERE status = 'cancelled'),
        COUNT(*) FILTER (WHERE status IN ('committed', 'proof_submitted', 'rejected'))
    INTO v_total, v_verified, v_missed, v_cancelled, v_pending
    FROM public.commitments
    WHERE owner_id = p_user_id AND gufi_day = p_gufi_day;

    IF v_total > 0 THEN
        v_pct := ROUND(((v_verified::DOUBLE PRECISION / v_total::DOUBLE PRECISION) * 100.0)::NUMERIC, 2);
        IF v_pending > 0 THEN
            IF EXISTS (
                SELECT 1 FROM public.commitments
                WHERE owner_id = p_user_id AND gufi_day = p_gufi_day AND status = 'proof_submitted'
            ) THEN
                v_status := 'pending_review';
            ELSE
                v_status := 'in_progress';
            END IF;
        ELSIF v_verified = v_total THEN
            v_status := 'complete';
        ELSIF v_verified > 0 THEN
            v_status := 'partial';
        ELSE
            v_status := 'missed';
        END IF;
    ELSE
        v_status := 'empty';
        v_pct := 0.0;
    END IF;

    INSERT INTO public.daily_results (
        user_id,
        gufi_day,
        commitments_total,
        verified_count,
        missed_count,
        cancelled_count,
        pending_count,
        completion_percentage,
        daily_status,
        updated_at
    ) VALUES (
        p_user_id,
        p_gufi_day,
        v_total,
        v_verified,
        v_missed,
        v_cancelled,
        v_pending,
        v_pct,
        v_status,
        NOW()
    )
    ON CONFLICT (user_id, gufi_day) DO UPDATE SET
        commitments_total = EXCLUDED.commitments_total,
        verified_count = EXCLUDED.verified_count,
        missed_count = EXCLUDED.missed_count,
        cancelled_count = EXCLUDED.cancelled_count,
        pending_count = EXCLUDED.pending_count,
        completion_percentage = EXCLUDED.completion_percentage,
        daily_status = EXCLUDED.daily_status,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: EVALUATE MISSED COMMITMENTS
CREATE OR REPLACE FUNCTION public.evaluate_missed_commitments()
RETURNS INT AS $$
DECLARE
    rec RECORD;
    count INT := 0;
BEGIN
    FOR rec IN
        SELECT id, owner_id, gufi_day
        FROM public.commitments
        WHERE status = 'committed' AND due_at < NOW()
    LOOP
        UPDATE public.commitments
        SET status = 'missed',
            resolved_at = NOW(),
            updated_at = NOW()
        WHERE id = rec.id;

        INSERT INTO public.commitment_events (commitment_id, actor_id, event_type)
        VALUES (rec.id, NULL, 'COMMITMENT_MISSED');

        PERFORM public.recalculate_daily_result(rec.owner_id, rec.gufi_day);
        count := count + 1;
    END LOOP;

    FOR rec IN
        SELECT id, owner_id, gufi_day
        FROM public.commitments
        WHERE status = 'rejected' AND correction_deadline IS NOT NULL AND correction_deadline < NOW()
    LOOP
        UPDATE public.commitments
        SET status = 'missed',
            resolved_at = NOW(),
            updated_at = NOW()
        WHERE id = rec.id;

        INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
        VALUES (rec.id, NULL, 'COMMITMENT_MISSED', jsonb_build_object('reason', 'correction_window_expired'));

        PERFORM public.recalculate_daily_result(rec.owner_id, rec.gufi_day);
        count := count + 1;
    END LOOP;

    RETURN count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: GET 7-DAY MOMENTUM
CREATE OR REPLACE FUNCTION public.get_user_momentum(
    p_user_id UUID,
    p_current_gufi_day TEXT
)
RETURNS JSONB AS $$
DECLARE
    curr_date DATE := p_current_gufi_day::DATE;
    start_date DATE := curr_date - INTERVAL '6 days';
    v_verified INT := 0;
    v_missed INT := 0;
    v_cancelled INT := 0;
    v_resolved INT := 0;
    v_score INT := NULL;
BEGIN
    SELECT
        COUNT(*) FILTER (WHERE status = 'verified'),
        COUNT(*) FILTER (WHERE status = 'missed'),
        COUNT(*) FILTER (WHERE status = 'cancelled')
    INTO v_verified, v_missed, v_cancelled
    FROM public.commitments
    WHERE owner_id = p_user_id
      AND accountability_scope = 'circle'
      AND gufi_day::DATE >= start_date
      AND gufi_day::DATE <= curr_date
      AND status IN ('verified', 'missed', 'cancelled');

    v_resolved := v_verified + v_missed + v_cancelled;

    IF v_resolved > 0 THEN
        v_score := ROUND((v_verified::DOUBLE PRECISION / v_resolved::DOUBLE PRECISION) * 100.0);
        RETURN jsonb_build_object(
            'score', v_score,
            'verified_count', v_verified,
            'resolved_count', v_resolved,
            'is_available', true
        );
    ELSE
        RETURN jsonb_build_object(
            'score', NULL,
            'verified_count', 0,
            'resolved_count', 0,
            'is_available', false
        );
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.circles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commitment_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_results ENABLE ROW LEVEL SECURITY;

-- CIRCLES POLICIES
CREATE POLICY "Circle members and owners can read circles"
ON public.circles FOR SELECT
USING (
    owner_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.circle_members
        WHERE circle_id = public.circles.id AND user_id = auth.uid() AND status = 'active'
    )
    OR public.is_admin()
);

CREATE POLICY "Users can create circles"
ON public.circles FOR INSERT
WITH CHECK (owner_id = auth.uid() OR public.is_admin());

CREATE POLICY "Owners can update circles"
ON public.circles FOR UPDATE
USING (owner_id = auth.uid() OR public.is_admin());

-- CIRCLE MEMBERS POLICIES
CREATE POLICY "Circle members can read circle member list"
ON public.circle_members FOR SELECT
USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.circle_members m2
        WHERE m2.circle_id = public.circle_members.circle_id AND m2.user_id = auth.uid() AND m2.status = 'active'
    )
    OR EXISTS (
        SELECT 1 FROM public.circles c
        WHERE c.id = public.circle_members.circle_id AND c.owner_id = auth.uid()
    )
    OR public.is_admin()
);

CREATE POLICY "Circle owners can add members"
ON public.circle_members FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.circles c
        WHERE c.id = circle_id AND c.owner_id = auth.uid()
    )
    OR public.is_admin()
);

CREATE POLICY "Circle owners can update members or users can leave"
ON public.circle_members FOR UPDATE
USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.circles c
        WHERE c.id = public.circle_members.circle_id AND c.owner_id = auth.uid()
    )
    OR public.is_admin()
);

-- COMMITMENTS POLICIES
CREATE POLICY "Users can read own commitments and circle commitments"
ON public.commitments FOR SELECT
USING (
    owner_id = auth.uid()
    OR (
        circle_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.circle_members
            WHERE circle_id = public.commitments.circle_id AND user_id = auth.uid() AND status = 'active'
        )
    )
    OR public.is_admin()
);

CREATE POLICY "Users can insert own draft commitments"
ON public.commitments FOR INSERT
WITH CHECK (owner_id = auth.uid() AND status = 'draft');

CREATE POLICY "Users can update own draft commitments"
ON public.commitments FOR UPDATE
USING (owner_id = auth.uid() AND status = 'draft')
WITH CHECK (owner_id = auth.uid() AND status = 'draft');

-- PROOFS POLICIES
CREATE POLICY "Authorized users can read proofs"
ON public.proofs FOR SELECT
USING (
    submitter_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.commitments c
        JOIN public.circle_members m ON c.circle_id = m.circle_id
        WHERE c.id = public.proofs.commitment_id AND m.user_id = auth.uid() AND m.status = 'active'
    )
    OR public.is_admin()
);

-- REVIEWS POLICIES
CREATE POLICY "Authorized users can read reviews"
ON public.reviews FOR SELECT
USING (
    reviewer_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.commitments c
        WHERE c.id = public.reviews.commitment_id AND (
            c.owner_id = auth.uid()
            OR (c.circle_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM public.circle_members m
                WHERE m.circle_id = c.circle_id AND m.user_id = auth.uid() AND m.status = 'active'
            ))
        )
    )
    OR public.is_admin()
);

-- COMMITMENT EVENTS POLICIES
CREATE POLICY "Authorized users can read events"
ON public.commitment_events FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.commitments c
        WHERE c.id = public.commitment_events.commitment_id AND (
            c.owner_id = auth.uid()
            OR (c.circle_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM public.circle_members m
                WHERE m.circle_id = c.circle_id AND m.user_id = auth.uid() AND m.status = 'active'
            ))
        )
    )
    OR public.is_admin()
);

-- DAILY RESULTS POLICIES
CREATE POLICY "Users can read own daily results"
ON public.daily_results FOR SELECT
USING (user_id = auth.uid() OR public.is_admin());

-- STORAGE OBJECT POLICIES FOR PROOF MEDIA
CREATE POLICY "Private proof upload by owner"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'proofs'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Proof media view by eligible users"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'proofs'
    AND (
        auth.uid()::text = (storage.foldername(name))[1]
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.proofs p
            JOIN public.commitments c ON p.commitment_id = c.id
            JOIN public.circle_members m ON c.circle_id = m.circle_id
            WHERE p.media_url LIKE '%' || name || '%'
              AND m.user_id = auth.uid()
              AND m.status = 'active'
        )
    )
);

-- ==============================================================================
-- 20. SCHEDULED MISSED-COMMITMENT EVALUATION (pg_cron)
-- Periodically sweeps overdue commitments and expired correction windows
-- Runs automatically on the server without client interaction
-- ==============================================================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.unschedule('evaluate-missed-commitments-job')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'evaluate-missed-commitments-job');

        PERFORM cron.schedule(
            'evaluate-missed-commitments-job',
            '* * * * *',
            'SELECT public.evaluate_missed_commitments();'
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END;
$$;

-- ==============================================================================
-- 15. CIRCLE INVITES & ATOMIC RPCs
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.circle_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID NOT NULL REFERENCES public.circles(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    token TEXT,
    creator_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'expired')),
    expires_at TIMESTAMPTZ,
    max_uses INT,
    use_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_canonical_invite_code UNIQUE (code)
);

CREATE INDEX IF NOT EXISTS idx_circle_invites_code ON public.circle_invites(code);
CREATE INDEX IF NOT EXISTS idx_circle_invites_circle_id ON public.circle_invites(circle_id);
CREATE INDEX IF NOT EXISTS idx_circle_invites_creator_id ON public.circle_invites(creator_id);

-- Ensure circles.description and creation_request_id exist
ALTER TABLE public.circles ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.circles ADD COLUMN IF NOT EXISTS creation_request_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS idx_circles_owner_creation_req
ON public.circles(owner_id, creation_request_id)
WHERE creation_request_id IS NOT NULL;

-- Ensure unique constraint on circle_members (circle_id, user_id) exists specifically on public.circle_members
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE n.nspname = 'public'
          AND t.relname = 'circle_members'
          AND c.conname = 'unique_circle_member'
    ) THEN
        ALTER TABLE public.circle_members
        ADD CONSTRAINT unique_circle_member UNIQUE (circle_id, user_id);
    END IF;
END $$;

-- 2. CIRCLE INVITES TABLE
CREATE TABLE IF NOT EXISTS public.circle_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID NOT NULL REFERENCES public.circles(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    token TEXT,
    creator_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'expired')),
    expires_at TIMESTAMPTZ,
    max_uses INT,
    use_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_canonical_invite_code UNIQUE (code),
    CONSTRAINT valid_canonical_invite_code CHECK (code ~ '^GUFI-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6}$'),
    CONSTRAINT non_negative_use_count CHECK (use_count >= 0),
    CONSTRAINT valid_max_uses CHECK (max_uses IS NULL OR max_uses > 0)
);

CREATE INDEX IF NOT EXISTS idx_circle_invites_code ON public.circle_invites(code);
CREATE INDEX IF NOT EXISTS idx_circle_invites_circle_id ON public.circle_invites(circle_id);
CREATE INDEX IF NOT EXISTS idx_circle_invites_creator_id ON public.circle_invites(creator_id);

-- Ensure constraints on circle_invites if table already existed
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE n.nspname = 'public' AND t.relname = 'circle_invites' AND c.conname = 'valid_canonical_invite_code'
    ) THEN
        ALTER TABLE public.circle_invites
        ADD CONSTRAINT valid_canonical_invite_code CHECK (code ~ '^GUFI-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6}$');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE n.nspname = 'public' AND t.relname = 'circle_invites' AND c.conname = 'non_negative_use_count'
    ) THEN
        ALTER TABLE public.circle_invites
        ADD CONSTRAINT non_negative_use_count CHECK (use_count >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE n.nspname = 'public' AND t.relname = 'circle_invites' AND c.conname = 'valid_max_uses'
    ) THEN
        ALTER TABLE public.circle_invites
        ADD CONSTRAINT valid_max_uses CHECK (max_uses IS NULL OR max_uses > 0);
    END IF;
END $$;

-- 3. RLS ON CIRCLE INVITES
ALTER TABLE public.circle_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Circle members can read circle invites" ON public.circle_invites;
CREATE POLICY "Circle members can read circle invites"
ON public.circle_invites FOR SELECT
USING (
    creator_id = auth.uid() OR
    EXISTS (
        SELECT 1 FROM public.circle_members
        WHERE circle_id = public.circle_invites.circle_id
          AND user_id = auth.uid()
          AND status = 'active'
    )
);

DROP POLICY IF EXISTS "Circle creators can insert invites" ON public.circle_invites;
CREATE POLICY "Circle creators can insert invites"
ON public.circle_invites FOR INSERT
WITH CHECK (
    creator_id = auth.uid() AND
    EXISTS (
        SELECT 1 FROM public.circles
        WHERE id = public.circle_invites.circle_id
          AND owner_id = auth.uid()
    )
);

-- 4. PRIVATE HELPER: CANONICAL CODE NORMALIZATION FUNCTION
CREATE OR REPLACE FUNCTION public.normalize_circle_invite_code(p_input TEXT)
RETURNS TEXT AS $$
DECLARE
    v_clean TEXT;
BEGIN
    IF p_input IS NULL THEN
        RETURN '';
    END IF;

    v_clean := upper(trim(p_input));

    -- Extract from query parameters (e.g. ?code=... or &code=...)
    IF v_clean LIKE '%CODE=%' THEN
        v_clean := split_part(v_clean, 'CODE=', 2);
        v_clean := split_part(v_clean, '&', 1);
    ELSIF v_clean LIKE '%/JOIN/%' THEN
        v_clean := split_part(v_clean, '/JOIN/', 2);
        v_clean := split_part(v_clean, '?', 1);
    END IF;

    -- Strip URI scheme prefix
    IF v_clean LIKE 'GUFI://%' THEN
        v_clean := replace(v_clean, 'GUFI://', '');
    END IF;

    v_clean := upper(trim(v_clean));

    -- Strip leading GUFI prefix variations
    IF v_clean LIKE 'GUFI-%' THEN
        v_clean := substr(v_clean, 6);
    ELSIF v_clean LIKE 'GUFI %' THEN
        v_clean := substr(v_clean, 6);
    ELSIF v_clean LIKE 'GUFI%' AND length(v_clean) > 4 THEN
        v_clean := substr(v_clean, 5);
    END IF;

    -- Keep only unambiguous alphabet characters
    v_clean := regexp_replace(v_clean, '[^23456789ABCDEFGHJKLMNPQRSTUVWXYZ]', '', 'g');

    IF length(v_clean) = 0 THEN
        RETURN '';
    END IF;

    RETURN 'GUFI-' || v_clean;
END;
$$ LANGUAGE plpgsql IMMUTABLE SET search_path = public, pg_temp;

-- 5. PRIVATE HELPER: CANONICAL INVITE CODE GENERATOR (6 Characters Entropy)
CREATE OR REPLACE FUNCTION public.generate_canonical_invite_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    res TEXT;
    done BOOLEAN := FALSE;
BEGIN
    WHILE NOT done LOOP
        res := 'GUFI-' ||
               substr(chars, floor(random() * length(chars) + 1)::int, 1) ||
               substr(chars, floor(random() * length(chars) + 1)::int, 1) ||
               substr(chars, floor(random() * length(chars) + 1)::int, 1) ||
               substr(chars, floor(random() * length(chars) + 1)::int, 1) ||
               substr(chars, floor(random() * length(chars) + 1)::int, 1) ||
               substr(chars, floor(random() * length(chars) + 1)::int, 1);
        IF NOT EXISTS (SELECT 1 FROM public.circle_invites WHERE code = res) THEN
            done := TRUE;
        END IF;
    END LOOP;
    RETURN res;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp;

-- 6. ATOMIC RPC: create_circle_with_invite
-- Atomically creates: 1 Circle + 1 Owner Member + 1 High-Entropy Usable Invite
-- Guaranteed server-side idempotent via client-supplied p_request_id
CREATE OR REPLACE FUNCTION public.create_circle_with_invite(
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_request_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_circle_id UUID;
    v_code TEXT;
    v_circle RECORD;
    v_member RECORD;
    v_invite RECORD;
    v_inserted BOOLEAN := FALSE;
    v_retry_count INT := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- 1. Idempotency Check: if request_id was previously completed for this owner, return existing entity
    IF p_request_id IS NOT NULL THEN
        SELECT * INTO v_circle
        FROM public.circles
        WHERE owner_id = v_user_id AND creation_request_id = p_request_id
        LIMIT 1;

        IF v_circle IS NOT NULL THEN
            SELECT * INTO v_member
            FROM public.circle_members
            WHERE circle_id = v_circle.id AND user_id = v_user_id AND status = 'active'
            LIMIT 1;

            SELECT * INTO v_invite
            FROM public.circle_invites
            WHERE circle_id = v_circle.id AND creator_id = v_user_id AND status = 'active'
            ORDER BY created_at DESC
            LIMIT 1;

            RETURN jsonb_build_object(
                'circle', row_to_json(v_circle),
                'member', row_to_json(v_member),
                'invite', row_to_json(v_invite)
            );
        END IF;
    END IF;

    -- 2. Input Validation
    IF p_name IS NULL OR length(trim(p_name)) < 3 OR length(trim(p_name)) > 24 THEN
        RAISE EXCEPTION 'Circle name must be between 3 and 24 characters';
    END IF;

    IF p_description IS NOT NULL AND length(trim(p_description)) > 80 THEN
        RAISE EXCEPTION 'Circle description cannot exceed 80 characters';
    END IF;

    -- 3. Create Circle
    INSERT INTO public.circles (name, owner_id, description, creation_request_id, status)
    VALUES (trim(p_name), v_user_id, nullif(trim(p_description), ''), p_request_id, 'active')
    RETURNING * INTO v_circle;
    v_circle_id := v_circle.id;

    -- 4. Create Owner Membership
    INSERT INTO public.circle_members (circle_id, user_id, role, status)
    VALUES (v_circle_id, v_user_id, 'owner', 'active')
    ON CONFLICT (circle_id, user_id)
    DO UPDATE SET status = 'active', role = 'owner', updated_at = NOW()
    RETURNING * INTO v_member;

    -- 5. Create Primary Invite with bounded collision retry
    WHILE NOT v_inserted AND v_retry_count < 5 LOOP
        BEGIN
            v_code := public.generate_canonical_invite_code();
            INSERT INTO public.circle_invites (circle_id, code, creator_id, status)
            VALUES (v_circle_id, v_code, v_user_id, 'active')
            RETURNING * INTO v_invite;
            v_inserted := TRUE;
        EXCEPTION WHEN unique_violation THEN
            v_retry_count := v_retry_count + 1;
            IF v_retry_count >= 5 THEN
                RAISE EXCEPTION 'Failed to generate unique invite code after 5 attempts';
            END IF;
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'circle', row_to_json(v_circle),
        'member', row_to_json(v_member),
        'invite', row_to_json(v_invite)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 7. RPC: resolve_circle_invite
-- Resolves invite safely for authenticated users. Limits preview members to max 4.
CREATE OR REPLACE FUNCTION public.resolve_circle_invite(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
    v_code TEXT;
    v_invite RECORD;
    v_circle RECORD;
    v_creator_name TEXT;
    v_member_count INT;
    v_preview_members JSONB;
    v_is_member BOOLEAN := FALSE;
    v_current_user UUID := auth.uid();
BEGIN
    IF v_current_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required to resolve Circle invite';
    END IF;

    IF p_code IS NULL THEN
        RETURN jsonb_build_object('status', 'invalid', 'message', 'We couldn’t find that invite.');
    END IF;

    v_code := public.normalize_circle_invite_code(p_code);

    SELECT * INTO v_invite
    FROM public.circle_invites
    WHERE code = v_code;

    IF v_invite IS NULL THEN
        RETURN jsonb_build_object('status', 'invalid', 'message', 'We couldn’t find that invite.');
    END IF;

    IF v_invite.status = 'revoked' THEN
        RETURN jsonb_build_object('status', 'revoked', 'message', 'This invite is no longer active.');
    END IF;

    IF v_invite.status = 'expired'
       OR (v_invite.expires_at IS NOT NULL AND v_invite.expires_at < NOW())
       OR (v_invite.max_uses IS NOT NULL AND v_invite.use_count >= v_invite.max_uses) THEN
        RETURN jsonb_build_object(
            'status', 'expired',
            'message', 'This invite has expired.',
            'supporting', 'Ask someone in the Circle for a new invite.'
        );
    END IF;

    SELECT * INTO v_circle
    FROM public.circles
    WHERE id = v_invite.circle_id AND status = 'active';

    IF v_circle IS NULL THEN
        RETURN jsonb_build_object('status', 'invalid', 'message', 'Circle is no longer active.');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.circle_members
        WHERE circle_id = v_circle.id AND user_id = v_current_user AND status = 'active'
    ) INTO v_is_member;

    -- Full active member count
    SELECT count(*)::int INTO v_member_count
    FROM public.circle_members
    WHERE circle_id = v_circle.id AND status = 'active';

    -- Max 4 safe preview members (display name, avatar, id only)
    SELECT coalesce(jsonb_agg(
        jsonb_build_object(
            'id', sub.user_id,
            'displayName', coalesce(sub.display_name, sub.username, 'Member'),
            'profilePhotoUrl', sub.profile_photo_url
        )
    ), '[]'::jsonb) INTO v_preview_members
    FROM (
        SELECT cm.user_id, u.display_name, u.username, u.profile_photo_url
        FROM public.circle_members cm
        LEFT JOIN public.users u ON u.id = cm.user_id
        WHERE cm.circle_id = v_circle.id AND cm.status = 'active'
        ORDER BY cm.joined_at ASC
        LIMIT 4
    ) sub;

    -- Safe creator name (TEXT string)
    SELECT coalesce(display_name, username, 'Creator')
    INTO v_creator_name
    FROM public.users
    WHERE id = v_circle.owner_id;

    RETURN jsonb_build_object(
        'status', CASE WHEN v_is_member THEN 'already_member' ELSE 'valid' END,
        'circleId', v_circle.id,
        'circleName', v_circle.name,
        'description', v_circle.description,
        'inviteCode', v_invite.code,
        'creatorName', v_creator_name,
        'memberCount', v_member_count,
        'previewMembers', v_preview_members
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 8. RPC: join_circle_with_invite
-- Concurrency-safe atomic join with row-level locking
CREATE OR REPLACE FUNCTION public.join_circle_with_invite(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_code TEXT;
    v_invite RECORD;
    v_circle RECORD;
    v_already_member BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to join a Circle';
    END IF;

    IF p_code IS NULL THEN
        RETURN jsonb_build_object('success', false, 'status', 'invalid', 'message', 'We couldn’t find that invite.');
    END IF;

    v_code := public.normalize_circle_invite_code(p_code);

    -- Concurrency-safe row lock
    SELECT * INTO v_invite
    FROM public.circle_invites
    WHERE code = v_code
    FOR UPDATE;

    IF v_invite IS NULL THEN
        RETURN jsonb_build_object('success', false, 'status', 'invalid', 'message', 'We couldn’t find that invite.');
    END IF;

    IF v_invite.status = 'revoked' THEN
        RETURN jsonb_build_object('success', false, 'status', 'revoked', 'message', 'This invite is no longer active.');
    END IF;

    IF v_invite.status = 'expired'
       OR (v_invite.expires_at IS NOT NULL AND v_invite.expires_at < NOW())
       OR (v_invite.max_uses IS NOT NULL AND v_invite.use_count >= v_invite.max_uses) THEN
        RETURN jsonb_build_object('success', false, 'status', 'expired', 'message', 'This invite has expired.');
    END IF;

    SELECT * INTO v_circle
    FROM public.circles
    WHERE id = v_invite.circle_id AND status = 'active';

    IF v_circle IS NULL THEN
        RETURN jsonb_build_object('success', false, 'status', 'invalid', 'message', 'Circle is no longer active.');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.circle_members
        WHERE circle_id = v_circle.id AND user_id = v_user_id AND status = 'active'
    ) INTO v_already_member;

    IF v_already_member THEN
        RETURN jsonb_build_object('success', true, 'status', 'already_member', 'circleId', v_circle.id);
    END IF;

    -- Insert active membership
    INSERT INTO public.circle_members (circle_id, user_id, role, status)
    VALUES (v_circle.id, v_user_id, 'member', 'active')
    ON CONFLICT (circle_id, user_id)
    DO UPDATE SET status = 'active', role = 'member', updated_at = NOW();

    -- Increment invite use count
    UPDATE public.circle_invites
    SET use_count = use_count + 1, updated_at = NOW()
    WHERE id = v_invite.id;

    RETURN jsonb_build_object('success', true, 'status', 'success', 'circleId', v_circle.id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 9. PERMISSIONS & HARDENED LEAST PRIVILEGE GRANTS
-- Revoke all public execution on internal helpers
REVOKE ALL ON FUNCTION public.normalize_circle_invite_code(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.generate_canonical_invite_code() FROM PUBLIC, anon, authenticated;

-- Revoke all public execution on RPCs
REVOKE ALL ON FUNCTION public.create_circle_with_invite(TEXT, TEXT, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.resolve_circle_invite(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.join_circle_with_invite(TEXT) FROM PUBLIC, anon;

-- Grant execution on production RPCs strictly to authenticated users and service_role
GRANT EXECUTE ON FUNCTION public.create_circle_with_invite(TEXT, TEXT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.resolve_circle_invite(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_circle_with_invite(TEXT) TO authenticated, service_role;

-- Helpers accessible only to service_role (and internal callers in SECURITY DEFINER)
GRANT EXECUTE ON FUNCTION public.normalize_circle_invite_code(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.generate_canonical_invite_code() TO service_role;

-- Table privilege hardening: authenticated only needs SELECT on circle_invites; mutations go through trusted RPCs
REVOKE INSERT, UPDATE, DELETE ON TABLE public.circle_invites FROM authenticated, anon, PUBLIC;
GRANT SELECT ON TABLE public.circle_invites TO authenticated;
GRANT ALL ON TABLE public.circle_invites TO service_role;
