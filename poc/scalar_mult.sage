#!/usr/bin/sage
# vim: syntax=python
#
# Scalar-Multiplication proof SM (Section "Scalar-Multiplication Proof").
#
#   R_SM = { ((C_Z, K) ; Z, rho_Z, z) : C_Z = Commit~(Z; rho_Z) AND Z = z*K }

try:
    from sagelib.groups import P256, smul, point_coords, commit_point, random_point_randomness
    from sagelib.point_addition import PointAddition
except ImportError as e:
    import sys
    sys.exit("Error loading preprocessed sage files. Try running `make setup && make clean pyfiles`. Full error: " + str(e))


class ScalarMultiplication(object):
    def __init__(self, tom):
        self.tom = tom
        self.Fq = tom.group.Fs
        self.Fn = P256.Fs
        self.pa = PointAddition(tom, open_ay=False)

    @staticmethod
    def pa_commitments(C_Z, C1, C2):
        # statement_PA = (C_Z, C'', C'):  P_1 = Z, P_2 = Z'', P_3 = Z'
        return [C_Z[0], C_Z[1], C2[0], C2[1], C1[0], C1[1]]

    def prover_commit(self, K, C_Z, Z, z, rho_Z, rng):
        z = self.Fn(z)
        while True:
            omega = P256.random_scalar(rng)
            if omega not in (0, z, 2 * z):
                break
        Z1 = smul(omega, K)          # Z'  = omega * K
        Z2 = smul(omega - z, K)      # Z'' = (omega - z) * K
        rho1 = random_point_randomness(self.tom, rng)
        rho2 = random_point_randomness(self.tom, rng)
        C1 = commit_point(self.tom, Z1, rho1)
        C2 = commit_point(self.tom, Z2, rho2)

        values = point_coords(Z, self.Fq) + point_coords(Z2, self.Fq) + point_coords(Z1, self.Fq)
        rands = tuple(rho_Z) + tuple(rho2) + tuple(rho1)
        pa_com, pa_state = self.pa.prover_commit(self.pa_commitments(C_Z, C1, C2), values, rands, rng)
        return (C1, C2, pa_com), (omega, z, rho1, rho2, pa_state)

    def prover_response(self, prover_state, b):
        omega, z, rho1, rho2, pa_state = prover_state
        assert b in (0, 1)
        msg2 = self.pa.prover_response(pa_state, b)
        if b == 0:
            alpha, tau = omega, rho1
        else:
            alpha, tau = omega - z, rho2
        return (alpha, tau, msg2)

    def verifier(self, K, C_Z, commitment, b, response):
        C1, C2, pa_com = commitment
        alpha, tau, msg2 = response
        if b not in (0, 1) or alpha == 0:
            return False
        # (1) PA on (C_Z, C'', C') accepts (msg_1, b, msg_2)
        if not self.pa.verifier(self.pa_commitments(C_Z, C1, C2), pa_com, b, msg2):
            return False
        # (2) open C' (b = 0) or C'' (b = 1) to alpha*K
        expected = commit_point(self.tom, smul(alpha, K), tau)
        return expected == (C1 if b == 0 else C2)
