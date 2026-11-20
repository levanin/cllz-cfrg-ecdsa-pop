#!/usr/bin/sage
# vim: syntax=python
#
# Point-Addition proof PA.
#
#   R_PA = { ((C_1, C_2, C_3) ; P_1, P_2, P_3, openings) :
#              C_i = Commit~(P_i; rho_i)  AND  P_1 + P_2 = P_3 }
#
# with P_1 != +-P_2 and P_1, P_2 != identity. In the code the six coordinate
# commitments C[1..6] of the draft are the 0-indexed list C[0..5]:
#
#   C[0] -> a_x   C[1] -> a_y   (P_1)
#   C[2] -> b_x   C[3] -> b_y   (P_2)
#   C[4] -> t_x   C[5] -> t_y   (P_3)

try:
    from sagelib.linear_relation import LinearRelation, SchnorrProof
except ImportError as e:
    import sys
    sys.exit("Error loading preprocessed sage files. Try running `make setup && make clean pyfiles`. Full error: " + str(e))

PA_WITNESS = ["tau", "rtau", "inv_f1", "aux_f1", "e1", "e2", "f3", "rf3", "e3", "ay", "r2"]


def pa_relation(tom, C, C_tau, open_ay=True):
    """Build the PA LinearRelation over Tom-256 (draft: `Relation PA(H, C[1..6], C_tau)`)."""
    assert len(C) == 6
    rel = LinearRelation(tom.group)
    nw = 11 if open_ay else 9
    w = rel.allocate_scalars(nw)
    tau, rtau, inv_f1, aux_f1, e1, e2, f3, rf3, e3 = w[:9]

    iG, iH, iCtau, iD31, iD42, iS135, iD15, iS26, iC2 = rel.allocate_elements(9)
    rel.set_elements([
        (iG, tom.g),
        (iH, tom.h),
        (iCtau, C_tau),
        (iD31, C[2] - C[0]),           # C[3] - C[1]
        (iD42, C[3] - C[1]),           # C[4] - C[2]
        (iS135, C[0] + C[2] + C[4]),   # C[1] + C[3] + C[5]
        (iD15, C[0] - C[4]),           # C[1] - C[5]
        (iS26, C[1] + C[5]),           # C[2] + C[6]
        (iC2, C[1]),                   # C[2]
    ])

    rel.append_equation(iCtau, [(tau, iG), (rtau, iH)])        # slope commitment
    rel.append_equation(iG, [(inv_f1, iD31), (aux_f1, iH)])    # b_x - a_x != 0
    rel.append_equation(iD42, [(tau, iD31), (e1, iH)])         # (C1)
    rel.append_equation(iS135, [(tau, iCtau), (e2, iH)])       # (C2), squaring
    rel.append_equation(iD15, [(f3, iG), (rf3, iH)])           # factor of (C3)
    rel.append_equation(iS26, [(f3, iCtau), (e3, iH)])         # (C3)
    if open_ay:
        ay, r2 = w[9:]
        rel.append_equation(iC2, [(ay, iG), (r2, iH)])         # omitted inside SM
    return rel


class PointAddition(object):
    """PA as a Sigma protocol. The prover's first message is (C_tau, A), where
    C_tau completes the instance and A is the Schnorr announcement."""

    def __init__(self, tom, open_ay=True):
        self.tom = tom
        self.Fq = tom.group.Fs
        self.open_ay = open_ay

    def witness(self, values, rands, rtau):
        """values = (a_x, a_y, b_x, b_y, t_x, t_y), rands = (r_1, ..., r_6)."""
        ax, ay, bx, by, tx, ty = [self.Fq(v) for v in values]
        r1, r2, r3, r4, r5, r6 = [self.Fq(r) for r in rands]
        if bx == ax:
            raise ValueError("PA precondition violated: P_1 = +-P_2")
        tau = (by - ay) / (bx - ax)
        f3 = ax - tx
        wit = [
            tau,
            rtau,
            1 / (bx - ax),                        # inv_f1
            -(r3 - r1) / (bx - ax),               # aux_f1
            (r4 - r2) - (r3 - r1) * tau,          # e1
            (r1 + r3 + r5) - rtau * tau,          # e2
            f3,                                   # f3
            r1 - r5,                              # rf3
            (r2 + r6) - rtau * f3,                # e3
        ]
        if self.open_ay:
            wit += [ay, r2]
        return tau, wit

    def prover_commit(self, C, values, rands, rng):
        rtau = self.tom.random(rng)
        tau, wit = self.witness(values, rands, rtau)
        C_tau = self.tom.commit(tau, rtau)
        proto = SchnorrProof(pa_relation(self.tom, C, C_tau, self.open_ay))
        A, st = proto.prover_commit(wit, rng)
        return (C_tau, A), (proto, st)

    def prover_response(self, prover_state, challenge):
        proto, st = prover_state
        return proto.prover_response(st, challenge)

    def verifier(self, C, commitment, challenge, response):
        C_tau, A = commitment
        proto = SchnorrProof(pa_relation(self.tom, C, C_tau, self.open_ay))
        return proto.verifier(A, challenge, response)

    def num_equations(self):
        return 7 if self.open_ay else 6

    def num_scalars(self):
        return 11 if self.open_ay else 9
