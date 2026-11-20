#!/usr/bin/sage
# vim: syntax=python
#
# Fiat-Shamir transcript.
#
# Uses a simple
# SHAKE128-based transcript with length-prefixed, labelled absorb/squeeze
# operations.

import hashlib

try:
    from sagelib.groups import i2osp, os2ip
except ImportError as e:
    import sys
    sys.exit("Error loading preprocessed sage files. Try running `make setup && make clean pyfiles`. Full error: " + str(e))


def _lp(data):
    return i2osp(len(data), 8) + data


class Transcript(object):
    def __init__(self, domain_sep):
        self._h = hashlib.shake_128()
        self._h.update(b"ECDSA-PoP/transcript/v0")
        self.absorb(b"domain-sep", domain_sep)

    def copy(self):
        t = Transcript.__new__(Transcript)
        t._h = self._h.copy()
        return t

    def absorb(self, label, data):
        self._h.update(b"A" + _lp(label) + _lp(data))

    def absorb_elements(self, label, group, points):
        self.absorb(label, b"".join(group.serialize(P) for P in points))

    def absorb_scalars(self, label, group, scalars):
        self.absorb(label, b"".join(group.serialize_scalar(s) for s in scalars))

    def squeeze(self, label, n):
        self._h.update(b"S" + _lp(label) + i2osp(n, 8))
        return self._h.copy().digest(int(n))


def bytes_to_bits(data, nbits):
    """Little-endian bit decomposition of the first nbits bits of data."""
    return [(data[i // 8] >> (i % 8)) & 1 for i in range(nbits)]


def bytes_to_scalar(data, order):
    """Reduce a (scalar_len + 16)-byte string mod `order` (statistically uniform)."""
    return os2ip(data) % order
