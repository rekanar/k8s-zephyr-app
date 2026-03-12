# VoiceDub — Setup & User Guide

## What is VoiceDub?

VoiceDub lets you **record your natural voice** while you're healthy, then **play those recordings back** when you're unwell, using speech recognition and AI to automatically match what you want to say to your saved recordings.

> **Use case:** You have an important meeting but you're sick and your voice is gone. Open VoiceDub, speak or type what you want to say, and your own pre-recorded healthy voice plays instead.

---

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Running the App](#running-the-app)
5. [Docker Setup](#docker-setup)
6. [How to Use — Step by Step](#how-to-use--step-by-step)
   - [Step 1: Record Your Voice (Do This While Healthy)](#step-1-record-your-voice-do-this-while-healthy)
   - [Step 2: Use Live Dubbing (When You're Unwell)](#step-2-use-live-dubbing-when-youre-unwell)
   - [Step 3: Browse Your Voice Library](#step-3-browse-your-voice-library)
   - [Step 4: Get AI Reply Suggestions](#step-4-get-ai-reply-suggestions)
7. [Use Cases & Scenarios](#use-cases--scenarios)
8. [Tips & Best Practices](#tips--best-practices)
9. [Troubleshooting](#troubleshooting)
10. [API Reference](#api-reference)

---

## Requirements

| Requirement | Details |
|---|---|
| **Node.js** | v20 or newer |
| **Browser** | Chrome or Edge (required for microphone + Web Speech API) |
| **Microphone** | For recording and live speech recognition |
| **Anthropic API key** | Free tier works — get one at [console.anthropic.com](https://console.anthropic.com) |

---

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/rekanar/voicedub-app.git
cd voicedub-app

# 2. Install dependencies
npm install
```

---

## Configuration

Create a `.env` file in the project root (or set the environment variable directly):

```bash
# .env
ANTHROPIC_API_KEY=sk-ant-your-key-here
PORT=3000   # optional, defaults to 3000
```

**Getting an Anthropic API key:**
1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Sign in / create an account
3. Navigate to **API Keys** → **Create Key**
4. Copy the key and paste it into your `.env` file

---

## Running the App

```bash
# Standard start
npm start

# Development mode (auto-restarts on file changes)
npm run dev

# With environment variable inline
ANTHROPIC_API_KEY=sk-ant-your-key-here npm start
```

Open your browser at: **http://localhost:3000**

> **Important:** Use Chrome or Edge. Firefox does not fully support the Web Speech API used for live voice recognition.

---

## Docker Setup

```bash
# Build the image
docker build -t voicedub .

# Run (recordings are saved inside container by default)
docker run -p 3000:3000 -e ANTHROPIC_API_KEY=sk-ant-your-key voicedub

# Run with persistent recordings (recommended)
docker run -p 3000:3000 \
  -e ANTHROPIC_API_KEY=sk-ant-your-key \
  -v $(pwd)/recordings:/app/recordings \
  voicedub
```

---

## How to Use — Step by Step

### Step 1: Record Your Voice (Do This While Healthy)

**Goal:** Build a library of your natural, healthy voice recordings.

1. Click the **"Record Voice"** tab
2. In the **"Phrase / Label"** field, type what you're about to say
   *(e.g. "Yes, I agree with that")*
3. Choose a **Category** from the dropdown
   *(Greetings, Meetings, Agreements, Questions, Responses, Closings)*
4. **Quick shortcut:** Click any **quick-add tag** to auto-fill common work phrases
5. Click the red **⏺ Record** button — allow microphone access if prompted
6. **Speak the phrase clearly** into your microphone
7. Click **⏹ Stop** when done (recording auto-stops at 30 seconds)
8. Click **▶ Preview** to hear your recording
9. If satisfied, click **💾 Save to Voice Library**
10. Repeat for all the phrases you might need

**Recommended phrases to record in advance:**
- Greetings: *"Good morning everyone"*, *"Hi, nice to meet you"*
- Agreements: *"Yes, I agree"*, *"That sounds good to me"*, *"No problem at all"*
- Responses: *"I'll look into that and get back to you"*, *"Let me check on that"*
- Questions: *"Can you repeat that please?"*, *"Could you send me an email?"*
- Work: *"I'm sorry, I'm not feeling well today"*, *"I'll follow up with you later"*
- Closings: *"Thank you for your patience"*, *"Talk to you soon"*

---

### Step 2: Use Live Dubbing (When You're Unwell)

**Goal:** Speak or type what you want to say — your saved voice plays automatically.

**Option A — Microphone (speech recognition):**
1. Click the **"Live Dubbing"** tab
2. Click **🎙️ Start Listening**
3. Grant microphone permission if prompted
4. **Speak naturally** — your words appear in the text box in real time
5. Click **"Find & Play My Voice"**
6. If a match is found → your pre-recorded voice plays automatically
7. If no match → a TTS fallback speaks the text for you
8. Click **⏹ Stop** when done

**Option B — Typing:**
1. Click the **"Live Dubbing"** tab
2. Click inside the **"Recognized Speech"** text box
3. **Type what you want to say**
4. Click **"Find & Play My Voice"**

**How matching works:**
- Claude AI reads your text and finds the most semantically similar phrase in your library
- Example: you say *"yeah that works"* → it matches *"Yes, I agree with that"* (your recording)
- Confidence score is shown (e.g. *"87% match"*)
- If confidence is below 50%, it falls back to text-to-speech

---

### Step 3: Browse Your Voice Library

**Goal:** Manage all your recordings.

1. Click the **"Voice Library"** tab
2. **Search** by typing keywords in the search box
3. **Filter** by category using the dropdown
4. Click **▶** on any card to play a recording
5. Click **"Use Now"** to instantly play a phrase in the Live Dubbing tab
6. Click **"Delete"** to remove a recording you no longer need

---

### Step 4: Get AI Reply Suggestions

**Goal:** When you're unsure what to say, let Claude suggest appropriate responses.

1. Click the **"AI Suggest"** tab
2. In **"What was said to you?"**, paste or type what someone said
   *(e.g. "Can you join the 3pm standup? We need your input on the timeline.")*
3. Set the **Situation** *(default: "professional work meeting")*
4. Click **🤖 Get AI Suggestions**
5. Claude returns 3 short, professional response options
6. For each suggestion:
   - Click **🔈 Speak** → plays via text-to-speech immediately
   - Click **🎤 Record** → jumps to the Record tab with the text pre-filled so you can record it in your own voice

---

## Use Cases & Scenarios

### Scenario 1: Sick day, important standup meeting
> You have laryngitis but can't miss the morning standup.

1. Open VoiceDub in Chrome on your laptop
2. Join the video call, mute your actual mic
3. Use **AI Suggest** → paste what was discussed → get 3 reply options
4. Click **🔈 Speak** to play TTS, or switch to **Live Dubbing** if you recorded phrases in advance
5. Type short answers in the text box → your pre-recorded voice plays

### Scenario 2: Client call with voice fatigue
> You've been on calls all day and your voice is strained.

1. In the **Voice Library**, click **"Use Now"** on common phrases
2. They play instantly in the **Live Dubbing** tab
3. Use the text box for less common responses → TTS fallback

### Scenario 3: Building your voice library proactively
> You want to be prepared before you get sick.

1. Spend 15 minutes in the **Record Voice** tab
2. Record 20–30 phrases across all categories
3. Use the **quick-add tags** to fast-fill common phrases
4. Record a few personalized ones: your name, your team name, project names

### Scenario 4: Non-native speaker needing clear pronunciation
> You want a cleaner recording of your voice for professional calls.

1. Record each phrase multiple times
2. Preview all versions
3. Keep the best take, delete the rest from the Voice Library

---

## Tips & Best Practices

**Recording quality:**
- Record in a **quiet room** with minimal background noise
- Speak at your **normal conversational pace** — not too slow, not rushed
- Hold the microphone **6–12 inches** from your mouth
- Record phrases you **actually use** at work, in your natural style

**Voice library organization:**
- Use **categories** to group related phrases — makes browsing faster
- Be **specific with labels** — *"Yes, I'll attend the meeting"* is more useful than just *"Yes"*
- Record **variations** of the same idea: *"I agree"*, *"That works for me"*, *"Sounds good"*

**Live dubbing:**
- Keep the **text box short** — one sentence at a time works best
- The AI is **semantic**, not keyword-based — you don't need exact phrase matches
- If the mic keeps activating in meetings, use **Option B (typing)** instead

**AI suggestions:**
- Give Claude **full context** — paste the whole message/question you received
- Change the **Situation** field to match your context: *"client presentation"*, *"email reply"*, *"team chat"*

---

## Troubleshooting

| Problem | Solution |
|---|---|
| **Microphone not working** | Check browser permissions: Chrome → Settings → Privacy → Microphone → Allow localhost |
| **Speech not recognized** | Speak clearly, reduce background noise; Chrome works best |
| **No match found** | Your phrase library may be empty — go to Record Voice tab and add phrases first |
| **"AI Ready" badge shows error** | Check your `ANTHROPIC_API_KEY` in `.env`; restart the server |
| **Recordings lost after restart** | Mount a volume with Docker: `-v $(pwd)/recordings:/app/recordings` |
| **Port already in use** | Set `PORT=3001` in your `.env` file |
| **Audio doesn't play automatically** | Some browsers block autoplay — click the **▶ Play My Voice** button manually |

---

## API Reference

All endpoints accept/return JSON unless noted.

### `POST /api/phrases`
Save a recorded voice phrase.
- **Content-Type:** `multipart/form-data`
- **Body:** `audio` (file, .webm), `label` (string), `category` (string, optional)
- **Returns:** `{ success: true, phrase: { id, label, category, audioPath, createdAt } }`

### `GET /api/phrases`
List all saved phrases.
- **Returns:** `{ phrases: [...] }`

### `DELETE /api/phrases/:id`
Delete a phrase and its audio file.
- **Returns:** `{ success: true }`

### `POST /api/match`
AI-match spoken text to the best recorded phrase.
- **Body:** `{ spokenText: "what the user said" }`
- **Returns:** `{ match: phrase | null, confidence: 0–100, suggestion: "cleaned text" }`

### `POST /api/suggest`
Get 3 AI-generated reply suggestions.
- **Body:** `{ context: "what was said", situation: "optional context" }`
- **Returns:** `{ suggestions: ["reply1", "reply2", "reply3"] }`

### `GET /health`
Health check.
- **Returns:** `{ status: "ok" }`
