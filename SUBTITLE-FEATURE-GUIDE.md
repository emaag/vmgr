# 🎬 Subtitle Generation Feature Guide

## Overview

The Video Manager Ultimate v1.1.0 now includes **AI-powered automatic subtitle generation** using OpenAI's Whisper speech-to-text technology.

## Features

### 🎯 Key Capabilities
- **Automatic Speech Recognition**: Converts speech in videos to text
- **Multiple Models**: Choose between speed and accuracy
- **Format Support**: SRT, VTT, TXT, JSON
- **Language Detection**: Auto-detect or manually specify language
- **Batch Processing**: Generate subtitles for entire collections
- **Smart Skip**: Automatically skips videos that already have subtitles

### 📊 Whisper Model Options

| Model  | Size  | Speed      | Accuracy | Best For                    |
|--------|-------|------------|----------|-----------------------------|
| tiny   | 75MB  | Very Fast  | Good     | Quick previews, testing     |
| base   | 142MB | Fast       | Better   | Balanced usage (default)    |
| small  | 466MB | Moderate   | Great    | Production use              |
| medium | 1.5GB | Slow       | Excellent| High-quality subtitles      |
| large  | 2.9GB | Very Slow  | Best     | Maximum accuracy needed     |

### 📝 Supported Formats

- **SRT** (SubRip) - Most widely supported subtitle format
- **VTT** (WebVTT) - Web-friendly subtitle format
- **TXT** - Plain text transcript
- **JSON** - Structured data with timestamps

## Installation

### Option 1: OpenAI Whisper (Python)

```bash
# Install with pip
pip install -U openai-whisper

# Verify installation
whisper --help
```

**Requirements:**
- Python 3.8+
- ffmpeg
- Sufficient RAM (varies by model)

### Option 2: whisper.cpp (C++ - Faster)

```bash
# Clone and build
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
make

# Add to PATH or create symlink
sudo ln -s $(pwd)/whisper.cpp /usr/local/bin/whisper.cpp

# Download models
bash ./models/download-ggml-model.sh base
```

**Advantages:**
- Faster processing
- Lower memory usage
- Better for large collections

## Usage

### Interactive Menu

1. Launch the script:
   ```bash
   ./video-manager-ultimate.sh
   ```

2. Select option `[5] Subtitle Generation`

3. Choose from:
   - Generate Subtitles (Single Directory)
   - Batch Generate Subtitles (Multiple Directories)
   - Configure Subtitle Settings
   - Check Whisper Installation

### Command Line

#### Basic Usage

```bash
# Generate subtitles for all videos in a directory
./video-manager-ultimate.sh subtitles /path/to/videos
```

#### With Custom Settings

```bash
# Use small model, SRT format, English language
./video-manager-ultimate.sh --model small --format srt --language en subtitles /path/to/videos
```

#### Dry Run (Preview)

```bash
# See what would happen without actually generating subtitles
./video-manager-ultimate.sh --dry-run subtitles /path/to/videos
```

### Examples

#### Example 1: Quick Processing
```bash
# Use tiny model for fast processing
./video-manager-ultimate.sh --model tiny subtitles ~/Videos
```

#### Example 2: High Quality
```bash
# Use medium model for better accuracy
./video-manager-ultimate.sh --model medium --format srt subtitles ~/Videos
```

#### Example 3: Specific Language
```bash
# Force Spanish language detection
./video-manager-ultimate.sh --language es subtitles ~/Spanish-Videos
```

#### Example 4: Multiple Formats
```bash
# Generate both SRT and VTT
./video-manager-ultimate.sh --format srt subtitles ~/Videos
./video-manager-ultimate.sh --format vtt subtitles ~/Videos
```

## Configuration

### Default Settings

The script uses these defaults (can be changed in interactive menu or via command line):

```bash
WHISPER_MODEL="base"        # Balanced speed/accuracy
SUBTITLE_FORMAT="srt"       # Most compatible format
SUBTITLE_LANGUAGE="auto"    # Automatic language detection
```

### Language Codes

Common language codes for `--language`:

- `en` - English
- `es` - Spanish
- `fr` - French
- `de` - German
- `it` - Italian
- `pt` - Portuguese
- `ru` - Russian
- `ja` - Japanese
- `zh` - Chinese
- `ko` - Korean
- `auto` - Automatic detection

## Performance Tips

### 🚀 Speed Optimization

1. **Use smaller models**: `tiny` or `base` for faster processing
2. **Use whisper.cpp**: C++ implementation is significantly faster
3. **Process in batches**: Process during off-hours for large collections
4. **GPU acceleration**: Install CUDA for GPU support (Python Whisper only)

### 💾 Storage Considerations

- SRT files are typically 10-50 KB per video
- Allow ~50 KB per hour of video content
- For 1000 hours of video: ~50 MB of subtitle files

### ⚡ Processing Time Estimates

**Using base model on typical hardware:**
- 1 hour video: 5-10 minutes
- 10 videos (10 hours total): 50-100 minutes
- 100 videos (100 hours total): 8-16 hours

**Using whisper.cpp (faster):**
- 1 hour video: 2-4 minutes
- 10 videos: 20-40 minutes
- 100 videos: 3-6 hours

## Troubleshooting

### Whisper Not Found

**Error:** "Whisper is not installed!"

**Solution:**
1. Install OpenAI Whisper: `pip install -U openai-whisper`
2. OR install whisper.cpp and ensure it's in your PATH
3. Check installation: `which whisper` or `which whisper.cpp`

### Out of Memory

**Error:** Process killed or memory errors

**Solution:**
1. Use a smaller model (`tiny` or `base`)
2. Close other applications
3. Process videos in smaller batches
4. Consider using whisper.cpp (lower memory usage)

### Subtitle Quality Issues

**Problem:** Inaccurate transcriptions

**Solutions:**
1. Use a larger model (`medium` or `large`)
2. Specify the correct language instead of `auto`
3. Ensure audio quality is good in source video
4. Try different Whisper implementations

### Permission Errors

**Error:** Cannot write subtitle file

**Solution:**
1. Check directory permissions: `ls -la /path/to/videos`
2. Ensure you have write access to the video directory
3. Try running with appropriate permissions

## Best Practices

### ✅ Recommended Workflow

1. **Test first**: Use `--dry-run` to preview operations
2. **Start small**: Test on a few videos before processing entire collection
3. **Choose appropriate model**:
   - `base` for most use cases
   - `small` for better quality
   - `tiny` only for testing
4. **Verify results**: Check a few generated subtitles for accuracy
5. **Backup**: Keep originals before bulk processing

### 📋 Quality Checklist

Before processing your entire collection:

- [ ] Whisper is correctly installed
- [ ] Tested on 2-3 sample videos
- [ ] Checked subtitle quality
- [ ] Selected appropriate model for your needs
- [ ] Set correct output format
- [ ] Verified language detection works
- [ ] Have sufficient disk space
- [ ] Confirmed processing time is acceptable

## Integration with Video Players

### VLC
- Automatically detects `.srt` files with same name as video
- Place subtitle file in same directory as video

### MPV
- Automatically loads subtitles
- Supports SRT, VTT, and other formats

### Plex/Jellyfin
- Place subtitle files alongside videos
- Named: `videoname.srt` or `videoname.en.srt`
- Will be automatically detected and offered to users

## Advanced Usage

### Custom Workflow Integration

```bash
#!/bin/bash
# Process new downloads automatically

DOWNLOAD_DIR="/mnt/c/Users/Eric/Downloads"
VIDEO_DIR="/mnt/c/Users/Eric/Videos"

# Move videos
mv $DOWNLOAD_DIR/*.mp4 $VIDEO_DIR/

# Rename and organize
./video-manager-ultimate.sh rename $VIDEO_DIR

# Generate subtitles
./video-manager-ultimate.sh --model base subtitles $VIDEO_DIR

# Find duplicates
./video-manager-ultimate.sh duplicates $VIDEO_DIR
```

### Cron Job for Scheduled Processing

```bash
# Add to crontab (crontab -e)
# Process videos every night at 2 AM
0 2 * * * /path/to/video-manager-ultimate.sh --model base subtitles /path/to/videos >> /var/log/subtitle-generation.log 2>&1
```

## FAQ

### Q: Do I need internet to generate subtitles?
A: No, once Whisper is installed and models are downloaded, it works completely offline.

### Q: Can I interrupt subtitle generation?
A: Yes, press Ctrl+C. Already generated subtitles will be preserved.

### Q: What if a video already has subtitles?
A: The script automatically skips videos that already have subtitle files.

### Q: Can I generate subtitles in multiple languages?
A: Whisper transcribes in the original language. For translation, you'd need a separate translation tool.

### Q: How accurate are the subtitles?
A: Accuracy depends on:
- Model size (larger = more accurate)
- Audio quality
- Speaker clarity
- Background noise
- Language complexity

### Q: Can I edit generated subtitles?
A: Yes! SRT files are plain text and can be edited with any text editor or subtitle editor like Subtitle Edit.

## Version History

### v1.1.0 (2025-11-02)
- ✨ Initial release of subtitle generation feature
- 🎯 Support for 5 Whisper models
- 📝 Support for 4 output formats
- 🌍 Language detection and manual selection
- 📊 Subtitle statistics tracking
- 🔧 Interactive configuration menu

## Support

For issues or questions:
1. Check troubleshooting section above
2. Verify Whisper installation
3. Test with sample video
4. Check logs in `~/.video-manager-logs/`

## Credits

- **Whisper AI**: OpenAI (https://github.com/openai/whisper)
- **whisper.cpp**: Georgi Gerganov (https://github.com/ggerganov/whisper.cpp)
- **Video Manager**: Created for Eric's Video Management System

---

**Happy subtitle generating! May your videos be perfectly captioned!** 🎬✨
