#!/usr/bin/sage
# vim: syntax=python
#
# Commitment transfer: move Pedersen commitments to small limbs m_i from the credential
# curve (BLS12-381 G1) to
# Tom-256, proving equality of openings with OKMZ.

try:
    from sagelib.groups import smul
except ImportError as e:
    import sys
    sys.exit("Error loading preprocessed sage files. Try running `make setup && make clean pyfiles`. Full error: " + str(e))

B_M, B_C, B_F = 128, 112, 8


class CommitmentTransfer(object):
    def __init__(self, cred, tom, b_m=B_M, b_c=B_C, b_f=B_F):
        self.cred = cred  # Pedersen over the credential curve: (g, h)
        self.tom = tom    # Pedersen over Tom-256: (G_t, H_t)
        self.b_m, self.b_c, self.b_f = b_m, b_c, b_f
        bound = min(cred.group.order, tom.group.order)
        # b_m + b_c + b_f < log2(min(|F_s|, |F_q|))
        assert 2**(b_m + b_c + b_f) + 2**(b_m + b_c) < bound
        self.z_lo = 2**(b_m + b_c)
        self.z_hi = 2**(b_m + b_c + b_f)
        self.z_len = (b_m + b_c + b_f + 7) // 8

    def in_range(self, z):
        return self.z_lo <= z < self.z_hi

    def prover_commit(self, m, rho, rng):
        """m: limbs (0 <= m_i < 2^b_m), rho: their credential-curve randomness."""
        Ct, A, At, state = [], [], [], []
        for m_i, rho_i in zip(m, rho):
            assert 0 <= m_i < 2**self.b_m
            rt_i = self.tom.random(rng)
            Ct.append(self.tom.commit(m_i, rt_i))                  # 1. new Tom commitment
            k_i = rng.randbelow(self.z_hi)                         # 2. bounded mask
            t_i = self.cred.random(rng)
            tt_i = self.tom.random(rng)
            A.append(smul(k_i, self.cred.g) + smul(t_i, self.cred.h))
            At.append(smul(k_i, self.tom.g) + smul(tt_i, self.tom.h))
            state.append((Integer(m_i), self.cred.group.Fs(rho_i), rt_i, k_i, t_i, tt_i))
        return (Ct, A, At), state

    def prover_response(self, state, c):
        """Returns (z, s, s~) or None on abort (caller restarts with fresh randomness)."""
        assert 0 <= c < 2**self.b_c
        z, s, st = [], [], []
        for m_i, rho_i, rt_i, k_i, t_i, tt_i in state:
            z_i = k_i + c * m_i                                    # over the integers
            if not self.in_range(z_i):
                return None
            z.append(z_i)
            s.append(t_i + c * rho_i)                              # in F_s
            st.append(tt_i + c * rt_i)                             # in F_q
        return (z, s, st)

    def verifier(self, C, commitment, c, response):
        Ct, A, At = commitment
        z, s, st = response
        n = len(C)
        if not (len(Ct) == len(A) == len(At) == len(z) == len(s) == len(st) == n):
            return False
        if not 0 <= c < 2**self.b_c:
            return False
        for i in range(n):
            if not self.in_range(z[i]):                                            # (3)
                return False
            if smul(z[i], self.cred.g) + smul(s[i], self.cred.h) != A[i] + smul(c, C[i]):    # (1)
                return False
            if smul(z[i], self.tom.g) + smul(st[i], self.tom.h) != At[i] + smul(c, Ct[i]):   # (2)
                return False
        return True

    def fold(self, Ct):
        """[C~(x_0), C~(x_1), C~(y_0), C~(y_1)] -> (C_x, C_y)."""
        w = 2**self.b_m
        return (Ct[0] + smul(w, Ct[1]), Ct[2] + smul(w, Ct[3]))

    def fold_randomness(self, state):
        w = self.tom.group.Fs(2**self.b_m)
        rt = [st[2] for st in state]
        return (rt[0] + w * rt[1], rt[2] + w * rt[3])
