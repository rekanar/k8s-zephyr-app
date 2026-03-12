# VoiceDub — Voice Recognizer & Dubbing App

**Use your own voice for work, even when you're not feeling well.**

## Features

| Feature | Description |
|---|---|
| **Live Dubbing** | Speak or type — your saved recordings play back automatically |
| **Voice Recording** | Record yourself saying common work phrases while healthy |
| **AI Phrase Matching** | Claude Opus 4.6 finds the best recorded phrase for any recognized speech |
| **Voice Library** | Browse, play, and manage all your recorded phrases |
| **AI Suggestions** | Claude suggests smart replies based on context |
| **TTS Fallback** | Web Speech Synthesis speaks text when no recording matches |

## Quick Start

```bash
npm install
ANTHROPIC_API_KEY=your_key npm start
# Open http://localhost:3000
```

## How to Use

1. **Record your voice** (when healthy) → Record Voice tab → say phrases → Save
2. **Use your voice** (when unwell) → Live Dubbing tab → speak/type → Find & Play My Voice
3. **Get AI help** → AI Suggest tab → enter what was said → Claude gives 3 replies

## Docker

```bash
docker build -t voicedub .
docker run -p 3000:3000 -e ANTHROPIC_API_KEY=your_key -v ./recordings:/app/recordings voicedub
```

## API

| Method | Path | Description |
|---|---|---|
| POST | `/api/phrases` | Save recorded phrase (multipart) |
| GET | `/api/phrases` | List all phrases |
| DELETE | `/api/phrases/:id` | Delete a phrase |
| POST | `/api/match` | AI-match spoken text to best phrase |
| POST | `/api/suggest` | Get 3 AI reply suggestions |

## Requirements

- Node.js 20+
- `ANTHROPIC_API_KEY` environment variable
- Chrome/Edge browser (Web Speech API)
- Microphone access
