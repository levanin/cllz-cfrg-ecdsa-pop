---
title: "Schnorr-Type Proofs of Possession for ECDSA Device Binding"
abbrev: "ECDSA-PoP"
category: info

docname: draft-cllz-cfrg-ecdsa-pop-latest
submissiontype: IRTF
number:
date:
v: 3
area: IRTF
workgroup: Crypto Forum Research Group
keyword: Internet-Draft
venue:
  group: Crypto Forum
  type: Research Group
  mail: cfrg@ietf.org
  arch: https://mailarchive.ietf.org/arch/browse/cfrg/
  github: levanin/cllz-cfrg-ecdsa-pop
  latest: https://levanin.github.io/cllz-cfrg-ecdsa-pop/draft-cllz-cfrg-ecdsa-pop.html

author:
 -
    fullname: Sofia Celi
    organization: Brave Software / University of Bristol
    email: cherenkov@riseup.net
 -
    fullname: Anja Lehmann
    organization: Hasso Plattner Institute
    email: anja.lehmann@hpi.de
 -
    fullname: Shai Levin
    organization: Chalmers University of Technology / University of Gothenburg
    email: shai.levin@chalmers.se
 -
    fullname: Alexandros Zacharakis
    organization: Hasso Plattner Institute
    email: alexandros.zacharakis@hpi.de

normative:
  SIGMA: I-D.irtf-cfrg-sigma-protocols
  FIAT-SHAMIR: I-D.irtf-cfrg-fiat-shamir
  MODULAR-BBS:
    title: "BBS and Modular Sub-proofs with JSON Web Proofs"
    target: https://c2bo.github.io/draft-bormann-jwp-modular-bbs/draft-bormann-jwp-modular-bbs.html
    author:
      - name: Christian Bormann
      - name: Brent Zundel
    date: 2025
    seriesinfo:
      Internet-Draft: draft-bormann-jwp-modular-bbs
  SEC1:
    title: "SEC 1: Elliptic Curve Cryptography, Version 2.0"
    target: https://www.secg.org/sec1-v2.pdf
    author:
      - org: Standards for Efficient Cryptography Group
    date: 2009
  FIPS186-5:
    title: "Digital Signature Standard (DSS)"
    target: https://doi.org/10.6028/NIST.FIPS.186-5
    author:
      - org: National Institute of Standards and Technology
    seriesinfo:
      FIPS: PUB 186-5
    date: 2023

informative:
  PAPER:
    title: "Device Binding for Anonymous Credentials on Legacy Phones"
    author:
      - fullname: Sofia Celi
      - fullname: Anja Lehmann
      - fullname: Shai Levin
      - fullname: Alexandros Zacharakis
    date: 2025
  BBS: I-D.irtf-cfrg-bbs-signatures
  BLIND-BBS: I-D.irtf-cfrg-bbs-blind-signatures
  W3CBBS:
    title: "Data Integrity BBS Cryptosuites v1.0"
    target: https://www.w3.org/TR/vc-di-bbs/
    author:
      - org: World Wide Web Consortium (W3C)
    date: 2025
  RoK:
    title: "Algebraic Reductions of Knowledge"
    author:
      - fullname: Abhiram Kothapalli
      - fullname: Bryan Parno
    date: 2023
    seriesinfo:
      CRYPTO: 2023
  CDLS:
    title: "CDLS: Proving Knowledge of Committed Discrete Logarithms with Soundness"
    author:
      - name: Sofia Celi
      - name: Shai Levin
      - name: Joe Rowell
    date: 2024
    seriesinfo:
      AFRICACRYPT: 2024
  ZKATTEST:
    title: "ZKAttest: Ring and Group Signatures on top of existing ECDSA keys"
    author:
      - name: Armando Faz-Hernandez
      - name: Watson Ladd
      - name: Deepak Maram
    date: 2021
    seriesinfo:
      SAC: 2021
  OKMZ:
    title: "Beyond the Circuit: How to Minimize Foreign Arithmetic in ZKP Circuits"
    author:
      - name: Michele Orru
      - name: George Kadianakis
      - name: Mary Maller
      - name: Greg Zaverucha
    date: 2025
    seriesinfo:
      CiC: 2025
  LSZ:
    title: "Vision: A Modular Framework for Anonymous Credential Systems"
    target: https://doi.org/10.1007/978-3-032-19567-8_3
    author:
      - name: Anja Lehmann
      - name: Andrey Sidorenko
      - name: Alexandros Zacharakis
    date: 2026
    seriesinfo:
      SSR: 2025
  UBIQUE:
    title: "BBS+ Device Binding via ECDSA (EUDI Innovation Competition prototype)"
    author:
      - org: Ubique
    date: 2024
  EUDI-ARF:
    title: "EU Digital Identity Wallet -- Architecture and Reference Framework"
    target: https://eudi.dev/2.4.0/
    author:
      - org: European Commission
    date: 2026
  DEROSA:
    title: "Discussion comment on Cryptographers' Feedback on the EU Digital Identity's ARF #211"
    target: https://github.com/eu-digital-identity-wallet/eudi-doc-architecture-and-reference-framework/discussions/211/#discussioncomment-9882388
    author:
      - name: Paolo De Rosa
    date: 2024

--- abstract

This document specifies a Schnorr-type, circuit-free zero-knowledge proof of possession (PoP) of an ECDSA signature produced under a committed public key over the NIST P-256 (secp256r1) curve.
The PoP lets a credential holder prove, in zero knowledge, that it can produce a fresh ECDSA signature under a device public key without revealing that key, thereby providing device binding for privacy-preserving credentials whose presentation must remain unlinkable.

The construction is built exclusively from Sigma protocols as it decomposes the ECDSA verification equation into a scalar-multiplication relation and a point-addition relation over P-256, each proved with a dedicated Sigma protocol over a companion ("Tom") curve whose scalar field equals the base field of P-256.
It is designed to be expressed using the interfaces of the CFRG Sigma-protocols specification and to serve as the device-binding sub-proof of the modular BBS / JSON Web Proofs construction.
SNARK-based realizations of the same relation are out of scope.

--- middle

# Introduction

Anonymous credentials enable privacy-preserving authentication: a holder presents an issuer-attested credential to a relying party while revealing only the minimum necessary information and remaining unlinkable across presentations. BBS signatures are a leading basis for such credentials and are being adopted in several standardization efforts {{BBS}}{{BLIND-BBS}}{{W3CBBS}}. These efforts are of relevance to the European Union Digital Identity (EUDI) wallet {{EUDI-ARF}}, which is mandated to implement user authentication with strong privacy guarantees, including selective disclosure and unlinkability.

A central requirement for credentials used in digital-identity deployments is non-transferability: a credential must be usable only by its legitimate holder, and not be shared, or copied. The standard way to enforce this is device binding. The credential is tied to a key held in a secure element (SE) on the user's device, and at presentation time the holder produces a fresh signature -- a proof of possession (PoP) -- under the corresponding secret key, which never leaves the SE. Because the key is non-exportable, the credential cannot be used without the device that holds it.

The EUDI architecture mandates device binding to a secure element, but consumer-device secure elements are, in practice, restricted to ECDSA over P-256 and do not expose the pairing-friendly operations required by native anonymous-credential device binding. The lack of an efficient and robust device-binding mechanism for anonymous credentials on legacy hardware was a key reason such credentials were not used in the initial EUDI deployment, which instead relies on batch-issued one-time-use credentials {{DEROSA}}.

Here, we address the gap by specifying how to prove possession of an ECDSA signature under a committed device public key, so that ECDSA device binding can be composed with a pairing-based credential layer such as BBS. Our solution is based on Schnorr-type proofs, providing a robust, well-understood approach that avoids the implementation and interoperability challenges of circuit-based constructions.

## Scope

This document specifies only the *Schnorr-type* (Sigma-protocol-based) PoP.
This is the most conservative construction in {{PAPER}}: it uses no arithmetic circuits and no general-purpose proof system, relying solely on Sigma protocols and Pedersen commitments.
SNARK / circuit-based realizations of the same statement (the "foreign-field" and "native circuit" constructions of {{PAPER}}, and the Committed Schnorr reduction used by them) are explicitly out of scope.

The proof is interactive as described, and is made non-interactive with the Fiat-Shamir transform ({{fiat-shamir}}).
Sigma protocols are composed using the interfaces of {{SIGMA}}, and the non-interactive transform and its codec are taken from the companion specification {{FIAT-SHAMIR}}.

## Relationship to Other Specifications

This document is designed to compose with two CFRG / IETF efforts:

- {{SIGMA}} (Sigma protocols).
  The sub-protocols specified here are Sigma protocols and are described, where possible, using the `Group`, `LinearRelation`, and `SigmaProtocol` abstractions of {{SIGMA}}.
  In particular, the point-addition proof of {{point-addition}} is a batch of linear relations whose group bases include commitments drawn from the statement, and is therefore expressible through the `LinearRelation` interface; the scalar-multiplication proof of {{scalar-mult}} is a custom `SigmaProtocol` (a bit-challenge proof run with parallel repetition) that internally invokes the point-addition proof.

- {{MODULAR-BBS}} (modular BBS sub-proofs).
  The PoP specified here is intended to instantiate the `ecdsa-p256-db` device-binding sub-proof of {{MODULAR-BBS}}, which exposes the holder's P-256 public key as four committed BBS messages carrying its 128-bit limbs (at indices `[0, 1, 2, 3]`) and binds the sub-proof to a challenge derived from the presentation headers.
  {{integration}} describes this binding.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

The following terms are used throughout.

ECDSA curve (P-256):
: The curve secp256r1 / NIST P-256 {{FIPS186-5}}{{SEC1}}.
  `G_p` denotes its group of points (prime order `n_p`), `P` a fixed generator, `F_q` its base field, and `F_np` its scalar field.

Tom curve (Tom-256):
: A curve forming a "2-chain" with P-256: its scalar field equals the base field `F_q` of P-256 (see {{ZKATTEST}}).
  `G_t` denotes its group of points.
  Arithmetic over `F_q` -- i.e. arithmetic on P-256 coordinates -- is therefore *native* in the scalar field of `G_t`, which is what makes the Sigma-protocol proofs efficient.

Credential curve:
: The pairing-friendly curve used by the credential layer (e.g., BLS12-381 for BBS), with scalar field `F_s`.
  Commitments produced by the credential layer live over this curve.

Pedersen commitment:
: For a group `G` with independent generators `(g, h)` (and, for vectors, `(g_1,...,g_k, h)`), the commitment to message `m` with randomness `rho` is `Commit(m; rho) = m*g + rho*h` (resp. `sum_i m_i*g_i + rho*h`).
  Pedersen commitments used here are perfectly hiding and computationally binding under the discrete-log assumption in `G`.

Throughout, lowercase letters denote scalars and uppercase letters denote group elements.
`x*P` denotes scalar multiplication and `A + B` denotes group addition.
`H(.)` is a hash into `F_np` (SHA-256 reduced mod `n_p`, as in ECDSA), and `F: G_p -> F_np` is the ECDSA conversion function mapping a point to the integer reduction mod `n_p` of its x-coordinate.

# Overview

In this system there are three parties: a holder, who holds a credential and possesses an ECDSA-based device key pair; an issuer, who issues credentials; and a verifier, who verifies credentials and their binding to devices.
The holder has a device ECDSA key pair (`private_key = x`, `public_key = Q`), where `Q = x*P` over P-256. This public key is included in the holder's credential (e.g., as a committed BBS message).
The public key MAY be carried into the credential as a committed message via blind issuance ({{BLIND-BBS}}), that is, in hidden form, so that the issuer signs over `Q` without learning it. This case requires the additional functionality described in {{transfer}}.
When presenting a credential, the verifier supplies a fresh `nonce`. The holder uses the secure element to produce an ECDSA signature over `nonce` with the device key pair, then proves in zero knowledge that it knows a valid signature under the committed key `Q`, without revealing `Q`.

In order to instantiate this functionality, we rewrite how ECDSA signatures (which are of the form `(r, s)`) look like.
As shown in {{ZKATTEST}}, an ECDSA signature on a message `msg` can be rewritten as a pair `(K, z)` with `r = F(K)`, and `z = r^{-1} * s mod n_p`.
The verification then reduces to checking (where `P` is a fixed generator):

~~~
z*K = H(msg) * r^{-1} * P + Q
~~~

Because the signature is fresh and single-use, the value `K` MAY be revealed without harming unlinkability; only the long-lived device public key `Q` must stay hidden.
The purpose now is to prove that one knows a valid signature of the form above without revealing the underlying `Q` (this is the purpose of our PoP).
By setting:

~~~
alpha = H(nonce) * F(K)^{-1}  mod n_p          (a public scalar)
Hpt   = alpha * P                              (a public P-256 point)
~~~

the statement to be proved becomes: knowledge of a scalar `z` and an opening of the commitment to `Q` such that

~~~
z*K = Hpt + Q                                  (Eq. POP)
~~~

The computation is over P-256. `K`, `Hpt` are public; `z` and `Q` are secret.

The PoP for (Eq. POP) can be interpreted as three functionalities, each run between prover (holder) and verifier (relying party):

1. Commitment transfer ({{transfer}}).
   Transfer the commitment to `Q` from the credential curve to the Tom curve, where P-256 coordinate arithmetic is native.
   After this step `Q = (x, y)` is committed as two Tom Pedersen commitments `C_x = Commit(x; rho_x)` (to the `x` coordinate), `C_y = Commit(y; rho_y)` (to the `y` coordinate).

2. Reduction to curve operations ({{rok-group}}).
   Set `Z = z*K` and commit to it to generate `C_Z`. Then, split Eq. POP into two statements: i. a scalar-multiplication statement (`Z = z*K`) and ii. a point-addition statement (`Z = Hpt + Q`).

3. Curve-operation proofs.
   Prove the two statements with the Sigma protocols of {{scalar-mult}} (scalar multiplication, `SM`) and {{point-addition}} (point addition, `PA`), run in parallel.

Symbolically, with `x` denoting parallel (AND) composition and `o` sequential composition of functionalities (see {{RoK}}), our PoP is:

~~~
PoP = ( SM x PA ) o group o transfer
~~~

Each functionality is an honest-verifier zero-knowledge reduction.
This composition in the reduction of knowledge framework is then made non-interactive by applying the Fiat-Shamir transform ({{fiat-shamir}}), deriving every verifier challenge from the transcript; the exact per-challenge transcript inputs remain to be specified (see {{fiat-shamir}}).
The result is a non-interactive zero-knowledge proof of knowledge for (Eq. POP).

# Parameters and Encodings

## Curves and Generators

An instantiation of this PoP fixes:

- the ECDSA curve P-256, with generator `P`, group order `n_p`, base field `F_q`;
- the Tom curve Tom-256 with group `G_t` whose scalar field is `F_q`, with two independent Pedersen generators `(G_t, H_t)`;
- the credential-layer commitment scheme (e.g., Pedersen over BLS12-381) and its generators, as fixed by the credential profile (e.g. {{MODULAR-BBS}}).

The generators `(G_t, H_t)` MUST be sampled verifiably (e.g., via hash-to-curve from fixed domain-separation strings) so that no party knows their relative discrete logarithm.
The concrete instantiation of such parameters should be resolved by future standardisation efforts.

## Committing to a P-256 Public Key {#encoding}

A P-256 public key is a point `Q = (x, y)` in `F_q^2`.
Because the credential-layer commitment commits to scalars of the credential curve (`F_s`), each coordinate is encoded as a fixed number of limbs in `F_s`, and the limbs are committed with Pedersen.

This document adopts the approach of {{PAPER}}, where each of `x` and `y` is split into two 128-bit little-endian limbs, i.e.

~~~
x = x_0 + 2^128 * x_1,   0 <= x_i < 2^128
~~~

and likewise for `y`.
This matches the four 128-bit limb commitments (at indices `[0, 1, 2, 3]`) now used by the `ecdsa-p256-db` device binding of {{MODULAR-BBS}}, which adopted this layout to align with {{PAPER}}.
The 128-bit limb size guarantees 112 bits of security for the transfer of {{transfer}} -- sufficient for this application -- and is chosen for efficiency and for interoperability with {{MODULAR-BBS}}; the proofs below are otherwise agnostic to the limb size (see {{transfer}}).

The credential layer is responsible, at issuance, for guaranteeing that (a) each limb lies in its declared range and (b) `(x, y)` is a valid P-256 point.
This PoP assumes those facts hold a priori and does not re-prove them.

# Commitment Transfer {#transfer}

The PoP operates over the Tom curve, but the credential layer commits `Q` over the credential curve.
The transfer step re-expresses the commitment to `Q` as commitments over Tom-256, preserving the committed value.
Following {{PAPER}}, it is structured as a *reduction of knowledge* ({{RoK}}): a public-coin interactive reduction that maps a committed statement under the credential-curve scheme to the *same* statement under the Tom-curve scheme, after which the curve-operation proofs of {{rok-group}} take over.

Let `Commit` be the credential-curve commitment scheme and `Commit~` the Tom-curve scheme.
Generically, for each committed value `m_i` with credential-curve commitment `C_i`, the prover produces a fresh Tom commitment `C~_i = Commit~(m_i; rho~_i)` and proves, with a public-coin proof of knowledge `EQ`, the relation

~~~
R_eq = { (C_i, C~_i ; m_i, rho_i, rho~_i) :
            C_i  = Commit (m_i; rho_i)  AND
            C~_i = Commit~(m_i; rho~_i) }
~~~

i.e. that `C_i` and `C~_i` open to the same value.
All instances of `EQ` run in parallel.

For Pedersen-to-Pedersen transfer across the credential and Tom curves, `EQ` MUST be instantiated with a cross-group equality-of-opening proof for small-integer messages (the technique of {{OKMZ}}); the limb encoding of {{encoding}} guarantees the small-message precondition.

## Protocol

Unrolling the reduction of {{PAPER}} with `EQ` instantiated by the cross-group proof of {{OKMZ}} gives the following per-limb, public-coin protocol.
It is run in parallel over all committed limbs, sharing a single challenge `c`.
Write `(g, h)` for the credential-curve Pedersen generators and `(G_t, H_t)` for the Tom generators ({{encoding}}), and let `b_m`, `b_c`, `b_f` be the {{OKMZ}} message-bound, challenge, and slack widths, with

~~~
b_m + b_c + b_f  <  log2( min(|F_s|, |F_q|) )
~~~

so that every value below stays an integer in both scalar fields (no wraparound).

~~~
Prover P                                  Verifier V
  inputs: m_i, rho_i  (0 <= m_i < 2^b_m)  inputs: C_i = m_i*g + rho_i*h

  # 1. new commitment: reduce the statement to Tom
  rho~_i <- F_q
  C~_i = m_i*G_t + rho~_i*H_t
                 ---            C~_i            --->

  # 2. announcement: bounded masks in both groups
  k_i  <- { 0, ..., 2^(b_m + b_c + b_f) - 1 }
  t_i  <- F_s;   t~_i <- F_q
  A_i  = k_i*g   + t_i*h
  A~_i = k_i*G_t + t~_i*H_t
                 ---         A_i, A~_i          --->
                 <---   c <- {0,...,2^b_c - 1}  ---
  # 3. bounded response (z_i over the integers)
  z_i  = k_i  + c*m_i
  s_i  = t_i  + c*rho_i        (in F_s)
  s~_i = t~_i + c*rho~_i       (in F_q)
  if z_i outside the admissible range R: abort and restart
                 ---       z_i, s_i, s~_i       --->

Verifier checks (per limb i):
  (1)  z_i*g   + s_i*h    == A_i  + c*C_i   # open, cred curve
  (2)  z_i*G_t + s~_i*H_t == A~_i + c*C~_i  # open, Tom curve
  (3)  z_i in R                             # range: no wraparound
~~~

The abort in step 3 is the rejection sampling of {{OKMZ}}; the admissible range `R` and the exact bound widths are those of {{OKMZ}}, to which implementations MUST conform.
On acceptance, both parties use Pedersen homomorphism to fold the per-limb Tom commitments `C~_i`, weighted by the appropriate powers of `2^b_m`, into the two single-scalar coordinate commitments

~~~
C_x = Commit~(x; rho_x),    C_y = Commit~(y; rho_y)
~~~

These two commitments, together denoted `C_Q`, are the output statement of the reduction and the committed form of `Q` used by the remaining proofs.

This document adopts 128-bit limbs (and the parameters `b_m = 128, b_c = 112, b_f = 8`) for the transfer, as in {{PAPER}}: this minimizes the number of cross-group instances, and with the {{OKMZ}} parameters achieves 112-bit security.
Smaller limbs (e.g. 64-bit) work equally well -- they leave more headroom below `min(|F_s|, |F_q|)` and so can reach higher soundness -- at the cost of proportionally more cross-group instances; profiles with stricter requirements SHOULD adjust the limb size and repetition accordingly.

# Reduction to Curve Operations {#rok-group}

After transfer, the statement is (Eq. POP) with `Q` committed over Tom as `C_Q`, `K` and `Hpt` public.
The `group` reduction introduces the point `Z = z*K` and splits (Eq. POP) into independent scalar-multiplication and point-addition statements.

Inputs:

~~~
statement: (C_Q, K, Hpt)   witness: (z, Q, rho_Q)
relation:  z*K = Hpt + Q
~~~

Protocol:

1. P computes `Z = z*K`, samples randomness `rho_Z`, and sends `C_Z = Commit~(Z; rho_Z)` (a Tom commitment to the P-256 point `Z`).
2. Both parties compute `C_H = Commit~(Hpt; 0)`, the (deterministic, zero-randomness) commitment to the public point `Hpt`.
3. The reduction outputs two statements:

   - Scalar multiplication: `statement_SM = (C_Z, K)`, `witness_SM = (Z, rho_Z, z)`, asserting `Z = z*K`.
   - Point addition: `statement_PA = (C_Q, C_H, C_Z)`, `witness_PA` the openings of the three commitments, asserting `Q + Hpt = Z` (equivalently `Z = Hpt + Q`, Eq. POP).

Note that `C_Q = (C_x, C_y)` is a pair of coordinate commitments; the point-addition proof of {{point-addition}} operates per coordinate.
Likewise `C_Z` and `C_H` are coordinate-commitment pairs.

The two output statements are then proved in a parallel composition: `SM x PA`.

# Scalar-Multiplication Proof {#scalar-mult}

This section specifies the Sigma protocol `SM` proving the relation

~~~
R_SM = { ((C_Z, K) ; Z, rho_Z, z) :
            C_Z = Commit~(Z; rho_Z)  AND  Z = z*K }
~~~

where `K` is a public P-256 point, `z` a secret scalar, and `Z` a P-256 point committed over Tom.

`SM` is the scalar-multiplication proof of CDLS {{CDLS}}, used here with one modification from {{PAPER}}: the original protocol additionally committed to the scalar, whereas here `z` is a free (uncommitted) witness, which improves efficiency.

It is a bit-challenge Schnorr-type proof: a single execution uses a one-bit verifier challenge and has knowledge-soundness error `1/2`.
To reach error `2^-lambda`, `lambda` independent executions are run in parallel (`lambda = 128` is RECOMMENDED).
In one execution, the prover derives from its witness an auxiliary ("combined") instance using fresh randomness, sends the corresponding commitments, the verifier replies with a challenge bit, and the prover opens one of two related committed instances according to that bit; the point relation among the committed instances is established by invoking the point-addition proof internally.
The per-execution protocol is that of {{CDLS}} (Construction for `R_SM`), with the scalar treated as a free witness as noted above.

## Protocol

The following is one execution, between prover `P` and verifier `V`; `lambda` such executions run in parallel and share a single Fiat-Shamir transcript ({{fiat-shamir}}).
`F_np` is the scalar field of P-256, and `Commit~` the Tom commitment scheme of {{transfer}}.
As in {{rok-group}} and {{point-addition}}, each `Commit~` to a P-256 point is a pair of coordinate commitments -- one to the `x` and one to the `y` coordinate -- so `C_Z`, `C'`, and `C''` are coordinate-commitment pairs, and the openings (`rho_Z`, `rho'`, `rho''`, `tau`) and check (2) are taken per coordinate.

~~~
Prover P                                        Verifier V
  inputs: Z, z, rho_Z   (Z = z*K)               inputs: C_Z, K

  # sample a fresh "combined" instance
  omega <- F_np \ {0, z, 2z}
  Z'  = omega*K                  # public-scalar multiples of K
  Z'' = (omega - z)*K
  rho', rho'' <- Tom randomness
  C'  = Commit~(Z';  rho')
  C'' = Commit~(Z''; rho'')

  # point-addition instance over the committed points,
  # asserting  Z + Z'' = Z' :
  #   statement_PA = (C_Z, C'', C')
  #   witness_PA   = (Z, rho_Z, Z'', rho'', Z', rho')
  # PA is run with the C[2]-opening dropped (see {{point-addition}})
  msg_1 = announcement of PA on statement_PA
                 ---     C', C'', msg_1     --->
                 <---       b <- {0,1}      ---
  msg_2 = response of PA under challenge b
  if b = 0:  (alpha, tau) = (omega,       rho')
  if b = 1:  (alpha, tau) = (omega - z,   rho'')
                 ---   alpha, tau, msg_2    --->

Verifier checks:
  (1)  PA on (C_Z, C'', C') accepts the transcript (msg_1, b, msg_2)
  (2)  if b = 0:  C'  == Commit~(alpha*K; tau)
       if b = 1:  C'' == Commit~(alpha*K; tau)
~~~

Because `Z' = omega*K` and `Z'' = (omega - z)*K` are public-scalar multiples of `K`, the committed points satisfy `Z + Z'' = z*K + (omega - z)*K = omega*K = Z'`; the point-addition proof `PA` ({{point-addition}}) establishes this relation among `C_Z`, `C''`, `C'`, and is run here with the one-bit challenge `b`, which it shares with the opening (its announcement and response are `msg_1` and `msg_2`).
Inside this composition `PA` drops its `C[2]` opening proof (the lines flagged `omit in SM` in {{point-addition}}), since the opening of `C_Z` is recovered from the two openings revealed across the `b = 0` and `b = 1` transcripts.
The exclusion of `{0, z, 2z}` when sampling `omega` keeps `Z`, `Z'`, `Z''` non-identity and pairwise non-opposite, so the non-degeneracy precondition of {{point-addition}} holds.
An extractor with accepting responses for both `b = 0` and `b = 1` recovers `alpha_0 = omega` and `alpha_1 = omega - z`, hence `z = alpha_0 - alpha_1` and the opening of `C_Z` as `Z = z*K`; revealing only one opening per execution gives (statistical) honest-verifier zero knowledge.

When expressed via {{SIGMA}}, `SM` is a custom `SigmaProtocol` (not a plain `LinearRelation`): its challenge is a single bit and the protocol is run as `lambda` parallel repetitions.
Its zero-knowledge simulator follows the standard simulation for bit-challenge Sigma protocols (sample the challenge bit, then produce a consistent commitment and response).

# Point-Addition Proof {#point-addition}

This section specifies the Sigma protocol `PA` proving the relation

~~~
R_PA = { ((C_1, C_2, C_3) ; P_1, P_2, P_3, openings) :
            C_i = Commit~(P_i; rho_i)  AND  P_1 + P_2 = P_3 }
~~~

over Tom commitments to the affine coordinates of `P_1 = (a_x, a_y)`, `P_2 = (b_x, b_y)`, `P_3 = (t_x, t_y)`, under the promise `P_1 != +-P_2` and `P_1, P_2 != identity` (guaranteed by the callers in this document).
Each `C_i` is a pair of coordinate commitments; we write `C_1 = (C[1], C[2])`, `C_2 = (C[3], C[4])`, `C_3 = (C[5], C[6])`, committing to `a_x, a_y, b_x, b_y, t_x, t_y` respectively, all over Tom with generators `(G, H) = (G_t, H_t)`.

## Affine Addition Constraints

For `P_3 = P_1 + P_2` with `tau = (b_y - a_y) / (b_x - a_x)` over `F_q`, the affine addition law is equivalent to the three constraints

~~~
(C1)   tau * (b_x - a_x) = b_y - a_y
(C2)   tau^2             = a_x + b_x + t_x
(C3)   tau * (a_x - t_x) = a_y + t_y
~~~

together with `b_x - a_x != 0` (which enforces `P_1 != +-P_2`).
`PA` proves knowledge of openings of the coordinate commitments and of a commitment to `tau` satisfying (C1)-(C3).

## Protocol

`PA` is the linear relation of {{SIGMA}} instantiated over T256:

~~~
Relation PA(H, C1, C2, C3, C4, C5, C6, Ctau, U1):
  Witness: tau, rtau, f1, rf1, e1, e2, f3, rf3, e3, ay, r2, b1, b2, m
  Equations:
    Ctau = tau * G + rtau * H              # slope commitment
    C3 - C1 = f1 * G + rf1 * H             # factor of (C1)
    C4 - C2 = tau * (C3 - C1) + e1 * H     # (C1)
    C1 + C3 + C5 = tau * Ctau + e2 * H     # (C2), squaring
    C1 - C5 = f3 * G + rf3 * H             # factor of (C3)
    C2 + C6 = f3 * Ctau + e3 * H           # (C3)
    C2 = ay * G + r2 * H                   # omit in SM
    U1 = m * G                             # non-zero, part 1
    U1 = b1 * (C3 - C1) + b2 * H           # non-zero, part 2
~~~

`G` is the T256 generator, `H` the auxiliary Pedersen generator.

Note that instance validation in {{SIGMA}} rejects the identity in every instance element. Therefore, `U1 != identity` and thus `m = b1 * f1 != 0` (assuming the discrete logarithm of `H`base `G` is not known), hence `f1 = b_x - a_x != 0` and `P_1 != +-P_2`.

The prover holds `a_x`, `a_y`, `b_x`, `b_y`, `t_x`, `t_y` and `r_1`, ..., `r_6`; the verifier holds `C[1]`, ..., `C[6]`. The prover completes the instance with two elements of its own:

~~~
tau = (b_y - a_y) / (b_x - a_x)
r_tau  <-$ F_q;         Ctau = tau * G + r_tau * H
beta_1 <-$ F_q \ {0};   U1 = (beta_1 * (b_x - a_x)) * G
~~~

and runs the {{SIGMA}} prover with the witness

~~~
f1 = b_x - a_x   rf1 = r_3 - r_1   e1 = (r_4 - r_2) - rf1 * tau
f3 = a_x - t_x   rf3 = r_1 - r_5   e3 = (r_2 + r_6) - r_tau * f3
ay = a_y         r2  = r_2         e2 = (r_1 + r_3 + r_5)
                                        - r_tau * tau
b1 = beta_1      b2 = -beta_1 * rf1   m = beta_1 * f1
~~~

`Ctau` and `U1` prepend the NARG string:

~~~
pa_proof =  Group.serialize([Ctau, U1]) || sigma_narg_string
~~~

The verifier rebuilds the instance from `C[1]`, ...`C[6]` and the received elements. Then, runs the {{SIGMA}} verifier; no checks beyond it are needed.

When `PA` is composed with `SM` (Section 7), the equation `C[2] = ay * G + r2 * H` is un-necessary (Optimisation 3 of {{PAPER}}) and is therefore omitted, together with the scalar witnesses `ay`, `r2`.

# Non-Interactive Proofs (Fiat-Shamir) {#fiat-shamir}

The interactive protocols above are public-coin and are made non-interactive with the Fiat-Shamir transform specified in the companion document {{FIAT-SHAMIR}}, applied to the Sigma protocols composed via {{SIGMA}}: each verifier challenge -- the equality-proof challenge of {{transfer}}, the bit-challenge `b` of {{scalar-mult}}, and the challenge `c` of {{point-addition}} -- is derived by absorbing, into the {{FIAT-SHAMIR}} codec (duplex sponge), a transcript that includes a protocol/version domain separator, the ciphersuite identifier, the full statement, and all prior prover messages.

Implementations MUST use the codec and challenge-derivation of {{FIAT-SHAMIR}} and MUST include the following in the Fiat-Shamir transcript:

- a fixed domain-separation label for this PoP and its version;
- the public statement of (Eq. POP): `K`, `nonce` (or `Hpt`), and the committed key `C_Q` (and, after transfer, the Tom commitments);
- for the bound presentation context, the challenge octets supplied by the calling protocol (see {{integration}}).

The exact Fiat-Shamir binding for the composed protocol is not yet fixed by this document.
In particular, the precise inputs absorbed before each challenge -- the domain separator, the credential- and Tom-curve commitments and announcements of the transfer ({{transfer}}), the prover messages of `SM` and `PA`, and the {{OKMZ}} bound parameters -- remain to be specified, and MUST be pinned down (consistent with {{FIAT-SHAMIR}}) before this profile is interoperable.
The move structure of the sub-protocols is normative; the exact byte-level Fiat-Shamir inputs and complete composed protocol specification are deferred to a future revision.

# Integration with Modular BBS {#integration}

When used as the `ecdsa-p256-db` sub-proof of {{MODULAR-BBS}}:

- The holder's P-256 public key occupies four committed BBS messages carrying its 128-bit limbs, encoded as in {{encoding}}.
  The sub-proof carries `alg = "ecdsa-p256-db"` and takes no inputs beyond the base sub-proof fields; its `i` field MUST be `[0, 1, 2, 3]`, naming the four indices that hold these limbs.
  The BBS core proof (`CoreProofGen`) exposes the four messages as Pedersen commitments over the credential curve; these are the inputs `C_i` to the transfer of {{transfer}}.
- The four messages MAY be populated at issuance as committed messages using blind BBS issuance ({{BLIND-BBS}}): the holder sends the issuer a commitment to its device public key (with the holder-held blinding scalar) and a proof of its correctness, and the issuer blindly signs without learning `Q`.
  This keeps the device secret key bound to the holder's secure element and unknown to the issuer, and the issuance-time commitment to `Q` is reused as the transfer input above.
- The message signed by the secure element is not transmitted; both parties recompute it as `db_msg = "JWP-BBS-DB-CHAL" || presentation_header_octets`, where `"JWP-BBS-DB-CHAL"` is the literal ASCII string.
  Because `db_msg` binds `presentation_header_octets` (which carries the `nonce` and `aud`), it is fresh per presentation.
  `db_msg` is the ECDSA message of the PoP: it plays the role of `nonce` in {{overview}}, so `alpha` and `Hpt` are formed from `H(db_msg)`.
- The `proof` bytes are the serialized non-interactive PoP ({{fiat-shamir}}): a zero-knowledge proof of knowledge of `(Q, (r, s))` such that the four commitments at the indices in `i` open to the 128-bit limbs of `Q`, and `(r, s)` is a valid ECDSA P-256 signature on `db_msg` under `Q`.
- The verifier accepts iff the four indices in `i` are all committed in the core proof and the sub-proof verifies against the four commitments and the locally recomputed `db_msg`.
  This meets the {{MODULAR-BBS}} requirement that a sub-proof bind to commitments attested by the core proof, since the transfer of {{transfer}} ties the Tom commitments `C_Q` to the credential-curve commitments produced by `CoreProofGen`.

The PoP itself is agnostic to the credential scheme: any scheme that can expose a Pedersen commitment to the device public key over a curve supported by the transfer of {{transfer}} can use this sub-proof.

# Implementation Status

> Note to the RFC Editor: please remove this section before publication.

A public, benchmarked reference implementation of the complete Schnorr-type PoP specified here -- the `( SM x PA ) o group o transfer` composition of {{overview}}, including the {{OKMZ}} style commitment transfer of {{transfer}} and the Tom-256 scalar-multiplication and point-addition proofs -- is available at <https://github.com/hpicrypto/ecdsa_pops>.
It is written in Rust and underlies the measurements reported in {{PAPER}}.

{{PAPER}} gives three realizations of the same ECDSA-device-binding relation -- the Schnorr-type proof specified in this document and two circuit-based variants that are out of scope here (see {{scope}}) -- and earlier variants of the Schnorr-type approach appear in {{UBIQUE}}.
The repository above is the specific implementation that matches this document's Schnorr-type protocol and parameter choices.

# Security Considerations

Knowledge soundness.
: The composed protocol is a proof of knowledge for (Eq. POP) (see {{PAPER}} for the analysis in the reductions-of-knowledge framework).
  `SM` has soundness error `2^-lambda` after `lambda` parallel repetitions; `PA` has the `2^-lambda` soundness error of a Sigma protocol over `F_q`.
  At the moment, we set `lambda = 128`, but since the commitment linking protocol {{transfer}} achieves 112 bits of soundness for our proposed parameters, we may update to `lambda = 112` in future revisions.
  Soundness of the overall PoP additionally relies on the binding of all Pedersen commitments, i.e. on the discrete-log assumption in both the credential curve and the Tom curve, and on the small-message soundness precondition of the transfer proof ({{transfer}}).

Zero knowledge / unlinkability.
: Each sub-protocol is honest-verifier zero-knowledge; with Fiat-Shamir over a random oracle the composition is non-interactive zero-knowledge.
  The device public key `Q` is the only long-lived value and remains perfectly hidden by the Pedersen commitments, so presentations are unlinkable.
  The ephemeral value `K` is fresh per signature and per presentation; revealing it does not link presentations.
  Implementations MUST use fresh randomness for every commitment and every proof; reuse of the per-execution randomness in `SM`, of commitment randomizers, or of the per-presentation `nonce` can leak the secret key or link presentations.

Secure-element trust.
: This PoP assumes the device secret key never leaves the secure element and that the element produces signatures only on inputs presented to it; the holder cannot extract the key.
  Revealing `K` as part of the statement is sound for proof of possession only under the honest-secure-element assumption discussed in {{PAPER}}.

Choice of the Tom curve.
: Using the Tom curve introduces a discrete-log assumption over an additional, less-studied curve.
  Deployments unwilling to take this assumption should use a circuit-based realization instead (out of scope here).
  `(G_t, H_t)` and all credential-curve generators MUST be nothing-up-my-sleeve / verifiably random so no party knows discrete-log relations among them.

Non-degeneracy.
: The point-addition proof is sound only under `P_1 != +-P_2` and `P_1, P_2 != identity`.
  The callers in this document guarantee these: `SM` excludes the degenerate scalars when forming its auxiliary instances (per {{CDLS}}), and the `group` reduction fixes the operands structurally.
  Other callers MUST establish these preconditions independently.

Post-quantum.
: As with all discrete-log Sigma protocols, these proofs provide (statistical) zero-knowledge against unbounded adversaries but are not sound against quantum adversaries.

# IANA Considerations

This document has no IANA actions of its own.
It defines the construction behind the `ecdsa-p256-db` sub-proof algorithm whose registration is requested by {{MODULAR-BBS}} in that document's sub-proof algorithm registry; this document does not create a new registry.

--- back

# Note on Authorship
{:numbered="false"}

The authors are listed in alphabetical order by surname and contributed equally to this work; the ordering does not denote a lead or corresponding author.
The document name uses the authors' combined initials ("cllz") rather than any single surname.
The "et al." form that appears in running headers is an artifact of the RFC document format and carries no such connotation here.

# Acknowledgments
{:numbered="false"}

This specification is derived from the construction and analysis in {{PAPER}}.
The Schnorr-type proof of possession formalizes and optimizes the ECDSA-device-binding approach of {{UBIQUE}} and the CDLS / zkAttest proofs of {{CDLS}} and {{ZKATTEST}}, composed through the modular credential framework of {{LSZ}} and the reductions-of-knowledge framework of {{RoK}}.
