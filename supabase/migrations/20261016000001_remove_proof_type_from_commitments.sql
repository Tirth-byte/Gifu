-- Migration: 20261016000001_remove_proof_type_from_commitments.sql
-- Purpose: Decouple proof format from commitment creation.
-- Commitments represent WHAT is promised, WHO holds accountability, and WHEN it is due.
-- Proof type belongs to the actual completion proof submitted by the user.

-- 1. Make proof_type column optional on public.commitments
ALTER TABLE public.commitments ALTER COLUMN proof_type DROP NOT NULL;

-- 2. Update submit_proof RPC to remove proof_type mismatch check
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

    -- Validate proof type
    IF p_proof_type NOT IN ('photo', 'text') THEN
        RAISE EXCEPTION 'Invalid proof type: must be photo or text';
    END IF;

    -- Validate proof payload
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

    -- Update commitment status to proof_submitted and track submitted proof_type
    UPDATE public.commitments
    SET status = 'proof_submitted',
        proof_type = p_proof_type,
        correction_deadline = NULL,
        updated_at = NOW()
    WHERE id = p_commitment_id;

    -- Record event
    INSERT INTO public.commitment_events (commitment_id, actor_id, event_type, metadata)
    VALUES (p_commitment_id, curr_user, event_name, jsonb_build_object('proof_id', proof_id, 'proof_type', p_proof_type));

    PERFORM public.recalculate_daily_result(curr_user, c_rec.gufi_day);

    RETURN jsonb_build_object('proof_id', proof_id, 'status', 'proof_submitted');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
