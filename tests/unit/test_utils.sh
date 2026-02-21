#!/usr/bin/env bash
# Unit tests for lib/utils.sh:
#   is_video_file, is_image_file, is_audio_file, get_media_type, get_safe_filename

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"

# ── is_video_file ─────────────────────────────────────────────────────────────

test_video_mp4() {
    assert_exits_zero "is_video_file 'movie.mp4'" "is_video: .mp4 recognised"
}

test_video_mkv() {
    assert_exits_zero "is_video_file 'movie.mkv'" "is_video: .mkv recognised"
}

test_video_avi() {
    assert_exits_zero "is_video_file 'movie.avi'" "is_video: .avi recognised"
}

test_video_mov() {
    assert_exits_zero "is_video_file 'clip.mov'" "is_video: .mov recognised"
}

test_video_webm() {
    assert_exits_zero "is_video_file 'clip.webm'" "is_video: .webm recognised"
}

test_video_uppercase_ext() {
    assert_exits_zero "is_video_file 'movie.MP4'" "is_video: uppercase .MP4 recognised"
}

test_video_mixed_case_ext() {
    assert_exits_zero "is_video_file 'movie.Mkv'" "is_video: mixed-case .Mkv recognised"
}

test_video_rejects_pdf() {
    assert_exits_nonzero "is_video_file 'doc.pdf'" "is_video: .pdf rejected"
}

test_video_rejects_jpg() {
    assert_exits_nonzero "is_video_file 'photo.jpg'" "is_video: .jpg rejected"
}

test_video_rejects_no_extension() {
    assert_exits_nonzero "is_video_file 'noextension'" "is_video: no extension rejected"
}

# ── is_image_file ─────────────────────────────────────────────────────────────

test_image_jpg() {
    assert_exits_zero "is_image_file 'photo.jpg'" "is_image: .jpg recognised"
}

test_image_jpeg() {
    assert_exits_zero "is_image_file 'photo.jpeg'" "is_image: .jpeg recognised"
}

test_image_png() {
    assert_exits_zero "is_image_file 'image.png'" "is_image: .png recognised"
}

test_image_webp() {
    assert_exits_zero "is_image_file 'image.webp'" "is_image: .webp recognised"
}

test_image_heic() {
    assert_exits_zero "is_image_file 'photo.heic'" "is_image: .heic recognised"
}

test_image_rejects_mp4() {
    assert_exits_nonzero "is_image_file 'movie.mp4'" "is_image: .mp4 rejected"
}

# ── is_audio_file ─────────────────────────────────────────────────────────────

test_audio_mp3() {
    assert_exits_zero "is_audio_file 'track.mp3'" "is_audio: .mp3 recognised"
}

test_audio_flac() {
    assert_exits_zero "is_audio_file 'track.flac'" "is_audio: .flac recognised"
}

test_audio_wav() {
    assert_exits_zero "is_audio_file 'track.wav'" "is_audio: .wav recognised"
}

test_audio_rejects_mp4() {
    assert_exits_nonzero "is_audio_file 'movie.mp4'" "is_audio: .mp4 rejected"
}

# ── get_media_type ────────────────────────────────────────────────────────────

test_media_type_video() {
    local result
    result=$(get_media_type "file.mp4")
    assert_equals "video" "$result" "media_type: mp4 → video"
}

test_media_type_image() {
    local result
    result=$(get_media_type "file.jpg")
    assert_equals "image" "$result" "media_type: jpg → image"
}

test_media_type_audio() {
    local result
    result=$(get_media_type "file.mp3")
    assert_equals "audio" "$result" "media_type: mp3 → audio"
}

test_media_type_unknown() {
    local result
    result=$(get_media_type "file.pdf")
    assert_equals "unknown" "$result" "media_type: pdf → unknown"
}

test_media_type_no_extension() {
    local result
    result=$(get_media_type "noext")
    assert_equals "unknown" "$result" "media_type: no extension → unknown"
}

# ── get_safe_filename ─────────────────────────────────────────────────────────

test_safe_filename_no_conflict() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    local result
    result=$(get_safe_filename "$tmpdir" "unique.mp4")
    assert_equals "unique.mp4" "$result" "safe_filename: no conflict → original name"
    rmdir "$tmpdir"
}

test_safe_filename_with_conflict() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    touch "$tmpdir/existing.mp4"
    local result
    result=$(get_safe_filename "$tmpdir" "existing.mp4")
    assert_equals "existing(1).mp4" "$result" "safe_filename: conflict → (1) suffix"
    rm -rf "$tmpdir"
}

test_safe_filename_multiple_conflicts() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    touch "$tmpdir/file.mp4" "$tmpdir/file(1).mp4"
    local result
    result=$(get_safe_filename "$tmpdir" "file.mp4")
    assert_equals "file(2).mp4" "$result" "safe_filename: two conflicts → (2) suffix"
    rm -rf "$tmpdir"
}

test_safe_filename_no_extension() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    touch "$tmpdir/noext"
    local result
    result=$(get_safe_filename "$tmpdir" "noext")
    assert_equals "noext(1)" "$result" "safe_filename: no-extension conflict → (1) suffix"
    rm -rf "$tmpdir"
}
