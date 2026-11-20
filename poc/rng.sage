#!/usr/bin/sage
# vim: syntax=python

import random
import secrets


class SecureRNG(object):
    """Cryptographically secure randomness (default)."""

    def randbelow(self, n):
        return Integer(secrets.randbelow(int(n)))


class SeededRNG(object):
    """Deterministic randomness for reproducible tests. INSECURE: test use only."""

    def __init__(self, seed):
        self._r = random.Random(int(seed))

    def randbelow(self, n):
        return Integer(self._r.randrange(int(n)))
