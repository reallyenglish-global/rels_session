# Reek advisory CI pilot

## Scope

`rels_session` is a Rails integration gem. The `Reek advisory` workflow scans its `lib/` implementation on pull requests targeting `main` that change `lib/`, `.reek.yml`, or the workflow. It does not change the existing Redis/RSpec workflow, add a runtime dependency, require a Redis connection, or modify branch protection. Keep this check optional during the pilot.

## Run locally

Use Ruby 3.4.8 (the repository's CI version):

```sh
mise exec -- gem install reek --version 6.6.0 --no-document
mise exec -- reek lib
```

Reek itself is pinned; transitive gem dependencies are not lockfile-pinned. The scan looks at the entire `lib/` snapshot, not just new lines. The Actions job reports smell findings without failing; an unexpected scanner failure is a failed optional job, not a clean scan. Setup errors show as failed steps. The workflow uses read-only repository access and does not use `pull_request_target`.

## Verification

On base `5fbb3dd37633169572a2ddcd5bb42b0fde682b3a`, the local Ruby 3.4.8/Reek 6.6.0 scan reported 117 baseline smells. The workflow shell step was exercised locally on the real source, clean Ruby, invalid config, invalid Ruby syntax and an empty scope. Reek can return zero for an invalid Ruby file, so the workflow explicitly checks stderr; nonempty stderr is treated conservatively as an incomplete scan. These checks do not prove execution on a GitHub-hosted runner.

## Triage and decision

- Inspect the scan log for locations and smell names. A finding is a prompt to inspect behavior, not proof of debt. Compare the PR base and candidate locally with the same version and scope to distinguish new findings from existing ones. A passing job alone does not mean there were no smells.
- Prioritize findings that point to scattered policy, difficult failure behavior, or duplicated business logic. Avoid unrelated cleanup, comment churn, and splitting methods just to satisfy a detector.
- After several real PRs, look at which findings prompted useful changes and how much review time or CI time the scan added. Tune or remove noisy checks before expanding. Do not make this workflow required simply because it ran successfully.
- To roll back the pilot, revert the workflow change. No runtime migration is needed.
