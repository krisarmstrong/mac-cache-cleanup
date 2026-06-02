<!-- Thanks for contributing! Keep PRs focused and small where possible. -->

## What does this change?

<!-- A short summary of the change and why. Link any related issue: Fixes #123 -->

## Which tools are affected?

- [ ] clear-outlook-cache
- [ ] clear-teams-cache
- [ ] clear-browsers
- [ ] shared (installer/CI/docs)

## Checklist

- [ ] `shellcheck -S warning $(git ls-files '*.sh')` passes
- [ ] `shfmt -i 2 -ci -bn -d $(git ls-files '*.sh')` shows no diff
- [ ] Tested `./install.sh`, `--time HH:MM`, and `uninstall` locally
- [ ] Updated the relevant README(s) if behavior changed
