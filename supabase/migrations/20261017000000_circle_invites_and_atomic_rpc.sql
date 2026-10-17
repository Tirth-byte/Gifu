-- ==============================================================================
-- GUFI MIGRATION: 20261017000000_circle_invites_and_atomic_rpc.sql
-- Canonical Circle Invites & Hardened Server-Side Atomic RPCs
-- ==============================================================================

-- 1. EXTENSIONS & SCHEMA ENSURANCE
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
-- Unprivileged utility helper for parsing invite formats
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
