# sync-test

Throwaway repositories that prove one way to keep a public and a private
repository of the same product in sync. Safe to delete. This README is written
for people and for coding agents alike: read it whole before acting on either
repository.

| repository | visibility | role |
|---|---|---|
| `sync-test-public` | public | the only real `main`. Every merge ends here |
| `sync-test-private` | private | a review room for the rare pull request whose discussion must stay private. Its `main` is a mirror |
| `sync-test-private-only` | private, collaborators only | code that must never be public, built on top of the public core |

The two first repositories hold the same tree and the same history: their
`main` branches point at the same commit, SHA for SHA.

## The model

```
public PR  ── review, Merge button ─────────────────────────────▶ public main
private PR ── private review ── scripts/land.sh: one commit ───▶ public main
public main ── scripts/mirror.sh: fast-forward only ───────────▶ private main
```

- **One writer per `main`.** Public `main` takes merges from the public Merge
  button and from `land.sh`. Private `main` takes only the mirror.
- **Nothing is ever force-pushed** to either `main`. A mirror that cannot
  fast-forward stops and says why.
- **Only the discussion stays private.** The code, comments, file names and
  the pull request title of a landed private PR all become public.

## Which repository do I open a pull request in?

| the change | where |
|---|---|
| bug fix, redesign, refactor, docs, anything a user could ask about | public |
| the change itself is fine, but its review will mention something that is not public yet (an unannounced product, a licence or branding question, a business decision, a security issue before disclosure) | private, then `land.sh` |
| code that must never be public | its own private repository, see [Code that never goes public](#code-that-never-goes-public) |

When unsure, ask before opening it. A private PR costs a land step; a public
PR that mentions something unannounced cannot be taken back.

## Flows

### A public pull request

Review and merge it in the public repository as usual. The mirror carries the
commit to the private `main`. Nothing else to do.

### A private pull request

1. Open it in the private repository and review it there. Work-in-progress
   commits are fine: they never leave.
2. Make the pull request **title** the public commit message. It is the only
   text that leaves. The body and the review stay private.
3. Once it is approved, land it from a clone that has two remotes, `public`
   and `private`:

   ```sh
   git remote add public  https://github.com/vyacheslav-voloshyn/sync-test-public.git
   git remote add private https://github.com/vyacheslav-voloshyn/sync-test-private.git
   LAND_DENY="$(cat ~/.land-deny)" make land PR=12
   ```

`land.sh` then:

1. refuses an unapproved PR (`REQUIRE_APPROVAL=0` skips this in single-account
   tests) and a title matching `LAND_DENY`;
2. merges the branch onto the fresh public `main` with `git merge-tree` and
   writes one commit: the PR title as message, the first commit's author as
   author;
3. on a conflict, pushes nothing and comments the conflicting files on the PR;
4. force-pushes that exact commit to the PR branch, so private CI has run on
   the SHA that lands;
5. pushes it to public `main` without force, and starts again from step 2 if
   public `main` moved in between (three attempts);
6. runs the mirror, then waits until GitHub shows the private PR as merged.
   GitHub does that on its own once private `main` contains the PR's head commit.

`LAND_DENY` is an extended regex of names that must not leave. Keep the real
list out of this public tree. The default only catches `ABC-123` style keys
and `.internal` hosts.

### Keeping the private `main` in sync

`.github/workflows/mirror.yml` runs `scripts/mirror.sh` in the private
repository. It runs only where the `PUBLIC_REPO` repository variable is set,
so the same file stays inert in the public repository. It starts on
`workflow_dispatch` or on a `repository_dispatch` of type `public-main-moved`.
A person can also run `scripts/mirror.sh` from a clone with both remotes.

## Code that never goes public

Identical trees mean the private repository cannot hold extra code. Code that
must never be public lives in its own private repository and builds on the
public core instead:

- The core lets a feature register itself (`core.Register`). A build decides
  which features exist by the packages it imports.
- Public extension points are plain public API. `core/fractal` exposes
  `Capabilities`, which a private package may append to.
- `sync-test-private-only` imports this module, adds its own feature and extends
  `fractal.Capabilities`, with not one line about it in this tree. Its README
  shows the build.

In the real product this is an extension in its own repository, installed
through the product's extension system. The public tree only ever sees the
extension API.

```sh
go run ./cmd/server          # public build
# fractal  fractal node, capabilities: jobs, files
```

## Rules for agents

- Never press Merge in the private repository and never push to either `main`
  by hand. Public merges and `land.sh` are the only ways in.
- Never pass `--force` to a push that targets `main`.
- Never mention an unannounced product, a customer, a ticket key or an
  internal host in anything that lands: code, comments, file names, commit
  messages, the private PR title.
- When `land.sh` or the mirror refuses, report its message and stop. Do not
  work around a refusal.
- Code that must stay private goes to its own private repository, never into
  this tree.

## What the test showed

| scenario | result |
|---|---|
| public PR merged with the button | the mirror fast-forwards private `main`; SHAs are equal |
| private PR landed | one commit with the title only, no WIP commits, no private PR number; GitHub marks the private PR merged |
| public `main` moves during review, or between land's fetch and push | rebased; the rejected push is retried and succeeds |
| conflicting private PR | nothing pushed; the PR gets a comment naming the files |
| internal name in the title | refused; nothing leaves |
| someone pushes straight to private `main` | the mirror fails, lists the foreign commit, rewrites nothing |
| a tag created in public | arrives through the mirror |
| a mirrored commit changes `.github/workflows/` | **fails** with `GITHUB_TOKEN`: it lacks the `workflows` permission. A real setup needs a GitHub App token for the mirror |

Not tested here: a GitHub App as the ruleset bypass actor (the repository
admin role stood in for it), a ruleset on the private repository (personal
free plan), the approval check (one account), and triggering the mirror from a
public event.

## A real setup needs

- a GitHub App owned by the public organisation with a ruleset bypass on
  public `main`, used by `land.sh` instead of a person;
- an App token with `contents` and `workflows` write on the private repository
  for the mirror;
- a ruleset on public `main`: changes through a pull request, no force pushes,
  the App as the only bypass actor;
- a ruleset on private `main`: only the mirror may write.
