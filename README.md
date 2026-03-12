# VoiceDub — Your Voice, Always

> Record your natural voice while you're healthy. Use it when you're not.

VoiceDub is a web app that lets you build a library of your own voice recordings, then automatically plays them back during meetings or calls when you're sick — matched to what you want to say using AI.

---

## Quick Start

```bash
git clone https://github.com/rekanar/voicedub-app.git
cd voicedub-app
npm install
ANTHROPIC_API_KEY=sk-ant-your-key npm start
# Open http://localhost:3000 in Chrome
```

**→ Full setup guide & usage instructions: [SETUP.md](./SETUP.md)**

---

## How It Works

```
You speak / type  →  Claude AI finds the best match  →  Your recorded voice plays
```

1. **Record** common work phrases in your own voice (takes ~15 min)
2. **Join your meeting** — open VoiceDub, start listening
3. **Speak or type** what you want to say
4. Your **pre-recorded healthy voice** plays back automatically

---

## Features

| Tab | What it does |
|---|---|
| 🔊 **Live Dubbing** | Real-time speech recognition + AI phrase matching + audio playback |
| 🎤 **Record Voice** | Record phrases by category with live waveform preview |
| 📚 **Voice Library** | Browse, search, filter, and manage all recordings |
| 🤖 **AI Suggest** | Claude generates 3 contextual reply suggestions |

- **AI matching** via Claude Opus 4.6 — semantic, not keyword-based
- **TTS fallback** when no matching recording is found
- **Quick-add tags** for 15 common work phrases
- **Docker ready** with persistent recording volume support

---

## Requirements

- Node.js 20+
- Chrome or Edge (Web Speech API)
- Microphone
- [Anthropic API key](https://console.anthropic.com) (free tier works)

---

## Docker

```bash
docker build -t voicedub .
docker run -p 3000:3000 \
  -e ANTHROPIC_API_KEY=sk-ant-your-key \
  -v $(pwd)/recordings:/app/recordings \
  voicedub
```

---

## API

| Method | Path | Description |
|---|---|---|
| POST | `/api/phrases` | Save recorded phrase (multipart/form-data) |
| GET | `/api/phrases` | List all phrases |
| DELETE | `/api/phrases/:id` | Delete a phrase |
| POST | `/api/match` | AI-match spoken text to best phrase |
| POST | `/api/suggest` | Get 3 AI reply suggestions |

---

## Tech Stack

- **Backend:** Node.js + Express
- **AI:** Anthropic Claude Opus 4.6 (`@anthropic-ai/sdk`)
- **Frontend:** Vanilla JS + Web Speech API + Canvas API
- **Audio:** MediaRecorder API (WebM format)

---

## License

MIT
