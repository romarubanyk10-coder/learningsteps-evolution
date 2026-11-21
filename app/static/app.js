// The browser talks ONLY to our own API (same address as this page).
// It never calls the AI model and never sees a key or a token.

const entriesList = document.getElementById("entries");
const entryCount = document.getElementById("entry-count");
const button = document.getElementById("summary-button");
const statusText = document.getElementById("status");
const summaryBox = document.getElementById("summary");

// textContent (not innerHTML): note text is shown as plain text, so a note
// containing <script> cannot run as code in the browser (no XSS).
function showEntries(entries) {
  entriesList.replaceChildren();
  for (const entry of entries) {
    const item = document.createElement("li");
    const date = (entry.created_at || "").slice(0, 10);
    item.textContent = `${date} — Work: ${entry.work} · Struggle: ${entry.struggle} · Next: ${entry.intention}`;
    entriesList.append(item);
  }
  entryCount.textContent = `(${entries.length})`;
}

async function loadEntries() {
  const response = await fetch("/entries");
  if (!response.ok) {
    statusText.textContent = "Could not load your notes.";
    return;
  }
  const data = await response.json();
  showEntries(data.entries);
}

async function summarize() {
  button.disabled = true;
  statusText.textContent = "The AI is reading your notes…";
  summaryBox.hidden = true;
  try {
    const response = await fetch("/entries/summary", { method: "POST" });
    const data = await response.json();
    if (!response.ok) {
      statusText.textContent = data.detail || "The summary is not available right now.";
      return;
    }
    summaryBox.textContent = data.summary;
    summaryBox.hidden = false;
    statusText.textContent = `Summary of your ${data.entries_used} newest notes.`;
  } catch {
    statusText.textContent = "The summary is not available right now.";
  } finally {
    button.disabled = false;
  }
}

button.addEventListener("click", summarize);
loadEntries();
