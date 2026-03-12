# VoiceDub — Voice Recognizer & Dubbing App

**Use your own voice for work, even when you're not feeling well.**

## What It Does

| Feature | Description |
|---|---|
| **Live Dubbing** | Speak (or type) — your saved recordings play back automatically |
| **Voice Recording** | Record yourself saying common work phrases while you're healthy |
| **AI Phrase Matching** | Claude AI finds the best recorded phrase for any recognized speech |
| **Voice Library** | Browse, play, and manage all your recorded phrases |
| **AI Suggestions** | Claude suggests smart replies based on context (what was said to you) |
| **TTS Fallback** | If no recording matches, Web Speech Synthesis speaks the text |

## How to Use

### Step 1 — Record your voice (when you're feeling well)
1. Go to **Record Voice** tab
2. Enter a phrase label (or click a quick-add tag)
3. Click **Record**, say the phrase, click **Stop**
4. Click **💾 Save to Voice Library**

### Step 2 — Use your voice (when you're unwell)
1. Go to **Live Dubbing** tab
2. Click **Start Listening** — speak and the app recognizes your words
3. Click **Find & Play My Voice** — Claude matches to your best recording
4. Your recorded voice plays back!

### AI Suggestions
- Go to **AI Suggest** tab
- Type what was said to you
- Claude generates 3 natural replies
- Click **🔈 Speak** for TTS or **🎤 Record** to record them in your voice

## Setup

```bash
cd src/voice-dubbing
npm install
export ANTHROPIC_API_KEY=your_key_here
npm start
# Open http://localhost:3000
```

## Docker

```bash
docker build -t voice-dubbing .
docker run -p 3000:3000 -e ANTHROPIC_API_KEY=your_key -v ./recordings:/app/recordings voice-dubbing
```

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/phrases` | Save a recorded voice phrase (multipart/form-data) |
| `GET` | `/api/phrases` | List all saved phrases |
| `DELETE` | `/api/phrases/:id` | Delete a phrase |
| `POST` | `/api/match` | AI-match spoken text to best recorded phrase |
| `POST` | `/api/suggest` | Get 3 AI-generated reply suggestions |
| `GET` | `/health` | Health check |

## Browser Requirements
- Chrome / Edge (for Web Speech API)
- Microphone access required for recording & live recognition
- Modern browser with MediaRecorder API support
