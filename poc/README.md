# SageMath reference implementation

A SageMath implementation of the Schnorr-type ECDSA proof of possession of
`draft-cllz-cfrg-ecdsa-pop`:

```
PoP = ( SM x PA ) o group o transfer
```

It is meant for readability and cross-checking the draft. It is not constant-time
and must not be used in production.

## Running it

Requires SageMath (tested with 10.5).

```
make test        # full suite, lambda = 128 SM repetitions
make test-fast   # lambda = 16, quick functional check
make clean
```

`make` preparses each `*.sage` file into `sagelib/*.py`. Modules import each other from there.

## Layout

| File                    | Draft section            | Contents |
|-------------------------|--------------------------|----------|
| `groups.sage`           | Parameters and Encodings | P-256, Tom-256, BLS12-381 G1; point encodings; Pedersen; `Commit~` of a P-256 point as a pair of coordinate commitments |
| `ecdsa.sage`            | Overview                 | ECDSA/SHA-256, rewriting `(r, s)` as `(K, z)`, `alpha` and `Hpt` |
| `linear_relation.sage`  | (SIGMA interfaces)       | `LinearRelation` / `SchnorrProof` modelled on draft-irtf-cfrg-sigma-protocols |
| `transfer.sage`         | Commitment Transfer      | OKMZ cross-group equality proof (`b_m=128, b_c=112, b_f=8`), rejection sampling, limb folding |
| `point_addition.sage`   | Point-Addition Proof     | `PA` as a linear relation (7 equations, or 6 without the `C[2]` opening inside SM) |
| `scalar_mult.sage`      | Scalar-Multiplication Proof | one bit-challenge execution of `SM`, which runs `PA` internally |
| `pop.sage`              | Reduction / Fiat-Shamir / Integration | composed non-interactive prover and verifier, proof serialization |
| `transcript.sage`       | Fiat-Shamir              | SHAKE128 transcript (placeholder, see below) |
| `rng.sage`              | --                       | secure RNG, plus a seeded RNG for reproducible tests |
| `test_pop.sage`         | --                       | tests: completeness, soundness checks, serialization |

## Choices the draft leaves open

The draft does not yet fix the items below. This implementation picks
something reasonable for each one. None of them are interoperable or normative:

- **Fiat-Shamir:** SHAKE128 with length-prefixed, labelled absorb/squeeze
  calls, instead of the draft-irtf-cfrg-fiat-shamir codec. Before the first
  challenge it absorbs, in order: the suite ID, the parameters
  (`lambda, b_m, b_c, b_f`), `ctx`, `msg`, the credential commitments and `K`.
  The first challenge is the transfer challenge `c`, taken after the transfer
  commitments and announcements. Then `C_Z` and every `SM` and `PA` first
  message are absorbed, and **one** squeeze yields the `lambda` SM bits and the
  `PA` challenge in `F_q`.
- **Generators:** `(G_t, H_t)` and the credential-curve `(g, h)` are derived by
  try-and-increment over SHAKE256 with fixed DSTs, not RFC 9380 hash-to-curve.
- **Transfer range `R`:** `[2^(b_m+b_c), 2^(b_m+b_c+b_f))`. The prover samples
  `k_i` in `[0, 2^(b_m+b_c+b_f))` and aborts if `z_i` is outside `R`, which
  happens with probability about 1/128 per limb. Each abort restarts the
  transfer with a fresh transcript fork.
- **Credential layer:** stood in for by one Pedersen commitment per limb over
  BLS12-381 G1, `C_i = m_i*g + rho_i*h`, with limbs ordered
  `[x_0, x_1, y_0, y_1]`. A real deployment takes these from BBS
  `CoreProofGen`.
- **Serialization:** SEC1-compressed P-256 and Tom-256 points, ZCash-compressed
  BLS12-381 points, big-endian scalars, and transfer responses `z_i` as
  31-byte integers.
- **Proof size** at `lambda = 128`: about 95 KiB, almost all of it from the
  128 SM executions (11 Tom points and 12 scalars each).
