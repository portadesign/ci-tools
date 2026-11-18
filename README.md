# ci-tools

Shared GitHub Actions workflows for Porta Design repositories.

## Claude review

On-demand code review of a pull request by Claude.

| Action | Result |
|---|---|
| Add the label `claude-review` to a PR | Review: verdict, numbered findings, inline comments on every ❌ |
| Write `@claude …` in a PR comment | Answer or change, organization members only |

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

### Rules

| Source | Applies to |
|---|---|
| Prompt in `.github/workflows/claude-review.yml` | Every repository |
| `profiles/<name>.md`, chosen by the argument (`pimcore`, `symfony`) | Repositories on that stack |
| `AGENTS.md`, `CLAUDE.md` of the repository | That repository |

Changes on `main` apply to every repository at once.

### Turn off

```sh
gh workflow disable "Claude review" -R portadesign/<repo>
```

Authentication: [wiki](https://github.com/portadesign/wiki/blob/main/GitHub/claude-review.md#keyless-authentication).
