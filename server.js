import Anthropic from "@anthropic-ai/sdk";
import express from "express";
import multer from "multer";
import { v4 as uuidv4 } from "uuid";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = process.env.PORT || 3000;

// Storage for voice recordings (in-memory map: phraseId -> { label, audioPath })
const voiceLibrary = new Map();
const RECORDINGS_DIR = path.join(__dirname, "recordings");

if (!fs.existsSync(RECORDINGS_DIR)) {
  fs.mkdirSync(RECORDINGS_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: RECORDINGS_DIR,
  filename: (req, file, cb) => cb(null, `${uuidv4()}.webm`),
});
const upload = multer({ storage, limits: { fileSize: 10 * 1024 * 1024 } });

const claude = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));
app.use("/recordings", express.static(RECORDINGS_DIR));

// ── Save a recorded voice phrase ──────────────────────────────────────────────
app.post("/api/phrases", upload.single("audio"), (req, res) => {
  if (!req.file) return res.status(400).json({ error: "No audio file provided" });
  const { label, category } = req.body;
  if (!label) {
    fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: "Phrase label is required" });
  }
  const id = uuidv4();
  const entry = {
    id,
    label: label.trim(),
    category: category || "General",
    audioPath: `/recordings/${req.file.filename}`,
    createdAt: new Date().toISOString(),
  };
  voiceLibrary.set(id, entry);
  res.json({ success: true, phrase: entry });
});

// ── List all saved phrases ────────────────────────────────────────────────────
app.get("/api/phrases", (req, res) => {
  res.json({ phrases: Array.from(voiceLibrary.values()) });
});

// ── Delete a phrase ───────────────────────────────────────────────────────────
app.delete("/api/phrases/:id", (req, res) => {
  const entry = voiceLibrary.get(req.params.id);
  if (!entry) return res.status(404).json({ error: "Phrase not found" });
  const filePath = path.join(RECORDINGS_DIR, path.basename(entry.audioPath));
  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
  voiceLibrary.delete(req.params.id);
  res.json({ success: true });
});

// ── AI phrase matching ────────────────────────────────────────────────────────
app.post("/api/match", async (req, res) => {
  const { spokenText } = req.body;
  if (!spokenText) return res.status(400).json({ error: "spokenText is required" });

  const phrases = Array.from(voiceLibrary.values());
  if (phrases.length === 0) return res.json({ match: null, suggestion: spokenText });

  try {
    const phraseList = phrases
      .map((p) => `ID: ${p.id} | Label: "${p.label}" | Category: ${p.category}`)
      .join("\n");

    const stream = claude.messages.stream({
      model: "claude-opus-4-6",
      max_tokens: 512,
      thinking: { type: "adaptive" },
      messages: [{
        role: "user",
        content: `You are a voice assistant that matches spoken text to pre-recorded voice phrases.

The user spoke: "${spokenText}"

Available recorded phrases:
${phraseList}

Task:
1. Find the best matching phrase ID from the list above (semantic match, not just keyword).
2. If no phrase is a good match (similarity < 50%), return null for matchId.
3. Also suggest a short clean version of what was spoken (max 10 words) for display.

Respond ONLY with valid JSON, no extra text:
{"matchId": "<id or null>", "confidence": <0-100>, "suggestion": "<cleaned text>"}`,
      }],
    });

    const response = await stream.finalMessage();
    const textBlock = response.content.find((b) => b.type === "text");
    const jsonMatch = textBlock?.text?.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("No JSON in response");

    const result = JSON.parse(jsonMatch[0]);
    const matchedPhrase = result.matchId ? voiceLibrary.get(result.matchId) : null;
    res.json({ match: matchedPhrase ?? null, confidence: result.confidence ?? 0, suggestion: result.suggestion ?? spokenText });
  } catch (err) {
    console.error("Claude match error:", err.message);
    const lower = spokenText.toLowerCase();
    const match = phrases.find((p) => lower.includes(p.label.toLowerCase()));
    res.json({ match: match ?? null, confidence: match ? 60 : 0, suggestion: spokenText });
  }
});

// ── AI smart reply suggestions ────────────────────────────────────────────────
app.post("/api/suggest", async (req, res) => {
  const { context, situation } = req.body;
  if (!context) return res.status(400).json({ error: "context is required" });

  try {
    const stream = claude.messages.stream({
      model: "claude-opus-4-6",
      max_tokens: 256,
      messages: [{
        role: "user",
        content: `You are a voice assistant for someone who is unwell and using pre-recorded voice to communicate at work.

Context / what was just said to them: "${context}"
Situation: "${situation || "professional work meeting"}"

Suggest 3 short, natural responses they could say. Keep each under 12 words. Professional tone.

Respond ONLY as JSON array: ["response1", "response2", "response3"]`,
      }],
    });

    const response = await stream.finalMessage();
    const textBlock = response.content.find((b) => b.type === "text");
    const jsonMatch = textBlock?.text?.match(/\[[\s\S]*\]/);
    res.json({ suggestions: jsonMatch ? JSON.parse(jsonMatch[0]) : [] });
  } catch (err) {
    console.error("Claude suggest error:", err.message);
    res.json({ suggestions: ["I understand, let me check.", "Could you clarify that?", "I will get back to you."] });
  }
});

app.get("/health", (req, res) => res.json({ status: "ok" }));

app.listen(PORT, () => {
  console.log(`VoiceDub running at http://localhost:${PORT}`);
  console.log(`ANTHROPIC_API_KEY: ${process.env.ANTHROPIC_API_KEY ? "set" : "NOT SET"}`);
});
