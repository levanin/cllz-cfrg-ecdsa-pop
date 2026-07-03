# Collaborating on this draft

This document is the internal working copy of **draft-cllz-cfrg-ecdsa-pop**.
We use two repositories:

| Role | Repository | Remote name | Visibility |
|------|-----------|-------------|------------|
| Day-to-day work | `levanin/cllz-cfrg-ecdsa-pop-dev` | `origin` | **private** |
| Published / canonical | `levanin/cllz-cfrg-ecdsa-pop` | `public` | **public** |

All messy, work-in-progress, "silly small" commits live in the **private** repo.
The **public** repo only ever receives clean, squashed snapshots at release time,
and it is the one linked from the I-D and used to submit to the IETF Datatracker.

**Golden rules**

1. Always work against `origin` (the private repo). Never commit directly to the public repo.
2. Never pull the public repo's history back into private — treat `public` as write-only.
3. Only a maintainer runs the publishing steps and pushes `draft-*` tags.

---

## 1. One-time setup

Clone the **private** repo and add the public repo as a second remote:

```sh
git clone https://github.com/levanin/cllz-cfrg-ecdsa-pop-dev.git
cd cllz-cfrg-ecdsa-pop-dev
git remote add public https://github.com/levanin/cllz-cfrg-ecdsa-pop.git
git remote -v   # confirm: origin = -dev (private), public = the public repo
```

Notes on authentication:

- These URLs use **HTTPS**. The first push/pull will ask for credentials — use a
  GitHub **Personal Access Token** as the password (classic PAT with `repo` scope),
  or let the macOS Keychain / Git Credential Manager store it.
- If you prefer **SSH**, swap the URLs for `git@github.com:levanin/...git`, but you
  must have an SSH key registered with GitHub first (otherwise you get
  `Permission denied (publickey)`).

Set your identity if you haven't globally:

```sh
git config user.name  "Your Name"
git config user.email "you@example.com"
```

You do **not** need kramdown-rfc / xml2rfc installed just to edit the Markdown.
You only need them to build the draft locally (`make`); see `README.md`.

---

## 2. Ongoing work

Work however you like on the private repo — small commits are fine and encouraged.

```sh
git checkout main
git pull origin main            # get coauthors' latest
# ... edit draft-cllz-cfrg-ecdsa-pop.md ...
git add -A
git commit -m "whatever, wip is fine"
git push origin main
```

Prefer short-lived branches for anything non-trivial, then merge into `main`:

```sh
git checkout -b my-section
# ... work, commit freely ...
git push origin my-section       # open a PR against main on the PRIVATE repo
```

Everything here stays private. None of these commits ever reach the public repo
unless a maintainer publishes a snapshot (next section).

---

## 3. Publishing (maintainers only)

Publishing takes the current private `main`, lays it down as **one clean commit**
on the public repo, and (optionally) tags it to submit a new revision to Datatracker.
The private history is never squashed or altered.

```sh
# Make sure you have the latest of both sides
git checkout main
git pull origin main
git fetch public

# Build one clean commit on top of public's current tip
git checkout -B release          # throwaway branch at private HEAD
git reset --soft public/main     # keep the files, drop the private commit history
git rm --cached --ignore-unmatch COLLABORATING.md   # NEVER publish this file (keeps it on disk)
git commit -m "Update draft: <summary of what changed>"

# Push just that single commit to the public repo's main
git push public release:main

# Back to normal work
git checkout main
git branch -D release            # optional cleanup
```

The public repo now has one more tidy commit; no private commits travelled with it.

> **Private-only files.** `COLLABORATING.md` (this file) is tracked in the private
> repo so collaborators receive it, but the `git rm --cached` line above drops it
> from every public snapshot, so it never reaches the public repo. If you add more
> internal-only files later, add matching `git rm --cached --ignore-unmatch <file>`
> lines here.

### Submitting a new version to the IETF Datatracker

Datatracker submission is triggered by pushing an **annotated tag** named after the
next revision. The version number lives in the *tag name* (docname stays `-latest`),
so just bump the number each time.

```sh
# tag the commit you just pushed to public/main
git tag -a draft-cllz-cfrg-ecdsa-pop-01 -m "Version 01"
git push public draft-cllz-cfrg-ecdsa-pop-01
```

This fires the "Publish New Draft Version" GitHub Action on the public repo, which
builds and uploads revision `01`. Watch the Action run under the public repo's
**Actions** tab; you'll get a confirmation email to approve the submission.

Rules for versions:

- Increment every time: `-01`, `-02`, ... Never reuse or move an old tag —
  Datatracker rejects a revision it already has.
- Push tags **only to `public`**, never to `origin` (the private repo has Actions
  disabled precisely so a stray tag can't submit).

---

## Quick reference

```
origin  = private  (levanin/cllz-cfrg-ecdsa-pop-dev)   <- work here, push freely
public  = public   (levanin/cllz-cfrg-ecdsa-pop)       <- clean snapshots only

edit -> commit -> push origin main            (anyone, anytime)
publish -> reset --soft public/main -> push public release:main   (maintainer)
release -> tag draft-...-NN -> push public tag                    (maintainer)
```
