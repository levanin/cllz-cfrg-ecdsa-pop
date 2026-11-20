#!/usr/bin/sage
# vim: syntax=python
#
# A minimal model of the interfaces of
# draft-irtf-cfrg-sigma-protocols: a batch of equations
#
#     elements[lhs_j] == sum_k scalars[s_jk] * elements[e_jk]
#
# proved with a Schnorr-type Sigma protocol (commit / challenge / response).

class LinearRelation(object):
    def __init__(self, group):
        self.group = group
        self.num_scalars = 0
        self.elements = []
        self.equations = []  # (lhs_index, [(scalar_index, element_index), ...])

    def allocate_scalars(self, n):
        idx = list(range(self.num_scalars, self.num_scalars + n))
        self.num_scalars += n
        return idx

    def allocate_elements(self, n):
        idx = list(range(len(self.elements), len(self.elements) + n))
        self.elements.extend([None] * n)
        return idx

    def set_elements(self, pairs):
        for i, P in pairs:
            self.elements[i] = P

    def append_equation(self, lhs, rhs):
        self.equations.append((lhs, list(rhs)))

    def image(self):
        return [self.elements[lhs] for lhs, _ in self.equations]

    def linear_map(self, scalars):
        assert len(scalars) == self.num_scalars
        out = []
        for _, rhs in self.equations:
            acc = self.group.identity()
            for s, e in rhs:
                acc += Integer(scalars[s]) * self.elements[e]
            out.append(acc)
        return out

    def is_satisfied(self, witness):
        return self.linear_map(witness) == self.image()


class SchnorrProof(object):
    """Sigma protocol for a LinearRelation. Challenges are scalars of
    relation.group.Fs; callers may restrict them (e.g. to {0, 1})."""

    def __init__(self, relation):
        self.relation = relation
        self.Fs = relation.group.Fs

    def prover_commit(self, witness, rng):
        nonces = [self.relation.group.random_scalar(rng) for _ in range(self.relation.num_scalars)]
        commitment = self.relation.linear_map(nonces)
        return commitment, (nonces, [self.Fs(w) for w in witness])

    def prover_response(self, prover_state, challenge):
        nonces, witness = prover_state
        c = self.Fs(challenge)
        return [k + c * w for k, w in zip(nonces, witness)]

    def verifier(self, commitment, challenge, response):
        if len(commitment) != len(self.relation.equations):
            return False
        if len(response) != self.relation.num_scalars:
            return False
        c = Integer(self.Fs(challenge))
        lhs = self.relation.linear_map(response)
        rhs = [A + c * X for A, X in zip(commitment, self.relation.image())]
        return lhs == rhs

    def simulate_commitment(self, response, challenge):
        c = Integer(self.Fs(challenge))
        return [T - c * X for T, X in zip(self.relation.linear_map(response), self.relation.image())]
