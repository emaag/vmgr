#!/usr/bin/env bash
# Unit tests for vmgr-completion.bash: the words offered for each position

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
source "$VMGR_ROOT/vmgr-completion.bash"

# _complete WORD...: complete the last word given, the way bash would
_complete() {
    COMP_WORDS=("$@")
    COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
    COMPREPLY=()
    _vmgr_completion
    echo "${COMPREPLY[*]}"
}

test_commands_include_the_newer_ones() {
    local out; out="$(_complete vmgr '')"
    assert_contains "reddit-setup" "$out" "complete: reddit-setup is offered"
    assert_contains "catalog-duplicates" "$out" "complete: catalog-duplicates is offered"
}

test_reddit_sort_and_time_values_are_offered() {
    assert_equals "top" "$(_complete vmgr reddit pics out --sort to)" "complete: --sort values"
    assert_equals "week" "$(_complete vmgr reddit pics out --time we)" "complete: --time values"
    assert_contains "--sort" "$(_complete vmgr reddit pics out --s)" "complete: --sort itself"
}

test_the_subreddit_position_offers_no_folders() {
    local d; d="$(mktemp -d)"; mkdir "$d/pictures"
    ( cd "$d" && assert_equals "" "$(_complete vmgr reddit p)" "complete: a subreddit name is not completed from folders" )
    ( cd "$d" && assert_equals "" "$(_complete vmgr reddit pics,EarthPorn)" "complete: a comma list is left alone too" )
    ( cd "$d" && assert_equals "pictures/" "$(_complete vmgr reddit pics,EarthPorn pict | sed 's#pictures$#pictures/#')" "complete: the folder after the names is completed" )
    rm -rf "$d"
}
