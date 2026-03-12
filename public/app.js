const QUICK_PHRASES = [
  { label: "Yes, I agree with that", category: "Agreements" },
  { label: "Good morning everyone", category: "Greetings" },
  { label: "I'll look into that and get back to you", category: "Responses" },
  { label: "Can you repeat that please", category: "Questions" },
  { label: "That sounds good to me", category: "Agreements" },
  { label: "I understand, thank you", category: "Responses" },
  { label: "Let me check on that", category: "Responses" },
  { label: "I'll be there in a moment", category: "General" },
  { label: "Could you send me an email about this", category: "Questions" },
  { label: "I'm sorry, I'm not feeling well today", category: "General" },
  { label: "Thank you for your patience", category: "Closings" },
  { label: "I'll follow up with you later", category: "Closings" },
  { label: "Yes, I can do that", category: "Agreements" },
  { label: "No problem at all", category: "Responses" },
  { label: "That's a great idea", category: "Agreements" },
];

let mediaRecorder = null, recordedChunks = [], recordedBlob = null;
let recordingStream = null, recordTimerInterval = null, recordSeconds = 0;
let analyserNode = null, audioCtx = null;
let listenAnimFrame = null, recAnimFrame = null;
let recognition = null, isListening = false;

const $ = (id) => document.getElementById(id);
const micStatus = $("mic-status");
const recognizedText = $("recognized-text");
const matchResult = $("match-result");
const noMatch = $("no-match");

// Tab switching
document.querySelectorAll(".tab").forEach((tab) => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach((t) => t.classList.remove("active"));
    document.querySelectorAll(".tab-content").forEach((c) => c.classList.remove("active"));
    tab.classList.add("active");
    $(`tab-${tab.dataset.tab}`).classList.add("active");
    if (tab.dataset.tab === "library") loadLibrary();
  });
});

function showToast(msg, type = "") {
  const toast = $("toast");
  toast.textContent = msg;
  toast.className = `toast${type ? " " + type : ""}`;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => (toast.className = "toast hidden"), 3000);
}

function drawVisualizer(canvas, analyser, animRef, color = "#6366f1") {
  const ctx = canvas.getContext("2d");
  const bufLen = analyser.frequencyBinCount;
  const dataArr = new Uint8Array(bufLen);
  function draw() {
    animRef.id = requestAnimationFrame(draw);
    analyser.getByteFrequencyData(dataArr);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#0f172a";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    const barW = (canvas.width / bufLen) * 2.5;
    let x = 0;
    for (let i = 0; i < bufLen; i++) {
      const h = (dataArr[i] / 255) * canvas.height;
      const grad = ctx.createLinearGradient(0, canvas.height, 0, canvas.height - h);
      grad.addColorStop(0, color + "44");
      grad.addColorStop(1, color);
      ctx.fillStyle = grad;
      ctx.fillRect(x, canvas.height - h, barW - 1, h);
      x += barW;
    }
  }
  draw();
}

function stopVisualizer(animRef, canvas) {
  if (animRef && animRef.id) cancelAnimationFrame(animRef.id);
  if (canvas) canvas.getContext("2d").clearRect(0, 0, canvas.width, canvas.height);
}

function initRecognition() {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SR) { showToast("Speech recognition not supported. Use Chrome.", "error"); return null; }
  const r = new SR();
  r.continuous = true;
  r.interimResults = true;
  r.lang = "en-US";
  r.onresult = (event) => {
    let final = "";
    for (let i = event.resultIndex; i < event.results.length; i++) {
      if (event.results[i].isFinal) final += event.results[i][0].transcript + " ";
    }
    if (final) recognizedText.textContent += final;
  };
  r.onerror = (e) => { if (e.error !== "aborted") showToast("Mic error: " + e.error, "error"); };
  r.onend = () => { if (isListening) r.start(); };
  return r;
}

// Live Dubbing tab
$("btn-listen").addEventListener("click", async () => {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioCtx = new AudioContext();
    analyserNode = audioCtx.createAnalyser();
    analyserNode.fftSize = 256;
    audioCtx.createMediaStreamSource(stream).connect(analyserNode);
    listenAnimFrame = {};
    drawVisualizer($("visualizer"), analyserNode, listenAnimFrame, "#6366f1");
    recognition = initRecognition();
    if (recognition) { recognition.start(); isListening = true; }
    micStatus.textContent = "Mic On";
    micStatus.className = "badge badge-on";
    $("btn-listen").disabled = true;
    $("btn-stop-listen").disabled = false;
  } catch { showToast("Microphone access denied.", "error"); }
});

$("btn-stop-listen").addEventListener("click", () => {
  isListening = false;
  if (recognition) { recognition.stop(); recognition = null; }
  if (audioCtx) { audioCtx.close(); audioCtx = null; }
  stopVisualizer(listenAnimFrame, $("visualizer"));
  micStatus.textContent = "Mic Off";
  micStatus.className = "badge badge-off";
  $("btn-listen").disabled = false;
  $("btn-stop-listen").disabled = true;
});

$("btn-clear-text").addEventListener("click", () => {
  recognizedText.textContent = "";
  matchResult.classList.add("hidden");
  noMatch.classList.add("hidden");
});

$("btn-find-match").addEventListener("click", async () => {
  const text = recognizedText.textContent.trim();
  if (!text) { showToast("Nothing to match yet. Speak or type something.", "error"); return; }
  $("btn-find-match").disabled = true;
  $("btn-find-match").textContent = "Searching…";
  matchResult.classList.add("hidden");
  noMatch.classList.add("hidden");
  try {
    const res = await fetch("/api/match", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ spokenText: text }),
    });
    const data = await res.json();
    if (data.match) {
      $("match-label").textContent = `"${data.match.label}"`;
      $("match-confidence").textContent = `${data.confidence}% match`;
      $("match-audio").src = data.match.audioPath;
      matchResult.classList.remove("hidden");
      $("match-audio").play().catch(() => {});
    } else {
      $("tts-text").textContent = data.suggestion || text;
      noMatch.classList.remove("hidden");
    }
  } catch { showToast("Error — is the server running?", "error"); }
  finally {
    $("btn-find-match").disabled = false;
    $("btn-find-match").textContent = "Find & Play My Voice";
  }
});

$("btn-autoplay").addEventListener("click", () => $("match-audio").play());
$("btn-tts").addEventListener("click", () => {
  const text = recognizedText.textContent.trim();
  if (text) { const u = new SpeechSynthesisUtterance(text); u.rate = 0.95; speechSynthesis.speak(u); }
});

// Record tab — quick tags
const quickTagsEl = $("quick-tags");
QUICK_PHRASES.forEach((p) => {
  const tag = document.createElement("span");
  tag.className = "quick-tag";
  tag.textContent = p.label;
  tag.addEventListener("click", () => {
    $("phrase-label").value = p.label;
    $("phrase-category").value = p.category;
  });
  quickTagsEl.appendChild(tag);
});

$("btn-record").addEventListener("click", async () => {
  try {
    recordingStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    recordedChunks = [];
    recordedBlob = null;
    const recAudioCtx = new AudioContext();
    const recAnalyser = recAudioCtx.createAnalyser();
    recAnalyser.fftSize = 256;
    recAudioCtx.createMediaStreamSource(recordingStream).connect(recAnalyser);
    recAnimFrame = {};
    drawVisualizer($("rec-visualizer"), recAnalyser, recAnimFrame, "#ef4444");

    mediaRecorder = new MediaRecorder(recordingStream, { mimeType: "audio/webm" });
    mediaRecorder.ondataavailable = (e) => { if (e.data.size > 0) recordedChunks.push(e.data); };
    mediaRecorder.onstop = () => {
      recordedBlob = new Blob(recordedChunks, { type: "audio/webm" });
      const preview = $("preview-audio");
      preview.src = URL.createObjectURL(recordedBlob);
      preview.style.display = "block";
      $("btn-play-preview").disabled = false;
      $("btn-save-phrase").disabled = false;
      stopVisualizer(recAnimFrame, $("rec-visualizer"));
      recAudioCtx.close();
      clearInterval(recordTimerInterval);
      $("rec-timer").classList.add("hidden");
    };
    mediaRecorder.start(100);

    recordSeconds = 0;
    $("rec-seconds").textContent = "0";
    $("rec-timer").classList.remove("hidden");
    recordTimerInterval = setInterval(() => {
      $("rec-seconds").textContent = ++recordSeconds;
      if (recordSeconds >= 30) stopRecording();
    }, 1000);

    $("btn-record").disabled = true;
    $("btn-stop-rec").disabled = false;
    $("btn-play-preview").disabled = true;
    $("btn-save-phrase").disabled = true;
  } catch { showToast("Microphone access denied.", "error"); }
});

function stopRecording() {
  if (mediaRecorder && mediaRecorder.state !== "inactive") mediaRecorder.stop();
  if (recordingStream) recordingStream.getTracks().forEach((t) => t.stop());
  $("btn-record").disabled = false;
  $("btn-stop-rec").disabled = true;
}
$("btn-stop-rec").addEventListener("click", stopRecording);
$("btn-play-preview").addEventListener("click", () => $("preview-audio").play());

$("btn-save-phrase").addEventListener("click", async () => {
  const label = $("phrase-label").value.trim();
  if (!label) { showToast("Enter a phrase label first.", "error"); return; }
  if (!recordedBlob) { showToast("Record audio first.", "error"); return; }
  const formData = new FormData();
  formData.append("audio", recordedBlob, "recording.webm");
  formData.append("label", label);
  formData.append("category", $("phrase-category").value);
  $("btn-save-phrase").disabled = true;
  $("btn-save-phrase").textContent = "Saving…";
  try {
    const res = await fetch("/api/phrases", { method: "POST", body: formData });
    const data = await res.json();
    if (data.success) {
      showToast(`Saved: "${label}"`, "success");
      $("phrase-label").value = "";
      recordedBlob = null;
      $("preview-audio").src = "";
      $("preview-audio").style.display = "none";
      $("btn-play-preview").disabled = true;
    } else { showToast(data.error || "Save failed", "error"); }
  } catch { showToast("Server error.", "error"); }
  finally {
    $("btn-save-phrase").disabled = false;
    $("btn-save-phrase").textContent = "💾 Save to Voice Library";
  }
});

// Library tab
async function loadLibrary() {
  try {
    const res = await fetch("/api/phrases");
    const data = await res.json();
    renderLibrary(data.phrases);
  } catch { showToast("Could not load library.", "error"); }
}

function renderLibrary(phrases) {
  const grid = $("phrase-grid");
  const searchVal = $("library-search").value.toLowerCase();
  const filterVal = $("library-filter").value;
  const filtered = phrases.filter((p) =>
    (!searchVal || p.label.toLowerCase().includes(searchVal)) &&
    (!filterVal || p.category === filterVal)
  );
  grid.innerHTML = "";
  $("library-empty").classList.toggle("hidden", filtered.length > 0);
  filtered.forEach((p) => {
    const card = document.createElement("div");
    card.className = "phrase-card";
    card.innerHTML = `
      <div class="phrase-card-header">
        <span class="phrase-card-label">${esc(p.label)}</span>
        <span class="phrase-card-category">${esc(p.category)}</span>
      </div>
      <audio class="phrase-card-audio" controls src="${p.audioPath}"></audio>
      <div class="phrase-card-actions">
        <button class="btn btn-sm btn-primary" onclick="useInDubbing('${p.id}','${escA(p.label)}','${p.audioPath}')">Use Now</button>
        <button class="btn btn-sm btn-danger" onclick="deletePhrase('${p.id}')">Delete</button>
      </div>`;
    grid.appendChild(card);
  });
}

window.useInDubbing = (id, label, audioPath) => {
  document.querySelector('[data-tab="dubbing"]').click();
  recognizedText.textContent = label;
  $("match-label").textContent = `"${label}"`;
  $("match-confidence").textContent = "Manual select";
  $("match-audio").src = audioPath;
  matchResult.classList.remove("hidden");
  noMatch.classList.add("hidden");
  $("match-audio").play().catch(() => {});
};

window.deletePhrase = async (id) => {
  if (!confirm("Delete this recording?")) return;
  try { await fetch(`/api/phrases/${id}`, { method: "DELETE" }); showToast("Deleted", "success"); loadLibrary(); }
  catch { showToast("Delete failed", "error"); }
};

$("btn-refresh-library").addEventListener("click", loadLibrary);
$("library-search").addEventListener("input", async () => { const d = await (await fetch("/api/phrases")).json(); renderLibrary(d.phrases); });
$("library-filter").addEventListener("change", async () => { const d = await (await fetch("/api/phrases")).json(); renderLibrary(d.phrases); });

// AI Suggest tab
$("btn-get-suggestions").addEventListener("click", async () => {
  const context = $("suggest-context").value.trim();
  if (!context) { showToast("Enter what was said to you.", "error"); return; }
  $("btn-get-suggestions").disabled = true;
  $("suggestions-loading").classList.remove("hidden");
  $("suggestions-list").innerHTML = "";
  try {
    const res = await fetch("/api/suggest", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ context, situation: $("suggest-situation").value.trim() }),
    });
    const data = await res.json();
    renderSuggestions(data.suggestions || []);
  } catch { showToast("AI suggestion failed.", "error"); }
  finally { $("btn-get-suggestions").disabled = false; $("suggestions-loading").classList.add("hidden"); }
});

function renderSuggestions(suggestions) {
  const list = $("suggestions-list");
  list.innerHTML = "";
  if (!suggestions.length) { list.innerHTML = '<p style="color:var(--muted)">No suggestions returned.</p>'; return; }
  suggestions.forEach((s) => {
    const item = document.createElement("div");
    item.className = "suggestion-item";
    item.innerHTML = `
      <span class="suggestion-text">${esc(s)}</span>
      <div class="suggestion-actions">
        <button class="btn btn-sm btn-secondary" onclick="speakTTS('${escA(s)}')">🔈 Speak</button>
        <button class="btn btn-sm btn-primary" onclick="useAsLabel('${escA(s)}')">🎤 Record</button>
      </div>`;
    list.appendChild(item);
  });
}

window.speakTTS = (text) => { const u = new SpeechSynthesisUtterance(text); u.rate = 0.95; speechSynthesis.speak(u); };
window.useAsLabel = (text) => { document.querySelector('[data-tab="record"]').click(); $("phrase-label").value = text; showToast("Label set — now record it!", "success"); };

function esc(s) { return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;"); }
function escA(s) { return String(s).replace(/'/g,"\\'"); }

loadLibrary();
