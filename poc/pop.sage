#!/usr/bin/sage
# vim: syntax=python
#
# The composed, non-interactive Schnorr-type ECDSA PoP:
#
#     PoP = ( SM x PA ) o group o transfer
#
# Statement (verifier): credential-curve commitments C_cred to the four
# 128-bit limbs [x_0, x_1, y_0, y_1] of Q, the ECDSA message, a context string.
# Witness   (prover):   Q, the limb openings, and an ECDSA signature (r, s) on
# the message under Q.

try:
    from sagelib.groups import (P256, Tom256, BLS12_381_G1, Pedersen, DeserializeError,
                                smul, point_coords, commit_point, random_point_randomness, i2osp, os2ip)
    from sagelib.transcript import Transcript, bytes_to_bits, bytes_to_scalar
    from sagelib.transfer import CommitmentTransfer, B_M, B_C, B_F
    from sagelib.point_addition import PointAddition
    from sagelib.scalar_mult import ScalarMultiplication
    from sagelib import ecdsa
except ImportError as e:
    import sys
    sys.exit("Error loading preprocessed sage files. Try running `make setup && make clean pyfiles`. Full error: " + str(e))

SUITE_ID = b"ECDSA-PoP-P256-SHA256_Tom256_BLS12381G1-v0"
LIMB_BITS = 128
NUM_LIMBS = 4
DEFAULT_LAMBDA = 128


class PublicParams(object):
    def __init__(self, lam=DEFAULT_LAMBDA):
        self.lam = lam
        self.tom = Pedersen.derive(Tom256, SUITE_ID + b"/tom-generators")
        self.cred = Pedersen.derive(BLS12_381_G1, SUITE_ID + b"/credential-generators")
        self.transfer = CommitmentTransfer(self.cred, self.tom, B_M, B_C, B_F)
        self.sm = ScalarMultiplication(self.tom)
        self.pa = PointAddition(self.tom, open_ay=True)


# Public-key encoding and credential-layer commitments
def encode_public_key(Q):
    """Q = (x, y) -> [x_0, x_1, y_0, y_1], 128-bit little-endian limbs."""
    x, y = Q.xy()
    x, y = Integer(x), Integer(y)
    mask = 2**LIMB_BITS - 1
    return [x & mask, x >> LIMB_BITS, y & mask, y >> LIMB_BITS]


def credential_commit(pp, Q, rng):
    """Stand-in for the credential layer (e.g. BBS CoreProofGen): one Pedersen
    commitment per limb over BLS12-381 G1. Returns (commitments, randomness)."""
    limbs = encode_public_key(Q)
    rho = [pp.cred.random(rng) for _ in limbs]
    return [pp.cred.commit(m, r) for m, r in zip(limbs, rho)], rho


class Proof(object):
    def __init__(self, K, transfer_com, transfer_resp, C_Z, sm_com, pa_com, sm_resp, pa_resp):
        self.K = K
        self.transfer_com = transfer_com    # (Ct[4], A[4], At[4])
        self.transfer_resp = transfer_resp  # (z[4], s[4], st[4])
        self.C_Z = C_Z                      # (C_Zx, C_Zy)
        self.sm_com = sm_com                # lam x (C', C'', (C_tau, A[6]))
        self.pa_com = pa_com                # (C_tau, A[7])
        self.sm_resp = sm_resp              # lam x (alpha, (tau_x, tau_y), msg2[9])
        self.pa_resp = pa_resp              # [11]


class _Writer(object):
    def __init__(self):
        self.buf = bytearray()

    def el(self, G, *Ps):
        for P in Ps:
            self.buf += G.serialize(P)

    def sc(self, G, *ss):
        for s in ss:
            self.buf += G.serialize_scalar(s)

    def raw_int(self, v, n):
        self.buf += i2osp(v, n)


class _Reader(object):
    def __init__(self, data):
        self.data = bytes(data)
        self.off = 0

    def _take(self, n):
        n = int(n)
        if self.off + n > len(self.data):
            raise DeserializeError("truncated proof")
        out = self.data[self.off:self.off + n]
        self.off += n
        return out

    def el(self, G, k=None):
        if k is None:
            return G.deserialize(self._take(G.element_len()))
        return [self.el(G) for _ in range(k)]

    def sc(self, G, k=None):
        if k is None:
            return G.deserialize_scalar(self._take(G.scalar_len))
        return [self.sc(G) for _ in range(k)]

    def raw_int(self, n):
        return os2ip(self._take(n))

    def done(self):
        if self.off != len(self.data):
            raise DeserializeError("trailing bytes")


def serialize_proof(pp, pf):
    T, B, Pq = Tom256, BLS12_381_G1, P256
    w = _Writer()
    w.el(Pq, pf.K)
    Ct, A, At = pf.transfer_com
    w.el(T, *Ct); w.el(B, *A); w.el(T, *At)
    w.el(T, *pf.C_Z)
    for C1, C2, (C_tau, Apa) in pf.sm_com:
        w.el(T, *C1); w.el(T, *C2); w.el(T, C_tau); w.el(T, *Apa)
    C_tau, Apa = pf.pa_com
    w.el(T, C_tau); w.el(T, *Apa)
    z, s, st = pf.transfer_resp
    for z_i in z:
        w.raw_int(z_i, pp.transfer.z_len)
    w.sc(B, *s); w.sc(T, *st)
    for alpha, tau, msg2 in pf.sm_resp:
        w.sc(Pq, alpha); w.sc(T, *tau); w.sc(T, *msg2)
    w.sc(T, *pf.pa_resp)
    return bytes(w.buf)


def deserialize_proof(pp, data):
    T, B, Pq = Tom256, BLS12_381_G1, P256
    r = _Reader(data)
    K = r.el(Pq)
    transfer_com = (r.el(T, NUM_LIMBS), r.el(B, NUM_LIMBS), r.el(T, NUM_LIMBS))
    C_Z = tuple(r.el(T, 2))
    nsm = pp.sm.pa.num_equations()
    sm_com = []
    for _ in range(pp.lam):
        C1 = tuple(r.el(T, 2)); C2 = tuple(r.el(T, 2))
        sm_com.append((C1, C2, (r.el(T), r.el(T, nsm))))
    pa_com = (r.el(T), r.el(T, pp.pa.num_equations()))
    z = [r.raw_int(pp.transfer.z_len) for _ in range(NUM_LIMBS)]
    transfer_resp = (z, r.sc(B, NUM_LIMBS), r.sc(T, NUM_LIMBS))
    sm_resp = []
    for _ in range(pp.lam):
        sm_resp.append((r.sc(Pq), tuple(r.sc(T, 2)), r.sc(T, pp.sm.pa.num_scalars())))
    pa_resp = r.sc(T, pp.pa.num_scalars())
    r.done()
    return Proof(K, transfer_com, transfer_resp, C_Z, sm_com, pa_com, sm_resp, pa_resp)


def _init_transcript(pp, C_cred, msg, ctx, K):
    ts = Transcript(SUITE_ID)
    ts.absorb(b"params", i2osp(pp.lam, 2) + i2osp(B_M, 2) + i2osp(B_C, 2) + i2osp(B_F, 2))
    ts.absorb(b"ctx", ctx)
    ts.absorb(b"msg", msg)
    ts.absorb_elements(b"cred-commitments", BLS12_381_G1, C_cred)
    ts.absorb_elements(b"K", P256, [K])
    return ts


def _transfer_challenge(pp, ts, transfer_com):
    Ct, A, At = transfer_com
    ts.absorb_elements(b"transfer/tom-commitments", Tom256, Ct)
    ts.absorb_elements(b"transfer/announcement-cred", BLS12_381_G1, A)
    ts.absorb_elements(b"transfer/announcement-tom", Tom256, At)
    nbytes = (B_C + 7) // 8
    return os2ip(ts.squeeze(b"transfer/challenge", nbytes)) % 2**B_C


def _smpa_challenges(pp, ts, C_Z, sm_com, pa_com):
    """Single hash call for SM x PA: lam challenge bits for SM, one F_q challenge for PA."""
    ts.absorb_elements(b"group/C_Z", Tom256, C_Z)
    flat = []
    for C1, C2, (C_tau, Apa) in sm_com:
        flat += list(C1) + list(C2) + [C_tau] + list(Apa)
    ts.absorb_elements(b"sm/commitments", Tom256, flat)
    ts.absorb_elements(b"pa/commitment", Tom256, [pa_com[0]] + list(pa_com[1]))
    nbits_bytes = (pp.lam + 7) // 8
    out = ts.squeeze(b"sm-x-pa/challenge", nbits_bytes + Tom256.scalar_len + 16)
    bits = bytes_to_bits(out[:nbits_bytes], pp.lam)
    c_pa = bytes_to_scalar(out[nbits_bytes:], Tom256.order)
    return bits, c_pa


def _pa_statement(C_Q, C_H, C_Z):
    # statement_PA = (C_Q, C_H, C_Z): P_1 = Q, P_2 = Hpt, P_3 = Z
    return list(C_Q) + list(C_H) + list(C_Z)


def prove(pp, Q, msg, sig, C_cred, rho_cred, rng, ctx=b""):
    Fq = Tom256.Fs
    K, z = ecdsa.to_kz(Q, msg, sig)
    alpha, Hpt = ecdsa.hpt(K, msg)
    assert smul(z, K) == Hpt + Q  # (Eq. POP)
    if point_coords(Q, Fq)[0] == point_coords(Hpt, Fq)[0]:
        raise ValueError("degenerate statement: Q = +-Hpt")

    ts0 = _init_transcript(pp, C_cred, msg, ctx, K)

    limbs = encode_public_key(Q)
    while True:
        ts = ts0.copy()
        transfer_com, transfer_state = pp.transfer.prover_commit(limbs, rho_cred, rng)
        c = _transfer_challenge(pp, ts, transfer_com)
        transfer_resp = pp.transfer.prover_response(transfer_state, c)
        if transfer_resp is not None:
            break
    C_Q = pp.transfer.fold(transfer_com[0])
    rho_Q = pp.transfer.fold_randomness(transfer_state)

    Z = smul(z, K)
    rho_Z = random_point_randomness(pp.tom, rng)
    C_Z = commit_point(pp.tom, Z, rho_Z)
    C_H = commit_point(pp.tom, Hpt, (Fq(0), Fq(0)))

    sm_com, sm_state = [], []
    for _ in range(pp.lam):
        com, st = pp.sm.prover_commit(K, C_Z, Z, z, rho_Z, rng)
        sm_com.append(com)
        sm_state.append(st)
    pa_values = point_coords(Q, Fq) + point_coords(Hpt, Fq) + point_coords(Z, Fq)
    pa_rands = tuple(rho_Q) + (Fq(0), Fq(0)) + tuple(rho_Z)
    pa_com, pa_state = pp.pa.prover_commit(_pa_statement(C_Q, C_H, C_Z), pa_values, pa_rands, rng)

    bits, c_pa = _smpa_challenges(pp, ts, C_Z, sm_com, pa_com)
    sm_resp = [pp.sm.prover_response(st, b) for st, b in zip(sm_state, bits)]
    pa_resp = pp.pa.prover_response(pa_state, c_pa)

    return Proof(K, transfer_com, transfer_resp, C_Z, sm_com, pa_com, sm_resp, pa_resp)


def verify(pp, C_cred, msg, proof, ctx=b""):
    try:
        return _verify(pp, C_cred, msg, proof, ctx)
    except (ValueError, ZeroDivisionError, ArithmeticError):
        return False


def _verify(pp, C_cred, msg, pf, ctx):
    Fq = Tom256.Fs
    if len(C_cred) != NUM_LIMBS or len(pf.sm_com) != pp.lam or len(pf.sm_resp) != pp.lam:
        return False
    K = pf.K
    if K.is_zero():
        return False
    alpha, Hpt = ecdsa.hpt(K, msg)  # raises if F(K) = 0
    if Hpt.is_zero():
        return False

    ts = _init_transcript(pp, C_cred, msg, ctx, K)

    c = _transfer_challenge(pp, ts, pf.transfer_com)
    if not pp.transfer.verifier(C_cred, pf.transfer_com, c, pf.transfer_resp):
        return False
    C_Q = pp.transfer.fold(pf.transfer_com[0])

    C_H = commit_point(pp.tom, Hpt, (Fq(0), Fq(0)))

    bits, c_pa = _smpa_challenges(pp, ts, pf.C_Z, pf.sm_com, pf.pa_com)
    for com, b, resp in zip(pf.sm_com, bits, pf.sm_resp):
        if not pp.sm.verifier(K, pf.C_Z, com, b, resp):
            return False
    return pp.pa.verifier(_pa_statement(C_Q, C_H, pf.C_Z), pf.pa_com, c_pa, pf.pa_resp)
