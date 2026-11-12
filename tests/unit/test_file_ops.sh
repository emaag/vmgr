#!/usr/bin/env bash
# Unit tests for lib/file-ops.sh pure functions:
#   apply_bracket_notation, remove_dashes, fix_bracket_spacing, cleanup_filename

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"

# ── apply_bracket_notation ────────────────────────────────────────────────────

test_bracket_basic() {
    local result
    result=$(apply_bracket_notation "studio filename.mp4")
    assert_equals "[Studio] filename.mp4" "$result" "bracket: basic studio filename"
}

test_bracket_single_word() {
    local result
    result=$(apply_bracket_notation "word.mp4")
    assert_equals "[Word].mp4" "$result" "bracket: single word filename"
}

test_bracket_capitalizes_first_letter() {
    local result
    result=$(apply_bracket_notation "abc rest.mkv")
    assert_contains "[Abc]" "$result" "bracket: first letter capitalised"
}

test_bracket_preserves_extension() {
    local result
    result=$(apply_bracket_notation "studio file.mkv")
    assert_contains ".mkv" "$result" "bracket: extension preserved"
}

test_bracket_dash_separator() {
    local result
    result=$(apply_bracket_notation "studio-rest.mp4")
    assert_contains "[Studio]" "$result" "bracket: dash separator handled"
}

test_bracket_dot_separator() {
    local result
    result=$(apply_bracket_notation "studio.rest.mp4")
    # first_word = "studio", separator = ".", rest = "rest"  ext = ".mp4"
    assert_contains "[Studio]" "$result" "bracket: dot separator handled"
}

test_bracket_underscore_in_name() {
    local result
    result=$(apply_bracket_notation "my_studio rest.mp4")
    assert_contains "[My_studio]" "$result" "bracket: underscore included in first word"
}

test_bracket_empty_filename_returns_nonzero() {
    local result
    result=$(apply_bracket_notation "" 2>/dev/null)
    local rc=$?
    assert_not_equals "0" "$rc" "bracket: empty filename returns non-zero"
}

test_bracket_no_extension() {
    local result
    result=$(apply_bracket_notation "studioname")
    assert_contains "[Studioname]" "$result" "bracket: no extension handled"
}

test_bracket_already_bracketed_passthrough() {
    # If the name already starts with [, the regex won't match [
    # (since [ is not in [a-zA-Z0-9_]) so the original is returned.
    local result
    result=$(apply_bracket_notation "[Studio] name.mp4")
    assert_equals "[Studio] name.mp4" "$result" "bracket: already-bracketed passthrough"
}

test_bracket_accented_first_word() {
    local result
    result=$(apply_bracket_notation "café title.mp4")
    assert_equals "[Café] title.mp4" "$result" "bracket: accented first word kept whole"
}

test_bracket_non_latin_first_word() {
    local result
    result=$(apply_bracket_notation "日本語 title.mp4")
    assert_equals "[日本語] title.mp4" "$result" "bracket: non-latin first word bracketed"
}

test_bracket_leading_whitespace_trimmed() {
    local result
    result=$(apply_bracket_notation "  studio name.mp4")
    assert_equals "[Studio] name.mp4" "$result" "bracket: leading whitespace trimmed"
}

test_bracket_trailing_space_before_extension_trimmed() {
    assert_equals "[Foo] bar.mkv" "$(cleanup_filename "foo bar .mkv")" "cleanup: space before extension removed"
    assert_equals "[Asd].mp4" "$(cleanup_filename "asd  .mp4")" "cleanup: several spaces before extension removed"
    assert_equals "[A] b.mp4" "$(cleanup_filename "[A] b .mp4")" "cleanup: already-bracketed name loses the space too"
}

test_cleanup_bracket_only_name_keeps_extension_attached() {
    local result
    result=$(cleanup_filename "[Studio].mp4")
    assert_equals "[Studio].mp4" "$result" "cleanup: no space before extension"
}

test_spacing_not_added_before_extension() {
    local result
    result=$(fix_bracket_spacing "[Studio].mp4")
    assert_equals "[Studio].mp4" "$result" "spacing: ] directly before extension unchanged"
}

# ── naming patterns ───────────────────────────────────────────────────────────

test_pattern_title_case() {
    assert_equals "My Show S01e01.mp4" "$(title_case_filename "my_show.s01e01.mp4")" "title-case: separators become spaces"
    assert_equals "Café Au Lait.mkv" "$(title_case_filename "CAFÉ AU LAIT.mkv")" "title-case: accents and caps"
}

test_pattern_snake_case() {
    assert_equals "my_show_01.mp4" "$(snake_case_filename "My Show - 01.mp4")" "snake_case: punctuation collapses"
    assert_equals "a_b.mkv" "$(snake_case_filename "[A] (b).mkv")" "snake_case: brackets trimmed"
}

test_pattern_strip_junk() {
    assert_equals "Show Name.mkv" "$(strip_junk_filename "Show.Name.1080p.WEB-DL.x264.mkv")" "strip-junk: dotted release name"
    assert_equals "Show Name 2020.mp4" "$(strip_junk_filename "Show Name [1080p] (HEVC) 2020.mp4")" "strip-junk: bracketed tags, year kept"
    assert_equals "Movie.mp4" "$(strip_junk_filename "Movie.DDP5.1.mp4")" "strip-junk: audio layout tag removed"
}

test_pattern_keeps_name_when_everything_is_junk() {
    assert_equals "1080p.mp4" "$(strip_junk_filename "1080p.mp4")" "strip-junk: never produces an empty name"
}

test_pattern_leading_dot_is_not_an_extension() {
    assert_equals "hidden" "$(snake_case_filename ".hidden")" "snake_case: leading dot is not split off as an extension"
}

test_pattern_lookup() {
    assert_equals "cleanup_filename" "$(rename_transform_for_pattern bracket)" "pattern: bracket maps to cleanup_filename"
    rename_transform_for_pattern nonsense >/dev/null
    assert_not_equals "0" "$?" "pattern: unknown name rejected"
}

# ── date formatting ───────────────────────────────────────────────────────────

test_dates_year_first_formats() {
    assert_equals "Show 05.03.2024.mp4" "$(normalize_dates_filename "Show 2024-03-05.mp4")" "dates: yyyy-mm-dd"
    assert_equals "Show 05.03.2024.mp4" "$(normalize_dates_filename "Show 2024.03.05.mp4")" "dates: yyyy.mm.dd"
    assert_equals "Show_05.03.2024.mp4" "$(normalize_dates_filename "Show_20240305.mp4")" "dates: yyyymmdd, surrounding text untouched"
}

test_dates_day_first_formats() {
    assert_equals "Show 05.03.2024.mp4" "$(normalize_dates_filename "Show 05-03-2024.mp4")" "dates: dd-mm-yyyy"
    assert_equals "Show 05.03.2024.mp4" "$(normalize_dates_filename "Show 05_03_2024.mp4")" "dates: dd_mm_yyyy"
}

test_dates_already_correct_is_unchanged() {
    assert_equals "Show 05.03.2024.mp4" "$(normalize_dates_filename "Show 05.03.2024.mp4")" "dates: dd.mm.yyyy is idempotent"
}

test_dates_impossible_or_unrelated_numbers_left_alone() {
    assert_equals "Show 2024-13-45.mp4" "$(normalize_dates_filename "Show 2024-13-45.mp4")" "dates: month 13 untouched"
    assert_equals "Show 1920x1080 v2.mp4" "$(normalize_dates_filename "Show 1920x1080 v2.mp4")" "dates: resolution untouched"
    assert_equals "Show 123456789.mp4" "$(normalize_dates_filename "Show 123456789.mp4")" "dates: long number untouched"
}

test_dates_several_in_one_name() {
    assert_equals "A 01.02.2023 to 05.03.2024.mp4" "$(normalize_dates_filename "A 2023-02-01 to 2024-03-05.mp4")" "dates: every date in the name"
}

test_dates_combine_with_pattern() {
    NORMALIZE_DATES=true
    local base="$(snake_case_filename "My Show 2024-03-05.mp4")"
    assert_equals "my_show_2024_03_05.mp4" "$base" "dates: snake_case writes the date with underscores"
    assert_equals "my_show_05.03.2024.mp4" "$(normalize_dates_filename "$base")" "dates: normalized after the pattern"
    unset NORMALIZE_DATES
}

test_dates_two_digit_year_to_yy_mm_dd() {
    DATE_FORMAT=yy.mm.dd
    assert_equals "[Deeper] 26.10.22 Leana.mp4" "$(normalize_dates_filename "[Deeper] 26 10 22 Leana.mp4")" "dates: yy mm dd with spaces"
    assert_equals "[Tushy] 26.11.01 Rissa.mp4" "$(normalize_dates_filename "[Tushy] 26.11.01 Rissa.mp4")" "dates: yy.mm.dd is idempotent"
    assert_equals "[Nubiles] 26.11.04.nellie.mp4" "$(normalize_dates_filename "[Nubiles] 26.11.04.nellie.mp4")" "dates: date followed by a dot"
    assert_equals "Show 26.03.05.mp4" "$(normalize_dates_filename "Show 2026-03-05.mp4")" "dates: yyyy-mm-dd to yy.mm.dd"
    assert_equals "Show 15.08.26 x.mp4" "$(normalize_dates_filename "Show 08.26.2015 x.mp4")" "dates: mm.dd.yyyy (month over 12) to yy.mm.dd"
    assert_equals "Show 15.03.04.mp4" "$(normalize_dates_filename "Show 04-03-2015.mp4")" "dates: dd-mm-yyyy still read day first"
    unset DATE_FORMAT
}

test_dates_other_target_formats() {
    DATE_FORMAT=yyyy-mm-dd
    assert_equals "Show 2026-11-03.mp4" "$(normalize_dates_filename "Show 26 11 03.mp4")" "dates: yy mm dd to yyyy-mm-dd"
    DATE_FORMAT=dd.mm.yyyy
    assert_equals "Show 03.11.2026.mp4" "$(normalize_dates_filename "Show 26 11 03.mp4")" "dates: yy mm dd to dd.mm.yyyy"
    unset DATE_FORMAT
}

test_dates_two_digit_leaves_unrelated_numbers() {
    DATE_FORMAT=yy.mm.dd
    assert_equals "Show 99 11 03.mp4" "$(normalize_dates_filename "Show 99 11 03.mp4")" "dates: year over 39 untouched"
    assert_equals "Show 26 13 03.mp4" "$(normalize_dates_filename "Show 26 13 03.mp4")" "dates: month 13 untouched"
    assert_equals "Show 5.1 audio.mp4" "$(normalize_dates_filename "Show 5.1 audio.mp4")" "dates: 5.1 untouched"
    unset DATE_FORMAT
}

test_dates_first_moves_date_after_tag() {
    DATE_FORMAT=yy.mm.dd DATE_FIRST=true
    assert_equals "[AnalMom] 26.10.31 Rebel Rhyder You Can Have My Ass.mp4" "$(normalize_dates_filename "[AnalMom] Rebel Rhyder You Can Have My Ass (26.10.31).mp4")" "date-first: parenthesised date at the end"
    assert_equals "[Ali] 25.09.03 Jones Jonesing For Ali_480p.mp4" "$(normalize_dates_filename "[Ali] Jones Jonesing For Ali (03.09.2025)_480p.mp4")" "date-first: converts, then moves"
    assert_equals "[Tushy] 26.11.01 Rissa May.mp4" "$(normalize_dates_filename "[Tushy] 26.11.01 Rissa May.mp4")" "date-first: already in place"
    assert_equals "[ALSScan] 26.01.12.Alicia.Williams.mp4" "$(normalize_dates_filename "[ALSScan] 26.01.12.Alicia.Williams.mp4")" "date-first: dotted name untouched"
    assert_equals "[AdultTime] Millie Morgan.mp4" "$(normalize_dates_filename "[AdultTime] Millie Morgan.mp4")" "date-first: no date, unchanged"
    assert_equals "Show Title (26.10.31).mp4" "$(normalize_dates_filename "Show Title (26.10.31).mp4")" "date-first: no leading tag, unchanged"
    unset DATE_FORMAT DATE_FIRST
}

# ── tidy ──────────────────────────────────────────────────────────────────────

test_tidy_studio_spelling() {
    load_studio_aliases
    assert_equals "[5KPorn] 26.01.21 Julia.mp4" "$(tidy_filename "[5kporn] 26.01.21 Julia.mp4")" "tidy: alias to canonical"
    assert_equals "[ALSScan] 22.05.19 Vanna.mp4" "$(tidy_filename "[ALSScan.com] 22.05.19 Vanna.mp4")" "tidy: .com alias"
    assert_equals "[Unknownstudio] Title.mp4" "$(tidy_filename "[Unknownstudio] Title.mp4")" "tidy: unknown studio untouched"
}

test_tidy_studio_user_file() {
    local f; f=$(mktemp)
    printf '# mine\nmystudio = MyStudio\n' > "$f"
    STUDIO_ALIASES_FILE="$f" load_studio_aliases
    assert_equals "[MyStudio] x.mp4" "$(tidy_filename "[mystudio] x.mp4")" "tidy: user alias file"
    rm -f "$f"; load_studio_aliases
}

test_tidy_dotted_names() {
    load_studio_aliases
    assert_equals "[Nubiles] 26.11.04 Nellie Pull My Hair.mp4" "$(tidy_filename "[Nubiles] 26.11.04.nellie.pull.my.hair.480p.mp4")" "tidy: dotted slug to words, junk dropped"
    assert_equals "[Amatrices] Sans Retenue Vol2.mp4" "$(tidy_filename "[Amatrices] -sans-retenue-vol2-1080p.mp4")" "tidy: dashed slug, leading dash"
}

test_tidy_junk_and_stray_characters() {
    load_studio_aliases
    assert_equals "[Ali] 25.09.03 Jones.mp4" "$(tidy_filename "[Ali] 25.09.03 Jones_480p.mp4")" "tidy: underscore junk"
    assert_equals "[X] Vanna Treat.mp4" "$(tidy_filename "[X] Vanna Treat(2160p).mp4")" "tidy: junk in parentheses"
    assert_equals "[X] Cadey 17.08.09.mp4" "$(tidy_filename "[X] Cadey 17.08.09 rq_340621a3.mp4")" "tidy: rq and hash id"
    assert_equals "[ArgentinaCasting] Martina, 18.mp4" "$(tidy_filename "[ArgentinaCasting] – Martina – 2923 – Martina, 18.mp4")" "tidy: en dashes and repeated name"
    assert_equals "[1].mp4" "$(tidy_filename "[1].mp4")" "tidy: placeholder untouched"
}

# ── remove_dashes ────────────────────────────────────────────────────────────

test_remove_dashes_basic() {
    local result
    result=$(remove_dashes "file - name.mp4")
    assert_equals "file name.mp4" "$result" "dashes: ' - ' replaced with ' '"
}

test_remove_dashes_no_dashes() {
    local result
    result=$(remove_dashes "nodash.mp4")
    assert_equals "nodash.mp4" "$result" "dashes: unchanged when no ' - '"
}

test_remove_dashes_multiple() {
    local result
    result=$(remove_dashes "a - b - c.mp4")
    assert_equals "a b c.mp4" "$result" "dashes: multiple ' - ' removed"
}

test_remove_dashes_hyphen_in_word_unchanged() {
    local result
    result=$(remove_dashes "well-known.mp4")
    assert_equals "well-known.mp4" "$result" "dashes: hyphen-in-word not removed (no spaces)"
}

test_remove_dashes_empty_string() {
    local result
    result=$(remove_dashes "")
    assert_equals "" "$result" "dashes: empty string stays empty"
}

# ── fix_bracket_spacing ───────────────────────────────────────────────────────

test_spacing_missing_space_after_bracket() {
    local result
    result=$(fix_bracket_spacing "[Studio]name.mp4")
    assert_equals "[Studio] name.mp4" "$result" "spacing: adds space after ]"
}

test_spacing_already_correct() {
    local result
    result=$(fix_bracket_spacing "[Studio] name.mp4")
    assert_equals "[Studio] name.mp4" "$result" "spacing: unchanged when correct"
}

test_spacing_no_brackets() {
    local result
    result=$(fix_bracket_spacing "filename.mp4")
    assert_equals "filename.mp4" "$result" "spacing: unchanged when no brackets"
}

test_spacing_multiple_brackets() {
    local result
    result=$(fix_bracket_spacing "[A]B [C]D.mp4")
    assert_equals "[A] B [C] D.mp4" "$result" "spacing: multiple bracket fixes"
}

# ── cleanup_filename (full pipeline) ─────────────────────────────────────────

test_cleanup_full_pipeline() {
    local result
    result=$(cleanup_filename "studio - rest.mp4")
    # After remove_dashes: "studio rest.mp4"
    # After apply_bracket_notation: "[Studio] rest.mp4"
    # After fix_bracket_spacing: "[Studio] rest.mp4"
    assert_equals "[Studio] rest.mp4" "$result" "cleanup: full pipeline"
}

test_cleanup_no_change_needed() {
    local result
    # Already in bracket notation with no dashes
    result=$(cleanup_filename "[Studio] rest.mp4")
    assert_equals "[Studio] rest.mp4" "$result" "cleanup: no change when already clean"
}

test_cleanup_preserves_extension() {
    local result
    result=$(cleanup_filename "studio name.mkv")
    assert_contains ".mkv" "$result" "cleanup: extension preserved"
}

test_rename_options_summary_and_preview() {
    RENAME_PATTERN=bracket NORMALIZE_DATES=false DATE_FORMAT=dd.mm.yyyy DATE_FIRST=false TIDY_NAMES=false
    assert_equals "bracket" "$(rename_options_summary)" "options summary: defaults"
    NORMALIZE_DATES=true DATE_FORMAT=yy.mm.dd DATE_FIRST=true TIDY_NAMES=true
    assert_equals "bracket, yy.mm.dd, date first, tidy" "$(rename_options_summary)" "options summary: everything on"
    assert_equals "[5KPorn] 26.01.21 Julia Cute.mp4" "$(rename_preview_name "5kporn Julia Cute (21.01.2026) 1080p rq.mp4")" "preview: runs the whole pipeline"
    RENAME_PATTERN=bracket NORMALIZE_DATES=false DATE_FORMAT=dd.mm.yyyy DATE_FIRST=false TIDY_NAMES=false
}
