#!/usr/bin/sage
# vim: syntax=python

import os
import sys
import time

try:
    from sagelib.groups import P256, Tom256, BLS12_381_G1, smul, point_coords, commit_point, random_point_randomness
    from sagelib.rng import SecureRNG, SeededRNG
    from sagelib.linear_relation import LinearRelation, SchnorrProof
    from sagelib.point_addition import PointAddition
    from sagelib.scalar_mult import ScalarMultiplication
    from sagelib.transfer import CommitmentTransfer
    from sagelib import ecdsa
    from sagelib.pop import (PublicParams, encode_public_key, credential_commit, prove, verify,
                             serialize_proof, deserialize_proof)
except ImportError as e:
    sys.exit("Error loading preprocessed sage files. Try running `make setup && make clean pyfiles`. Full error: " + str(e))

LAM = int(os.environ.get("POP_LAMBDA", 128))
rng = SeededRNG(0xEC05A)
pp = PublicParams(lam=LAM)
Fq = Tom256.Fs

_results = []


def test(fn):
    name = fn.__name__
    t0 = time.time()
    try:
        fn()
        ok = True
        err = ""
    except AssertionError as e:
        ok = False
        err = str(e)
    _results.append(ok)
    print("%s %-45s %6.2fs %s" % ("PASS" if ok else "FAIL", name, time.time() - t0, err))
    return fn


def random_point(G=P256):
    return smul(G.random_nonzero_scalar(rng), G.generator)


def commit_pt(Pt):
    rho = random_point_randomness(pp.tom, rng)
    return commit_point(pp.tom, Pt, rho), rho


@test
def test_groups_and_generators():
    assert Tom256.order == P256.p, "2-chain property"
    for G in (P256, Tom256, BLS12_381_G1):
        P = random_point(G)
        assert G.deserialize(G.serialize(P)) == P, "round-trip %s" % G
        assert G.deserialize(G.serialize(-P)) == -P, "round-trip neg %s" % G
    gens = [pp.tom.g, pp.tom.h]
    assert gens[0] != gens[1] and not any(g.is_zero() for g in gens)
    assert (BLS12_381_G1.order * pp.cred.g).is_zero() and (BLS12_381_G1.order * pp.cred.h).is_zero()


@test
def test_ecdsa_and_kz_rewrite():
    x, Q = ecdsa.keygen(rng)
    msg = b"hello"
    sig = ecdsa.sign(x, msg, rng)
    assert ecdsa.verify(Q, msg, sig)
    assert not ecdsa.verify(Q, b"other", sig)
    K, z = ecdsa.to_kz(Q, msg, sig)
    assert ecdsa.F(K) == sig[0]
    alpha, Hpt = ecdsa.hpt(K, msg)
    assert smul(z, K) == Hpt + Q, "Eq. POP"


@test
def test_linear_relation_dlog():
    rel = LinearRelation(Tom256)
    [w] = rel.allocate_scalars(1)
    iG, iX = rel.allocate_elements(2)
    x = Tom256.random_scalar(rng)
    rel.set_elements([(iG, Tom256.generator), (iX, smul(x, Tom256.generator))])
    rel.append_equation(iX, [(w, iG)])
    proto = SchnorrProof(rel)
    A, st = proto.prover_commit([x], rng)
    c = Tom256.random_scalar(rng)
    resp = proto.prover_response(st, c)
    assert proto.verifier(A, c, resp)
    assert proto.simulate_commitment(resp, c) == A
    assert not proto.verifier(A, c + 1, resp)


def _pa_instance(P1, P2, P3):
    C, vals, rands = [], [], []
    for Pt in (P1, P2, P3):
        Ci, rho = commit_pt(Pt)
        C += list(Ci)
        vals += list(point_coords(Pt, Fq))
        rands += list(rho)
    return C, vals, rands


@test
def test_point_addition():
    for open_ay in (True, False):
        pa = PointAddition(pp.tom, open_ay=open_ay)
        P1, P2 = random_point(), random_point()
        C, vals, rands = _pa_instance(P1, P2, P1 + P2)
        com, st = pa.prover_commit(C, vals, rands, rng)
        c = Fq.random_element()
        resp = pa.prover_response(st, c)
        assert pa.verifier(C, com, c, resp), "honest PA (open_ay=%s)" % open_ay
        assert not pa.verifier(C, com, c + 1, resp)
        # bit challenges, as used inside SM
        for b in (0, 1):
            com, st = pa.prover_commit(C, vals, rands, rng)
            assert pa.verifier(C, com, b, pa.prover_response(st, b))


@test
def test_point_addition_rejects_wrong_sum():
    pa = PointAddition(pp.tom)
    P1, P2 = random_point(), random_point()
    C, vals, rands = _pa_instance(P1, P2, P1 + P2 + P256.generator)
    com, st = pa.prover_commit(C, vals, rands, rng)
    c = Fq.random_element()
    assert not pa.verifier(C, com, c, pa.prover_response(st, c))


@test
def test_point_addition_degenerate():
    pa = PointAddition(pp.tom)
    P1 = random_point()
    for P2 in (P1, -P1):
        C, vals, rands = _pa_instance(P1, P2, P1 + P1)  # P3 irrelevant
        try:
            pa.prover_commit(C, vals, rands, rng)
            assert False, "PA prover accepted P_1 = +-P_2"
        except ValueError:
            pass


@test
def test_scalar_mult():
    sm = ScalarMultiplication(pp.tom)
    K = random_point()
    z = P256.random_nonzero_scalar(rng)
    Z = smul(z, K)
    C_Z, rho_Z = commit_pt(Z)
    for b in (0, 1, 0, 1):
        com, st = sm.prover_commit(K, C_Z, Z, z, rho_Z, rng)
        resp = sm.prover_response(st, b)
        assert sm.verifier(K, C_Z, com, b, resp), "honest SM b=%d" % b
        assert not sm.verifier(K, C_Z, com, 1 - b, resp), "wrong bit"


@test
def test_scalar_mult_rejects_wrong_z():
    # Prover commits to Z = z*K but uses z' != z: for each execution one of the two bits fails.
    sm = ScalarMultiplication(pp.tom)
    K = random_point()
    z = P256.random_nonzero_scalar(rng)
    Z = smul(z, K)
    C_Z, rho_Z = commit_pt(Z)
    bad = z + 1
    fails = 0
    for b in (0, 1):
        com, st = sm.prover_commit(K, C_Z, Z, bad, rho_Z, rng)
        if not sm.verifier(K, C_Z, com, b, sm.prover_response(st, b)):
            fails += 1
    assert fails >= 1


@test
def test_transfer():
    tr = pp.transfer
    _, Q = ecdsa.keygen(rng)
    C, rho = credential_commit(pp, Q, rng)
    limbs = encode_public_key(Q)
    while True:
        com, st = tr.prover_commit(limbs, rho, rng)
        c = rng.randbelow(2**tr.b_c)
        resp = tr.prover_response(st, c)
        if resp is not None:
            break
    assert tr.verifier(C, com, c, resp)
    # folded Tom commitments open to (x, y)
    C_Q = tr.fold(com[0])
    rho_Q = tr.fold_randomness(st)
    assert tuple(C_Q) == commit_point(pp.tom, Q, rho_Q)
    # a credential commitment to a different key is rejected
    _, Q2 = ecdsa.keygen(rng)
    C2, _ = credential_commit(pp, Q2, rng)
    assert not tr.verifier(C2, com, c, resp)


@test
def test_transfer_rejection_rate():
    tr = pp.transfer
    aborts, N = 0, 400
    m, rho = [2**128 - 1], [pp.cred.random(rng)]
    for _ in range(N):
        _, st = tr.prover_commit(m, rho, rng)
        if tr.prover_response(st, 2**tr.b_c - 1) is None:
            aborts += 1
    # expected abort probability ~ 2^-b_f + 2^-b_f = 1/128
    assert aborts < N // 16, "too many aborts: %d/%d" % (aborts, N)


# Full PoP

_x, _Q = ecdsa.keygen(rng)
_C_cred, _rho_cred = credential_commit(pp, _Q, rng)
_ctx = b"JWP-BBS-DB-CHAL" + b"presentation-header:nonce=1234,aud=rp.example"
_msg = _ctx  # db_msg is what the secure element signs
_sig = ecdsa.sign(_x, _msg, rng)
_proof = {}


@test
def test_pop_prove_verify():
    t0 = time.time()
    pf = prove(pp, _Q, _msg, _sig, _C_cred, _rho_cred, rng, ctx=_ctx)
    t1 = time.time()
    ok = verify(pp, _C_cred, _msg, pf, ctx=_ctx)
    t2 = time.time()
    assert ok, "Honest PoP rejected"
    _proof["pf"] = pf
    print("     lambda=%d  prove %.2fs  verify %.2fs" % (LAM, t1 - t0, t2 - t1))


@test
def test_pop_serialization():
    pf = _proof["pf"]
    data = serialize_proof(pp, pf)
    print("     proof size: %d bytes (%.1f KiB)" % (len(data), len(data) / 1024.0))
    pf2 = deserialize_proof(pp, data)
    assert serialize_proof(pp, pf2) == data
    assert verify(pp, _C_cred, _msg, pf2, ctx=_ctx)
    try:
        deserialize_proof(pp, data + b"\x00")
        assert False, "accepted trailing bytes"
    except ValueError:
        pass


@test
def test_pop_rejects_wrong_message():
    assert not verify(pp, _C_cred, _msg + b"x", _proof["pf"], ctx=_ctx)


@test
def test_pop_rejects_wrong_context():
    assert not verify(pp, _C_cred, _msg, _proof["pf"], ctx=_ctx + b"x")


@test
def test_pop_rejects_other_credential():
    _, Q2 = ecdsa.keygen(rng)
    C2, _ = credential_commit(pp, Q2, rng)
    assert not verify(pp, C2, _msg, _proof["pf"], ctx=_ctx)


@test
def test_pop_rejects_rerandomized_credential():
    # same key, different credential commitment: transfer must fail
    C2, _ = credential_commit(pp, _Q, rng)
    assert not verify(pp, C2, _msg, _proof["pf"], ctx=_ctx)


@test
def test_pop_rejects_wrong_key_signature():
    # holder signs with a key that is not the committed one
    x2, Q2 = ecdsa.keygen(rng)
    sig2 = ecdsa.sign(x2, _msg, rng)
    try:
        pf = prove(pp, _Q, _msg, sig2, _C_cred, _rho_cred, rng, ctx=_ctx)
        assert False, "prover accepted signature under the wrong key"
    except ValueError:
        pass
    pf = prove(pp, Q2, _msg, sig2, _C_cred, _rho_cred, rng, ctx=_ctx)
    assert not verify(pp, _C_cred, _msg, pf, ctx=_ctx)


@test
def test_pop_rejects_bit_flips():
    data = bytearray(serialize_proof(pp, _proof["pf"]))
    for pos in (5, 200, len(data) // 2, len(data) - 3):
        bad = bytearray(data)
        bad[pos] ^^= 0x01
        try:
            pf = deserialize_proof(pp, bytes(bad))
        except ValueError:
            continue
        assert not verify(pp, _C_cred, _msg, pf, ctx=_ctx), "accepted flip at %d" % pos


print()
print("%d/%d tests passed" % (sum(_results), len(_results)))
sys.exit(int(0) if all(_results) else int(1))
