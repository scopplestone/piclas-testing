# Fortitude

[Fortitude is a Fortran linter](https://github.com/PlasmaFAIR/fortitude) that can be installed from PYPI via

    # With uv:
    uv tool install fortitude-lint@latest

    # With pip:
    pip install fortitude-lint

After installing, check the version

    fortitude --version

## Gitlab CI
The Fortitude Gitlab CI/CD stage `fortitude:` is defined in `.gitlab-ci.yml` and the Fortitude settings are stored in `fpm.toml`.

## Pre-commit hook
The pre-commit hook for Fortitude is configured in ...
