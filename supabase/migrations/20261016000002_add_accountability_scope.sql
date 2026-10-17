-- ==============================================================================
-- GUFI MIGRATION: ADD ACCOUNTABILITY SCOPE (CIRCLE VS PRIVATE)
-- ==============================================================================

-- 1. Add accountability_scope column
ALTER TABLE public.commitments
ADD COLUMN IF NOT EXISTS accountability_scope TEXT NOT NULL DEFAULT 'circle'
CHECK (accountability_scope IN ('circle', 'private'));

-- Backfill legacy records
UPDATE public.commitments
SET accountability_scope = 'private'
WHERE circle_id IS NULL;

-- 2. Update status constraint to include 'completed' for private promises
ALTER TABLE public.commitments DROP CONSTRAINT IF EXISTS commitments_status_check;
ALTER TABLE public.commitments ADD CONSTRAINT commitments_status_check
CHECK (status IN ('draft', 'committed', 'proof_submitted', 'rejected', 'verified', 'completed', 'missed', 'cancelled'));

-- 3. Enforce scope consistency with circle_id
ALTER TABLE public.commitments DROP CONSTRAINT IF EXISTS check_accountability_circle;
ALTER TABLE public.commitments ADD CONSTRAINT check_accountability_circle
CHECK (
    (accountability_scope = 'circle' AND circle_id IS NOT NULL) OR
    (accountability_scope = 'private' AND circle_id IS NULL)
);

-- 4. Update submit_proof RPC to handle private promises
CREATE OR REPLACE FUNCTION public.submit_proof(
    p_commitment_id UUID,
    p_submitter_id UUID,
    p_proof_type TEXT,
    p_text_content TEXT DEFAULT NULL,
    p_media_url TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_commitment RECORD;
    v_proof_id UUID;
    v_target_status TEXT;
BEGIN
    SELECT * INTO v_commitment
    FROM public.commitments
    WHERE id = p_commitment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commitment not found';
    END IF;

    IF v_commitment.owner_id != p_submitter_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF v_commitment.status NOT IN ('committed', 'rejected') THEN
        RAISE EXCEPTION 'Proof cannot be submitted in status %', v_commitment.status;
    END IF;

    IF p_proof_type = 'text' AND (p_text_content IS NULL OR length(trim(p_text_content)) = 0) THEN
        RAISE EXCEPTION 'Text content is required for text proof';
    END IF;

    IF p_proof_type = 'photo' AND (p_media_url IS NULL OR length(trim(p_media_url)) = 0) THEN
        RAISE EXCEPTION 'Media URL is required for photo proof';
    END IF;

    -- Supersede prior submitted proofs
    UPDATE public.proofs
    SET status = 'superseded'
    WHERE commitment_id = p_commitment_id AND status = 'submitted';

    -- Insert new proof
    INSERT INTO public.proofs (commitment_id, submitter_id, proof_type, text_content, media_url, submitted_at, status)
    VALUES (p_commitment_id, p_submitter_id, p_proof_type, trim(p_text_content), trim(p_media_url), NOW(), 'submitted')
    RETURNING id INTO v_proof_id;

    -- If private, transition to completed directly without peer review
    IF v_commitment.accountability_scope = 'private' THEN
        v_target_status := 'completed';
        UPDATE public.commitments
        SET status = 'completed',
            proof_type = p_proof_type,
            resolved_at = NOW(),
            correction_deadline = NULL,
            updated_at = NOW()
        WHERE id = p_commitment_id;
    ELSE
        v_target_status := 'proof_submitted';
        UPDATE public.commitments
        SET status = 'proof_submitted',
            proof_type = p_proof_type,
            correction_deadline = NULL,
            updated_at = NOW()
        WHERE id = p_commitment_id;
    END IF;

    -- Insert audit event
    INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
    VALUES (p_commitment_id, p_submitter_id, 'proof_submitted', jsonb_build_object('proof_id', v_proof_id, 'target_status', v_target_status));

    PERFORM public.recalculate_daily_result(v_commitment.owner_id, v_commitment.gufi_day);

    RETURN jsonb_build_object(
        'success', true,
        'proof_id', v_proof_id,
        'commitment_status', v_target_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Update get_user_momentum to ONLY calculate from circle commitments (verified Momentum)
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
