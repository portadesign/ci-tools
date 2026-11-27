# ci-tools

Shared GitHub Actions workflows for Porta Design repositories.

## Claude review

On-demand code review of a pull request by Claude.

| Action | Result |
|---|---|
| Add the label `claude-review` to a PR | One review of the whole PR: verdict, numbered findings, an inline thread per finding, a suggested change where the fix is short |
| Push to a PR that has the label | One review of what changed since the last one; earlier findings are listed as still open or resolved |
| Remove the label | No review on further pushes |
| Write `@claude …` in a PR comment | Answer or change, organization members only |

- One review is one notification; the summaries of earlier reviews are hidden.
- Generated files, lock files and fixture data are not reviewed.
- A push that rewrites history (rebase, force-push) is reviewed in full.

### Install

```sh
composer config repositories.ci-tools vcs https://github.com/portadesign/ci-tools
composer require --dev portadesign/ci-tools:dev-main
vendor/bin/ci-tools claude-review pimcore
```

Without Composer:

```sh
curl -fsSL https://raw.githubusercontent.com/portadesign/ci-tools/main/bin/ci-tools | sh -s claude-review
```

The command writes `.github/workflows/claude-review.yml` and creates the label. Commit the file.

The file only forwards pull request events; which of them start a review is decided here, so it needs no
reinstall when the review changes.

### Rules

| Source | Applies to |
|---|---|
| Prompt in `.github/workflows/claude-review.yml` | Every repository |
| `profiles/<name>.md`, chosen by the argument (`pimcore`, `symfony`); `pimcore` includes `symfony` | Repositories on that stack |
| `AGENTS.md`, `CLAUDE.md` of the repository, and what its code consistently does | That repository; wins over the two above |

Changes on `main` apply to every repository at once.

### Test a change

Push a branch of ci-tools and point one repository at it:

```yaml
jobs:
  claude:
    uses: portadesign/ci-tools/.github/workflows/claude-review.yml@<branch>
    with:
      profile: pimcore
      ref: <branch>
```

`ref` makes the workflow load its scripts and profiles from that branch. Locally, `scripts/claude-review/context.sh`
runs against any PR (`GITHUB_REPOSITORY`, `PR`, `DIR`), and `post.sh` prints the review without posting it when
`DRY_RUN=1`.

### Turn off

```sh
gh workflow disable "Claude review" -R portadesign/<repo>
```

Authentication: [wiki](https://github.com/portadesign/wiki/blob/main/GitHub/claude-review.md#keyless-authentication).

## Composer audit

`composer audit --locked --abandoned=report` against `composer.lock`, without `composer install`.

| Trigger | Result |
|---|---|
| Pull request, push to the default branch | Fails on a security advisory, reports abandoned packages |
| Monday 06:00 UTC | Same check, catches advisories published since the last push |

### Install

```sh
composer config repositories.ci-tools vcs https://github.com/portadesign/ci-tools
composer require --dev portadesign/ci-tools:dev-main
vendor/bin/ci-tools composer-audit 8.1
```

Without Composer:

```sh
curl -fsSL https://raw.githubusercontent.com/portadesign/ci-tools/main/bin/ci-tools | sh -s composer-audit 8.1
```

The command writes `.github/workflows/composer-audit.yml`. Commit the file. The argument is the PHP version,
default `8.3`.

### Exceptions

An ignored advisory stays in the project's `composer.json` under `config.policy.advisories.ignore-id`, read by
Composer ≥ 2.10. The workflow does not handle exceptions.

### Turn off

```sh
gh workflow disable "Composer audit" -R portadesign/<repo>
```
