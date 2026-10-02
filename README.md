# LocalGuia

A local-first, self-hosted language acquisition platform built on **Comprehensible Input**, inspired by
Lenguia and LingQ. You read and listen to stories at your level, click any word for a contextual
explanation, and turn words into multimedia flashcards scheduled with **FSRS**. Words you are reviewing
are woven back into new AI-generated stories (**Organic SRS**), so review happens through reading.

Everything runs on your machine: SQLite for storage, Ollama (or any OpenAI-compatible endpoint) for the
LLM, faster-whisper for transcription, and Piper / Kokoro / Edge for speech.

```
┌──────────────────────────┐   /api/*, /media/*   ┌──────────────────────────────────────────────┐
│ Next.js 14 (App Router)  │ ───── rewrites ────▶ │ FastAPI (Python 3.11+)                         │
│ TypeScript · Tailwind    │                      │  routers/  system words stories flashcards    │
│ shadcn/ui · Zustand      │                      │            imports tutor speech analytics     │
│ :3000                    │                      │  services/ tokenizer (spaCy/MeCab/Jieba)       │
└──────────────────────────┘                      │            fsrs · llm · prompts · stories      │
                                                  │            tts · stt · alignment · importers   │
                                                  │            tutor · dictionary · jobs · worker  │
                                                  │  SQLite (WAL) + Alembic · data/media/          │
                                                  └───────┬──────────────┬───────────────┬────────┘
                                                          │              │               │
                                              Ollama / OpenAI-    faster-whisper   Edge / Piper /
                                              compatible LLM      (+ WhisperX)     Kokoro TTS
```

## Features

| Module | What you get |
|---|---|
| **A · Interactive reader** | Tokenization with lemma/POS/morphology (spaCy), Japanese furigana (fugashi/MeCab), Chinese pinyin (jieba + pypinyin). Words are colour-coded by status (blue = unseen, yellow = learning, pale = familiar/known, plain = mastered/ignored). Click a word for a popover with contextual translation, other meanings, grammar breakdown, sentence translation, pronunciation, a 1–4/Ignore status picker and one-click "Add to flashcards". Keyboard: `1`–`4`, `X`, `F`, `Esc`. "Finish" marks never-clicked words as Known (LingQ-style). |
| **Audio sync** | Sticky player with play/pause, scrubbing, 0.8×/1.0×/1.2×, word or sentence karaoke highlighting and auto-scroll. Double-click a word to jump the audio there. Works for generated narration, podcasts, uploads and embedded YouTube videos. |
| **B · Story engine** | Daily worker generates *N* stories/day from your interests. Custom generator modal with topic, optional grammar/vocab focus and level. **Organic SRS**: up to 10 words (due cards first, then "Learning" words) are injected with *"You MUST naturally incorporate these specific target words into the story context: [...]. Bold them in the output."*; the bold markers are stripped and the tokens are underlined in the reader. **Level calibrator**: strict per-CEFR allowed/forbidden grammar, vocabulary range and sentence length (`backend/app/services/prompts.py`). |
| **C · Flashcards** | Cards keep the context sentence and its translation, cached word + sentence audio, and an illustration (placeholder SVG or a local SD/Flux OpenAI-compatible image server). Four study modes: **Recognition**, **Recall** (type or speak), **Listening**, **Cloze** (`[...]`), plus Mixed. FSRS-5 scheduling with the 19 default weights, learning/relearning steps, interval previews on the rating buttons, configurable desired retention and new-cards-per-day. Card stability feeds back into the reader's word status. |
| **D · Importers** | Web articles (trafilatura), YouTube subtitles (youtube-transcript-api) synced to the embedded player, RSS podcasts and local audio files transcribed by faster-whisper with word timestamps (optional WhisperX refinement). Long jobs run in the background with progress. |
| **E · AI tutor** | Chat with a patient native-speaker persona constrained to your CEFR level, with role-play scenarios. Voice input (Web Speech API, falling back to local Whisper) and spoken replies (TTS). Each reply has a collapsible **Coach feedback** pane: what you wrote, the natural phrasing, and why. |
| **F · Dashboard** | Streak, words read, known/mastered counts, cards due, today's goal, vocabulary estimate vs CEFR benchmarks (A1 500 · A2 1000 · B1 2000 · B2 4000 · C1 8000), 30-day activity chart, and grammar checklists grouped by level and category (**314 Spanish items, 88 Dutch items**). |
| **G · Read & Listen** | **Read** holds all texts (daily, generated, from flashcards, articles, pasted). **Listen** holds YouTube videos, podcasts and audio uploads. These open in *listening mode*, with the text blurred until you reveal it. |
| **H · Speak & Write** | Output practice with tasks per level (built-in or AI-generated). **Write**: an editor, then AI correction with a word-level diff, explained corrections, a score and level estimate, "hear corrected version", and saving any correction as a flashcard. **Speak**: records audio with a live browser transcript (or server-side Whisper) and gives the same feedback plus playback of your recording. |
| **I · Stories from flashcards** | "Generate a text with my words" builds a new graded story around words you're still learning, due cards, or cards you select. |

**Offline demo:** `python -m app.demo.seed` (from `backend/`) loads a Dutch → English demo. It needs no AI:
every word has a pre-written dictionary entry, and on Windows the narration uses the built-in Dutch voice
with word timings.

## Quick start (native)

Prerequisites: Python 3.11+, Node 20+, and [Ollama](https://ollama.com) (or any OpenAI-compatible API).

```bash
ollama pull llama3.1:8b
```

Larger or more multilingual models (e.g. `qwen2.5:14b`, `gemma2:9b`, `mistral-nemo`) give noticeably better
stories and coach feedback. Pick one in **Settings**.

### 1. Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
pip install -r requirements-nlp.txt   # recommended: proper lemmas, furigana, pinyin
python -m spacy download es_core_news_sm   # one per language you study
pip install -r requirements-audio.txt # optional: podcast import + voice input (faster-whisper)
uvicorn app.main:app --reload --port 8000
```

On startup the server creates `backend/data/`, runs Alembic migrations, and starts the daily story worker.
API docs are at http://localhost:8000/docs.

### 2. Frontend

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:3000 and create your profile in **Settings**. The frontend proxies `/api` and `/media` to
`BACKEND_URL` (default `http://127.0.0.1:8000`).

## Quick start (Docker)

```bash
docker compose up --build
```

* The backend image includes the NLP tokenizers, spaCy models for es/fr/de/it/pt and faster-whisper. Use the
  build args in `docker-compose.yml` to slim it down.
* By default it talks to Ollama on the **host** (`host.docker.internal:11434`). To run Ollama in Docker too:
  set `LOCALGUIA_LLM_BASE_URL=http://ollama:11434/v1` and run `docker compose --profile ollama up --build`.
* Data lives in `./data` (SQLite + audio + images). Whisper models are cached in a named volume.
* NVIDIA GPU: add a `deploy.resources.reservations.devices` block to the backend service and set the Whisper
  device to `cuda` in Settings.

## Configuration

Most settings are edited in **Settings** in the UI and stored in SQLite (`app_settings`). Environment variables
(`backend/.env`, see `.env.example`) only provide defaults.

| Area | Options |
|---|---|
| LLM | Base URL, model, API key, temperature, JSON mode. Presets: Ollama, LM Studio, OpenAI, Anthropic (OpenAI-compatible endpoint), Groq. |
| TTS | `edge` (default; online neural voices with exact word timings), `piper` (fully offline; timings via Whisper alignment), `openai` (any `/audio/speech` server such as Kokoro-FastAPI), `none`. Per-language voice. |
| STT | Whisper model size, device (`auto`/`cpu`/`cuda`), compute type, optional WhisperX forced alignment. |
| Images | Placeholder SVG, OpenAI-compatible `/images/generations` server (local SD / Flux), or none. |
| Stories / SRS | Daily stories on/off and count, FSRS desired retention, new cards per day. |

**Fully offline setup:** Ollama + `tts_provider=piper` (install the [Piper](https://github.com/rhasspy/piper)
binary and download voices, e.g. `es_ES-davefx-medium.onnx`, then set the voices directory and voice name) +
faster-whisper. The only online dependency left is YouTube import.

## Data model

| Table | Notes |
|---|---|
| `language_profiles` | target/native language, CEFR level, interests (JSON), daily goal (words), active flag |
| `words` | `lemma`, `surface_form`, `language`, `status` (0 Ignored · 1 Learning · 2 Familiar · 3 Known · 4 Mastered), `last_seen`, `occurrences_count`, cached translation. Unique on (language, lemma). No row = unseen. |
| `flashcards` | `word_id`, front/back, context sentence + translation, notes, `audio_path`, `sentence_audio_path`, `image_path`, `srs_state` (JSON FSRS state: state, step, stability, difficulty, due, last_review, reps, lapses), indexed `due_at` |
| `review_logs` | every rating with mode and scheduled interval |
| `stories` | `content_raw`, `content_tokens` (JSON: text, lemma, pos, morph, is_punctuation, is_word, whitespace, sentence_index, reading, is_target), `audio_url`, `timestamps` (JSON: word, start_time, end_time, token_index), `target_level`, `source_type`, `read_status`, `injected_words` |
| `grammar_tags` | `code` (e.g. `es_present_subjunctive_regular_verbs`), title, description, category, `cefr_level`, `mastery_score` 0–1 |
| `study_logs` | per-day counters (words read, cards reviewed, …) powering streaks and charts |
| `conversations`, `chat_messages` | tutor history; assistant messages carry `corrections` for the preceding user message |
| `jobs`, `lookup_cache`, `app_settings` | background jobs, cached dictionary lookups, runtime settings |

Schema changes: edit `app/models.py`, then `alembic revision --autogenerate -m "..."` from `backend/`.

## How the pieces fit

* **Tokens round-trip exactly.** Every tokenizer backend emits `text + whitespace` that reconstructs the input,
  so paragraphs render faithfully with `white-space: pre-wrap`.
* **Alignment is character-based.** `services/alignment.py` aligns normalized character streams of tokens and timed
  words with `difflib`, so it tolerates tokenizer mismatches (Whisper "del" vs spaCy "de"+"el", CJK segmentation)
  and interpolates any gaps.
* **Story narration** uses Edge word-boundary events directly; other TTS providers are aligned by running Whisper
  over the rendered audio.
* **Word status ↔ FSRS.** After each review the word's status follows card stability (< 3 d Learning, < 21 d
  Familiar, < 90 d Known, else Mastered), so the reader's colours reflect what you have actually retained.

## Adding a language's grammar catalog

Create `backend/app/catalogs/grammar_<lang>.py` with a `CATALOG: dict[level, list[(category, title)]]` (see
`grammar_es.py`). It is seeded automatically when a profile for that language is created.

## Development

```bash
cd backend
pip install -r requirements-dev.txt
pytest          # FSRS, tokenizer, alignment, and an end-to-end API flow with a fake LLM
ruff check app tests && mypy app
```

```bash
cd frontend
npm run typecheck
npm run lint
```

## Known limitations

* The Spanish grammar catalog is the only one bundled (314 structures). Other languages work everywhere else,
  but their checklist is empty until you add a catalog.
* Edge TTS needs internet access, and networks that intercept TLS can break it. Switch to Piper or Kokoro for
  offline or locked-down machines.
* YouTube import depends on public subtitles and on YouTube not rate-limiting `youtube-transcript-api`. Videos
  play through the official embed, so playback itself needs internet.
* Small local models (≤ 8B) sometimes break the JSON contract for lookups and coach feedback. The backend falls
  back gracefully, but a stronger model gives much better results.
