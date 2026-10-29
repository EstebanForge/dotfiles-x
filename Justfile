default:
    @just --list

# Lint shell scripts (bash syntax + shellcheck)
check:
    bash -n dots.sh scripts/*.sh scripts/lib/*.sh test/*.sh
    shellcheck dots.sh test/smoke.sh

# Run sandbox smoke tests
test:
    ./test/smoke.sh

# Show dotfiles symlink status
status:
    ./dots.sh status

# Run dotfiles doctor diagnostics
doctor:
    ./dots.sh doctor

# Local CI gate
ci: check test
