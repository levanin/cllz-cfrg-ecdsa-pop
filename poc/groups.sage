#!/usr/bin/sage
# vim: syntax=python
#
# Prime-order elliptic-curve groups used by the ECDSA PoP, including the tom curve:
#
#   - P-256 (secp256r1): the ECDSA curve. Base field F_q, scalar field F_np.
#   - Tom-256: the "Tom" curve of ZKAttest, whose scalar field is F_q,
#              so P-256 coordinate arithmetic is native.
#   - BLS12-381 G1: the credential curve (BBS), scalar field F_s.

import hashlib


def i2osp(x, n):
    return int(x).to_bytes(int(n), "big")


def os2ip(b):
    return Integer(int.from_bytes(b, "big"))


class DeserializeError(ValueError):
    pass


class Group(object):
    """A prime-order (sub)group of a short-Weierstrass curve y^2 = x^3 + a*x + b."""

    def __init__(self, name, p, a, b, order, gen, cofactor=1, encoding="sec1"):
        self.name = name
        self.p = Integer(p)
        self.F = GF(self.p)
        self.a = self.F(a)
        self.b = self.F(b)
        self.E = EllipticCurve(self.F, [self.a, self.b])
        self.order = Integer(order)
        self.Fs = GF(self.order)  # scalar field
        self.cofactor = Integer(cofactor)
        self.generator = self.E(gen)
        self.field_len = (self.p.nbits() + 7) // 8
        self.scalar_len = (self.order.nbits() + 7) // 8
        self.encoding = encoding
        assert self.order.is_prime()
        assert (self.order * self.generator).is_zero()

    def __repr__(self):
        return self.name

    def identity(self):
        return self.E(0)

    def element_len(self):
        return self.field_len + (1 if self.encoding == "sec1" else 0)

    def serialize(self, P):
        """Compressed encoding. SEC1 (0x02/0x03 || x) for P-256 / Tom-256,
        ZCash-style 48-byte compressed for BLS12-381 G1. The identity is
        never sent by this protocol and is rejected.
        This is kinda of an ad-hoc choice atm.
        """
        if P.is_zero():
            raise ValueError("Refusing to serialize the identity")
        x, y = P.xy()
        if self.encoding == "sec1":
            return bytes([2 + int(y) % 2]) + i2osp(x, self.field_len)
        # zcash: 0x80 = compressed, 0x20 = y is lexicographically largest
        out = bytearray(i2osp(x, self.field_len))
        out[0] |= 0x80
        if int(y) > (self.p - 1) // 2:
            out[0] |= 0x20
        return bytes(out)

    def deserialize(self, data):
        if len(data) != self.element_len():
            raise DeserializeError("bad element length")
        if self.encoding == "sec1":
            if data[0] not in (2, 3):
                raise DeserializeError("bad SEC1 prefix")
            sign = data[0] - 2
            xi = os2ip(data[1:])
        else:
            flags = data[0] & 0xE0
            if flags & 0x80 == 0 or flags & 0x40 != 0:
                raise DeserializeError("bad zcash flags")
            sign = 1 if flags & 0x20 else 0
            xi = os2ip(bytes([data[0] & 0x1F]) + data[1:])
        if xi >= self.p:
            raise DeserializeError("x not reduced")
        x = self.F(xi)
        rhs = x**3 + self.a * x + self.b
        if not rhs.is_square():
            raise DeserializeError("not on curve")
        y = rhs.sqrt()
        if self.encoding == "sec1":
            if int(y) % 2 != sign:
                y = -y
        else:
            if (1 if int(y) > (self.p - 1) // 2 else 0) != sign:
                y = -y
        P = self.E(x, y)
        if self.cofactor != 1 and not (self.order * P).is_zero():
            raise DeserializeError("not in prime-order subgroup")
        return P

    def serialize_scalar(self, s):
        return i2osp(int(s), self.scalar_len)

    def deserialize_scalar(self, data):
        if len(data) != self.scalar_len:
            raise DeserializeError("bad scalar length")
        v = os2ip(data)
        if v >= self.order:
            raise DeserializeError("scalar not reduced")
        return self.Fs(v)

    def random_scalar(self, rng):
        return self.Fs(rng.randbelow(self.order))

    def random_nonzero_scalar(self, rng):
        while True:
            s = self.random_scalar(rng)
            if s != 0:
                return s

    def hash_to_group(self, msg, dst):
        """Nothing-up-my-sleeve generator derivation by try-and-increment over
        SHAKE256."""
        ctr = 0
        while True:
            h = hashlib.shake_256(
                i2osp(len(dst), 1) + dst + i2osp(ctr, 4) + msg
            ).digest(int(self.field_len + 17))
            x = self.F(os2ip(h[:-1]))
            rhs = x**3 + self.a * x + self.b
            if rhs.is_square():
                y = rhs.sqrt()
                if int(y) % 2 != h[-1] % 2:
                    y = -y
                P = self.cofactor * self.E(x, y)
                if not P.is_zero():
                    return P
            ctr += 1


def smul(k, P):
    """Scalar multiplication by a scalar given as an int / Integer / field element."""
    return Integer(k) * P


_P256_P = 2**256 - 2**224 + 2**192 + 2**96 - 1

P256 = Group(
    "P-256",
    p=_P256_P,
    a=-3,
    b=0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B,
    order=0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551,
    gen=(
        0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296,
        0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5,
    ),
)

# Tom-256 (ZKAttest): prime order equal to the P-256 base-field prime q.
_TOM_P = 0xFFFFFFFF0000000100000000000000017E72B42B30E7317793135661B1C4B117
Tom256 = Group(
    "Tom-256",
    p=_TOM_P,
    a=_TOM_P - 3,
    b=0xB441071B12F4A0366FB552F8E21ED4AC36B06ACEEB354224863E60F20219FC56,
    order=_P256_P,
    gen=(
        3,
        0x5A6DD32DF58708E64E97345CBE66600DECD9D538A351BB3C30B4954925B1F02D,
    ),
)

BLS12_381_G1 = Group(
    "BLS12-381-G1",
    p=0x1A0111EA397FE69A4B1BA7B6434BACD764774B84F38512BF6730D2A0F6B0F6241EABFFFEB153FFFFB9FEFFFFFFFFAAAB,
    a=0,
    b=4,
    order=0x73EDA753299D7D483339D80809A1D80553BDA402FFFE5BFEFFFFFFFF00000001,
    gen=(
        0x17F1D3A73197D7942695638C4FA9AC0FC3688C4F9774B905A14E3A3F171BAC586C55E83FF97A1AEFFB3AF00ADB22C6BB,
        0x08B3F481E3AAA0F1A09E30ED741D8AE4FCF5E095D5D00AF600DB18CB2C04B3EDD03CC744A2888AE40CAA232946C5E7E1,
    ),
    cofactor=0x396C8C005555E1568C00AAAB0000AAAB,
    encoding="zcash",
)

# The 2-chain property that makes the whole construction work.
# This just asserts but it does help
assert Tom256.order == P256.p


class Pedersen(object):
    """Commit(m; rho) = m*g + rho*h over `group`."""

    def __init__(self, group, g, h):
        self.group = group
        self.g = g
        self.h = h

    @classmethod
    def derive(cls, group, dst):
        g = group.hash_to_group(b"g", dst)
        h = group.hash_to_group(b"h", dst)
        assert g != h
        return cls(group, g, h)

    def commit(self, m, rho):
        return smul(m, self.g) + smul(rho, self.h)

    def random(self, rng):
        return self.group.random_scalar(rng)


def point_coords(Pt, F):
    """Affine coordinates of a P-256 point as elements of F (= F_q, the Tom scalar field)."""
    x, y = Pt.xy()
    return (F(int(x)), F(int(y)))


def commit_point(tom, Pt, rho):
    """Commit~(Pt; (rho_x, rho_y)): a pair of Tom Pedersen commitments, one per
    affine coordinate of the P-256 point Pt."""
    x, y = point_coords(Pt, tom.group.Fs)
    return (tom.commit(x, rho[0]), tom.commit(y, rho[1]))


def random_point_randomness(tom, rng):
    return (tom.random(rng), tom.random(rng))
