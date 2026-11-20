#!/usr/bin/sage
# vim: syntax=python
#
# ECDSA over P-256 with SHA-256, plus the (K, z) rewriting of ZKAttest used by
# the PoP:
#   r = F(K), z = r^{-1} * s mod n_p, and z*K = H(msg)*r^{-1}*P + Q.

import hashlib

try:
    from sagelib.groups import P256, smul, os2ip
except ImportError as e:
    import sys
    sys.exit("Error loading preprocessed sage files. Try running `make setup && make clean pyfiles`. Full error: " + str(e))

G = P256
n = P256.order
Fn = P256.Fs


def H(msg):
    """SHA-256 of msg reduced mod n_p (as in ECDSA)."""
    return Fn(os2ip(hashlib.sha256(msg).digest()))


def F(R):
    """ECDSA conversion function: x-coordinate of R reduced mod n_p."""
    return Fn(Integer(R.xy()[0]))


def keygen(rng):
    x = G.random_nonzero_scalar(rng)
    return x, smul(x, G.generator)


def sign(x, msg, rng):
    """Plain randomized ECDSA (a secure element would do this)."""
    h = H(msg)
    while True:
        k = G.random_nonzero_scalar(rng)
        r = F(smul(k, G.generator))
        if r == 0:
            continue
        s = (h + r * x) / k
        if s == 0:
            continue
        return (r, s)


def verify(Q, msg, sig):
    r, s = sig
    if r == 0 or s == 0:
        return False
    R = smul(H(msg) / s, G.generator) + smul(r / s, Q)
    return (not R.is_zero()) and F(R) == r


def to_kz(Q, msg, sig):
    """Rewrite a valid signature (r, s) under Q as (K, z) with r = F(K),
    z = s / r. The holder knows Q, so K is recovered deterministically as the
    ECDSA verification point R = (H(msg)/s)*P + (r/s)*Q."""
    if not verify(Q, msg, sig):
        raise ValueError("invalid ECDSA signature")
    r, s = sig
    K = smul(H(msg) / s, G.generator) + smul(r / s, Q)
    z = s / r
    return K, z


def hpt(K, msg):
    """alpha = H(msg) * F(K)^{-1} mod n_p and Hpt = alpha * P."""
    r = F(K)
    if r == 0:
        raise ValueError("F(K) = 0")
    alpha = H(msg) / r
    return alpha, smul(alpha, G.generator)
