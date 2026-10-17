-- ==============================================================================
-- GUFI CORE PRODUCT DOMAIN MIGRATION
-- Circles, Circle Members, Commitments, Proofs, Reviews, Events, Daily Results
-- ==============================================================================

-- 1. CIRCLES TABLE
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

-- 2. CIRCLE MEMBERS TABLE
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

-- 3. COMMITMENTS TABLE
CREATE TABLE IF NOT EXISTS public.commitments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    circle_id UUID REFERENCES public.circles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    proof_type TEXT NOT NULL CHECK (proof_type IN ('photo', 'text')),
    gufi_day TEXT NOT NULL, -- Format: YYYY-MM-DD
    due_at TIMESTAMPTZ NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    status TEXT NOT NULL DEFAULT 'draft' CHECK (
        status IN ('draft', 'committed', 'proof_submitted', 'rejected', 'verified', 'missed', 'cancelled')
    ),
    committed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    resolved_at TIMESTAMPTZ,
    correction_deadline TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_commitments_owner_day ON public.commitments(owner_id, gufi_day);
CREATE INDEX IF NOT EXISTS idx_commitments_circle_day ON public.commitments(circle_id, gufi_day);
CREATE INDEX IF NOT EXISTS idx_commitments_status ON public.commitments(status);
CREATE INDEX IF NOT EXISTS idx_commitments_due_at ON public.commitments(due_at);

-- 4. PROOFS TABLE
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

-- 5. REVIEWS TABLE
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

-- 6. COMMITMENT EVENTS TABLE (Immutable stream)
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

-- 7. DAILY RESULTS TABLE
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

-- 8. STORAGE BUCKET FOR PROOFS (Private)
INSERT INTO storage.buckets (id, name, public)
VALUES ('proofs', 'proofs', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- 9. TRIGGERS FOR UPDATED_AT
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

-- 10. TRIGGER: AUTO-ADD CIRCLE OWNER AS MEMBER
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

-- 11. RPC: AUTHORITATIVE GUFI DAY CONVERSION
-- Rule: Gufi day runs from 04:00 local time to 03:59:59.999 next calendar day.
CREATE OR REPLACE FUNCTION public.get_gufi_day(
    p_timestamp TIMESTAMPTZ,
    p_timezone TEXT DEFAULT 'UTC'
)
RETURNS TEXT AS $$
DECLARE
    local_ts TIMESTAMP;
BEGIN
    local_ts := p_timestamp AT TIME ZONE p_timezone;
    -- If local hour is before 4 AM, it belongs to the previous calendar day
    IF EXTRACT(HOUR FROM local_ts) < 4 THEN
        RETURN to_char((local_ts - INTERVAL '1 day')::DATE, 'YYYY-MM-DD');
    ELSE
        RETURN to_char(local_ts::DATE, 'YYYY-MM-DD');
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 12. RPC: ATOMIC COMMIT COMMITMENT (ENFORCING MAX 3 COMMITMENTS PER GUFI DAY)
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

    -- Select and lock commitment row
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

    -- Lock and check daily limit for this user on this gufi_day
    SELECT COUNT(*) INTO active_count
    FROM public.commitments
    WHERE owner_id = curr_user
      AND gufi_day = c_rec.gufi_day
      AND status != 'draft';

    IF active_count >= 3 THEN
        RAISE EXCEPTION 'Daily limit reached: maximum 3 commitments per Gufi day';
    END IF;

    -- Transition state
    UPDATE public.commitments
    SET status = 'committed',
        committed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_commitment_id;

    -- Log event
    INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
    VALUES (p_commitment_id, curr_user, 'COMMITMENT_COMMITTED', jsonb_build_object('gufi_day', c_rec.gufi_day));

    -- Recompute daily results
    PERFORM public.recalculate_daily_result(curr_user, c_rec.gufi_day);

    RETURN jsonb_build_object('success', true, 'status', 'committed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. RPC: SUBMIT PROOF
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

    -- Check if rejected and correction deadline expired
    IF c_rec.status = 'rejected' AND c_rec.correction_deadline IS NOT NULL AND NOW() > c_rec.correction_deadline THEN
        RAISE EXCEPTION 'Correction window has expired for this commitment';
    END IF;

    -- Validate proof payload
    IF p_proof_type != c_rec.proof_type THEN
        RAISE EXCEPTION 'Proof type does not match commitment proof type';
    END IF;

    IF p_proof_type = 'text' AND (p_text_content IS NULL OR length(trim(p_text_content)) = 0) THEN
        RAISE EXCEPTION 'Text content is required for text proof';
    END IF;

    IF p_proof_type = 'photo' AND (p_media_url IS NULL OR length(trim(p_media_url)) = 0) THEN
        RAISE EXCEPTION 'Media URL is required for photo proof';
    END IF;

    -- Supersede any previous active proofs
    UPDATE public.proofs
    SET status = 'superseded'
    WHERE commitment_id = p_commitment_id AND status = 'submitted';

    -- Insert new proof
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

    -- Update commitment status to proof_submitted
    UPDATE public.commitments
    SET status = 'proof_submitted',
        correction_deadline = NULL,
        updated_at = NOW()
    WHERE id = p_commitment_id;

    -- Record event
    INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
    VALUES (p_commitment_id, curr_user, event_name, jsonb_build_object('proof_id', proof_id));

    PERFORM public.recalculate_daily_result(curr_user, c_rec.gufi_day);

    RETURN jsonb_build_object('success', true, 'proof_id', proof_id, 'status', 'proof_submitted');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 14. RPC: REVIEW PROOF (1 APPROVAL IS ENOUGH)
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

    -- Fetch proof and commitment
    SELECT * INTO p_rec FROM public.proofs WHERE id = p_proof_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proof not found';
    END IF;

    SELECT * INTO c_rec FROM public.commitments WHERE id = p_rec.commitment_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commitment not found';
    END IF;

    -- Rule: Owner cannot review own proof
    IF c_rec.owner_id = curr_user THEN
        RAISE EXCEPTION 'Owner cannot review their own proof';
    END IF;

    -- Rule: Reviewer must be an active member of the commitment circle
    IF c_rec.circle_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.circle_members
            WHERE circle_id = c_rec.circle_id AND user_id = curr_user AND status = 'active'
        ) INTO is_member;

        IF NOT is_member THEN
            RAISE EXCEPTION 'Unauthorized: only active circle members can review';
        END IF;
    END IF;

    -- Rule: Must be currently awaiting review
    IF c_rec.status != 'proof_submitted' THEN
        RAISE EXCEPTION 'Commitment is not in proof_submitted state';
    END IF;

    -- Rule: Rejection requires a reason
    IF p_decision = 'rejected' AND (p_reason IS NULL OR length(trim(p_reason)) = 0) THEN
        RAISE EXCEPTION 'Rejection requires a reason';
    END IF;

    -- Insert review (unique constraint ensures 1 review per reviewer/proof)
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
        -- VERIFIED
        UPDATE public.commitments
        SET status = 'verified',
            resolved_at = NOW(),
            correction_deadline = NULL,
            updated_at = NOW()
        WHERE id = c_rec.id;

        INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
        VALUES (c_rec.id, curr_user, 'PROOF_VERIFIED', jsonb_build_object('review_id', review_id));
    ELSE
        -- REJECTED: If submitted on time, 6-hour correction window
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

-- 15. RPC: CANCEL COMMITMENT
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

-- 16. RPC: RECALCULATE DAILY RESULT
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

-- 17. RPC: EVALUATE MISSED COMMITMENTS (Scheduled server sweep)
CREATE OR REPLACE FUNCTION public.evaluate_missed_commitments()
RETURNS INT AS $$
DECLARE
    rec RECORD;
    count INT := 0;
BEGIN
    -- 1. Committed items where due_at has passed and no proof submitted
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

    -- 2. Rejected items where correction deadline has passed
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

-- 18. RPC: GET 7-DAY MOMENTUM
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

-- 19. ROW LEVEL SECURITY (RLS) POLICIES
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
            -- Ensure viewer belongs to the same circle as the commitment referencing this media
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
