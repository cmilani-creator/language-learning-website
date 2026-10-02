# Rebuild prompt for Claude Code: "LocalGuia"

> **How to use this file.** Open Claude Code in an **empty folder with a short path** (for example
> `C:\dev\localguia`), paste everything below the line, and let it work phase by phase. After each phase,
> ask it to show you the test results and the running app before continuing. If a session gets long, start
> a new one and say "continue with Phase N of REBUILD_PROMPT.md" with this file in the folder.

---

You are a senior full-stack engineer. Build **LocalGuia**, a local-first, self-hosted language-learning web
app based on Comprehensible Input (inspired by LingQ and Lenguia). It must run entirely on the user's
machine. AI features call any **OpenAI-compatible API** (Ollama now, OpenAI/Anthropic/Groq later), and
**every AI feature must degrade gracefully** when no model is configured: show a clear "Connect an AI model
in Settings" message and never crash or hang.

Work in the phases at the end of this document. After each phase run the tests and linters, start the app,
and confirm the phase's acceptance criteria before moving on. Do not skip verification. When something can't
be verified (for example no AI model available), say so explicitly.

## 1. Target environment and hard-won constraints (read first)

The primary user is on **Windows 11 with Windows PowerShell 5.1**, behind a **corporate TLS-inspecting
proxy**, with a **network-redirected Documents folder**. All of the following actually caused failures in a
previous build. Design for them from the start:

1. **PowerShell 5.1 has no `&&` or `||`.** Never give the user bash-style chained commands. Provide
   `start-backend.ps1` and `start-frontend.ps1` scripts that work from any current directory (use
   `$PSScriptRoot`) and document `powershell -ExecutionPolicy Bypass -File <script>`.
2. **Windows MAX_PATH (260 chars).** Python wheels with compiled extensions (SQLAlchemy, pydantic-core)
   fail to load from deep paths with "DLL load failed … The filename or extension is too long". Put the
   Python venv at `%LOCALAPPDATA%\LocalGuia\venv`, not inside the project, and recommend a short project
   path.
3. **Corporate TLS interception.** pip works (it uses the OS trust store), but **npm fails with
   `UNABLE_TO_GET_ISSUER_CERT_LOCALLY`** and hangs retrying. Fix: set `NODE_OPTIONS=--use-system-ca`
   (Node ≥ 22.15 / 23.8) in `start-frontend.ps1` and in the VS Code launch config. Online TTS (edge-tts)
   also fails behind such proxies, so an **offline Windows TTS provider** is required (see 6.7).
4. **Slow PowerShell profiles** (modules on a UNC share). Always spawn helper PowerShell processes with
   `-NoProfile`.
5. **Node may not be installed.** `start-frontend.ps1` must detect a missing Node and print
   `winget install OpenJS.NodeJS.LTS` (then "open a new terminal"). It should also prepend
   `C:\Program Files\nodejs` to PATH if node.exe exists but the terminal predates the install.
6. **Never bulk-delete directories by generic names** such as `data` during cleanup. Keep bundled catalogs in
   `app/catalogs/` (not `app/data/`) so they can't be confused with the runtime data folder `backend/data/`.
7. Ollama's `/v1/models` returns `{"data": null}` when no model is pulled. Handle `null`, and report "server
   is up but has no models; run `ollama pull <model>`". For a local Ollama URL (`:11434`), also report when
   the configured model isn't pulled.
8. SQLite drops tzinfo. Use a `UTCDateTime` SQLAlchemy `TypeDecorator` that stores naive UTC and returns
   aware UTC. Never compare naive and aware datetimes.
9. In the browser, opening `http://localhost:8000/` shows 404; that's expected (API only). The app is on
   `:3000`. Say this in the README.

## 2. Tech stack

- **Backend:** Python 3.11+ (tested on 3.12), FastAPI, Uvicorn, SQLAlchemy 2.x (typed `Mapped[]` models),
  Alembic (migrations run automatically at startup), pydantic v2 + pydantic-settings, httpx, SQLite in
  **WAL mode** (`PRAGMA journal_mode=WAL; synchronous=NORMAL; foreign_keys=ON; busy_timeout=30000`).
- **Importers:** trafilatura (articles), youtube-transcript-api (support both the <1.0 static `get_transcript`
  and the ≥1.0 instance `.fetch()` APIs), feedparser (RSS).
- **Optional NLP** (`requirements-nlp.txt`): spaCy (+ `<lang>_core_news_sm` models), fugashi[unidic-lite]
  + cutlet (Japanese), jieba + pypinyin (Chinese).
- **Optional audio** (`requirements-audio.txt`): faster-whisper; whisperx (commented, optional).
- **TTS:** edge-tts (online, word timings), Piper (local binary), any OpenAI-compatible `/audio/speech`
  server (e.g. Kokoro-FastAPI), and **Windows OneCore voices via WinRT** (offline, word timings).
- **Frontend:** Next.js 14.2 App Router, TypeScript strict, Tailwind 3.4, shadcn/ui-style components on Radix
  (dialog, popover, tabs, collapsible, progress, slot), Zustand (with `persist` for reader prefs),
  lucide-react icons. `output: "standalone"`; rewrites `/api/*` and `/media/*` to `BACKEND_URL`
  (default `http://127.0.0.1:8000`); `experimental.proxyTimeout: 600000` (local LLMs are slow).
- **Dev tooling:** pytest, ruff (line length 120, ignore B008 for FastAPI `Depends`; per-file E501 ignore for
  catalog/demo data), mypy (clean), `tsc --noEmit` (clean), Docker + docker-compose (backend, frontend,
  optional `ollama` profile, `host.docker.internal` for host Ollama).

## 3. Repository layout

```
localguia/
  README.md  REBUILD_PROMPT.md  docker-compose.yml  .gitignore  localguia.code-workspace
  start-backend.ps1  start-frontend.ps1
  backend/
    requirements.txt  requirements-nlp.txt  requirements-audio.txt  requirements-dev.txt
    pyproject.toml  alembic.ini  Dockerfile  .env.example
    migrations/ env.py  script.py.mako  versions/0001_initial_schema.py ...
    app/
      main.py  config.py  db.py  models.py  schemas.py  migrations_runner.py
      catalogs/ __init__.py  grammar_es.py  grammar_nl.py
      demo/ __init__.py  nl_en.py  seed.py
      routers/ system.py words.py stories.py flashcards.py imports.py tutor.py speech.py output.py analytics.py
      services/ runtime_config.py llm.py prompts.py tokenizer.py alignment.py fsrs.py srs.py stories.py
                dictionary.py tts.py windows_tts.ps1 stt.py importers.py images.py tutor.py output.py
                jobs.py worker.py grammar.py analytics.py profiles.py
    tests/ conftest.py test_fsrs.py test_text.py test_api.py test_output.py
  frontend/
    package.json  next.config.mjs  tsconfig.json  tailwind.config.ts  postcss.config.mjs  components.json
    .eslintrc.json  Dockerfile  next-env.d.ts
    src/app/ layout.tsx globals.css page.tsx(dashboard) read/ listen/ speak/ write/ flashcards/ tutor/
             settings/ reader/[id]/
    src/components/ app-shell.tsx job-progress.tsx importers.tsx
             ui/ (button card dialog popover misc[badge,input,textarea,select,label,progress,tabs,collapsible,spinner,error])
             reader/ (token-text word-popover media-player)  stories/ (story-card generate-dialog)
             flashcards/ (study-card story-from-cards)  output/ (feedback-panel task-picker)
             dashboard/ (charts grammar-checklist)
    src/lib/ api.ts types.ts store.ts speech.ts diff.ts utils.ts
```

`src/lib/types.ts` must mirror `backend/app/schemas.py` exactly.

## 4. Data model (SQLAlchemy 2, all timestamps `UTCDateTime`)

- **language_profiles**: id, target_language (ISO code), native_language, cefr_level (A1–C1),
  interests (JSON list), daily_goal (words read/day, default 1500), is_active, created_at. Exactly one
  active profile; everything else is scoped to the active profile's target language.
- **words**: id, lemma, surface_form, language, status (0 Ignored, 1 Learning, 2 Familiar, 3 Known,
  4 Mastered), translation (cached gloss), notes, last_seen, occurrences_count, created_at, updated_at.
  Unique (language, lemma). **No row = unseen.**
- **flashcards**: id, word_id (FK cascade), story_id (FK set null), front_text, back_translation,
  context_sentence, context_translation, notes, audio_path, sentence_audio_path, image_path, srs_state
  (JSON FSRS state), **due_at** (denormalized, indexed), created_at.
- **review_logs**: id, flashcard_id, rating 1–4, mode, state_before, scheduled_days, reviewed_at.
- **stories**: id (uuid), title, language, content_raw, content_tokens (JSON list of tokens), audio_url,
  timestamps (JSON `[{word, start_time, end_time, token_index}]`), target_level, source_type
  (`daily_generated | custom_generated | flashcard_generated | imported_article | podcast | youtube | audio_upload`),
  source_url, video_id, read_status (`unread | in_progress | completed`), injected_words
  (JSON `[{word, used}]`), focus, word_count, progress (0..1), generated_for (date), created_at.
  READING sources = daily/custom/flashcard_generated/imported_article; LISTENING = podcast/youtube/audio_upload.
- **grammar_tags**: id, language, code (unique, `<lang>_<slug>`), title, description, category, cefr_level,
  mastery_score 0..1.
- **study_logs**: (language, day) unique; words_read, new_words, cards_reviewed, stories_completed,
  tutor_messages. Powers streaks and charts.
- **conversations** (id uuid, language, title, scenario, created_at) and **chat_messages** (role, content,
  translation, corrections JSON `[{original, corrected, explanation}]` about the *preceding* user message).
- **output_submissions**: id uuid, language, kind (`writing | speaking`), prompt, text (writing or transcript),
  audio_url (recording), corrected_text, corrections JSON `[{original, corrected, explanation, type}]`
  (type ∈ grammar, vocabulary, spelling, word_order, style), feedback JSON
  `{summary, strengths[], improvements[], cefr_estimate, score 0-100}`, created_at.
- **jobs**: id uuid, kind, status (`pending | running | done | error`), progress, message, result JSON.
- **lookup_cache**: key (sha256), language, payload JSON.
- **app_settings**: key, value JSON (one row `runtime` holding RuntimeConfig).

## 5. Runtime settings (stored in SQLite, editable in the UI; env vars `LOCALGUIA_*` only provide defaults)

`llm_base_url` (default `http://localhost:11434/v1`), `llm_api_key` (`ollama`), `llm_model` (`llama3.1:8b`),
`llm_temperature` 0.8, `llm_json_mode` true, `llm_timeout_seconds` 300; `tts_provider`
(`edge | piper | openai | windows | none`), `tts_voices` {lang: voice} (Edge defaults such as
`nl-NL-ColetteNeural`, `es-ES-ElviraNeural`), `piper_binary`, `piper_voices_dir`, `tts_base_url`,
`tts_api_key`, `tts_model`; `whisper_model` `small`, `whisper_device` `auto`, `whisper_compute_type`
`int8`, `use_whisperx`; `image_provider` (`placeholder | openai | none`), `image_base_url`,
`image_api_key`, `image_model`; `daily_stories_enabled`, `daily_story_count` 3; `desired_retention` 0.9;
`new_cards_per_day` 20.

GET `/api/settings` **masks secrets** (`••••` + last 4). PATCH ignores masked values and unknown keys.

## 6. Core logic (implement exactly)

### 6.1 Tokenizer (`services/tokenizer.py`)
Token fields: `index, text, lemma (lowercase), pos, morph, is_punctuation, is_word, whitespace,
sentence_index, start (char offset), reading (furigana or pinyin), is_target`. **Invariant: concatenating
`text + whitespace` over all tokens reproduces the input exactly** (test it). Backends, best available
first (cache them per language): spaCy model → `spacy.blank(lang)` + sentencizer → Unicode regex fallback
(`\w+(?:['’\-]\w+)*|[^\w\s]+|\s+`). Japanese: fugashi (lemma, pos1, katakana reading → hiragana, only for
tokens containing kanji). Chinese: jieba + pypinyin (tone marks). Sentence boundaries: sentence-final
punctuation `[.!?…。！？]` or a newline in the whitespace. `tokenize_marked()` strips `**bold**` markers
(the LLM's way of marking injected words) and flags overlapping word tokens `is_target`.
`sentence_text(tokens, i)` joins a sentence's tokens and strips it; the frontend builds the same string.

### 6.2 Alignment (`services/alignment.py`)
Map timed words (TTS boundaries, Whisper, subtitles) onto tokens by aligning **normalized character
streams** (NFKD, lowercase, alphanumerics only) with `difflib.SequenceMatcher(autojunk=False)`.
Interpolate any unmatched tokens from their neighbours, so every word token gets a timestamp. This tolerates
"del" vs "de"+"el" and CJK segmentation differences. `distribute_segments()` spreads subtitle segment time
across words by character length.

### 6.3 FSRS-5 scheduler (`services/fsrs.py`, pure Python, fully unit-tested)
Default 19 weights:
`0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621`.
DECAY = −0.5, FACTOR = 0.9^(1/DECAY) − 1 (=19/81). R(t,S) = (1 + FACTOR·t/S)^DECAY.
Interval = S/FACTOR·(r^(1/DECAY) − 1), rounded, clamped to 1..36500 days. S0(G) = w[G−1].
D0(G) = w4 − e^(w5·(G−1)) + 1. Next D = w7·D0(4) + (1−w7)·(D + ΔD·(10−D)/9), ΔD = −w6·(G−3),
clamped 1..10. Recall S′ = S·(1 + e^w8·(11−D)·S^−w9·(e^(w10·(1−R))−1)·(w15 if Hard)·(w16 if Easy)).
Forget S′ = min(w11·D^−w12·((S+1)^w13−1)·e^(w14·(1−R)), S/e^(w17·w18)). Same-day review (elapsed < 1 day):
S′ = S·e^(w17·(G−3+w18)). States New/Learning/Review/Relearning; learning steps 1 min, 10 min; relearning
step 10 min. Hard on step 0 = average of the first two steps. Good advances a step and graduates after the
last; Easy graduates immediately; Again in Review increments lapses and enters Relearning. Provide
`preview()` for all four ratings plus a `format_interval` label ("10m", "4d", "2.1mo"). Tests: a new card
rated Good → 10 min; Easy → 16 days; interval ordering Again < Hard < Good < Easy; difficulty direction;
serialization round-trip.

**Word status follows the card:** after a review, if the card is not in Review state → Learning;
otherwise stability < 3 d → Learning, < 21 d → Familiar, < 90 d → Known, else Mastered (never override
Ignored). The study queue lists due review/learning cards first, then new cards up to `new_cards_per_day`
minus the new cards already introduced today.

### 6.4 Organic SRS and the story engine
`srs_injection_words()`: up to 10 lemmas. First words with cards due within 24 h (soonest first), then
Learning-status words (least recently seen first). The story prompt includes, verbatim:
*"You MUST naturally incorporate these specific target words into the story context: [w1, w2, …]. Bold them
in the output using **double asterisks**."* The model returns `# Title` followed by the story. Parse the
title (fall back to a short first line), strip the bold markers, tokenize, set `is_target`, and record
`injected_words[{word, used}]` (also flag unbolded tokens whose lemma or surface matches a target).
`generate_story(..., target_words=None)`: passing an explicit list overrides the automatic selection (used
by "story from my flashcards", `source_type="flashcard_generated"`).

**Level calibrator** (`prompts.py`), per level: target length (words) / max words per sentence / vocabulary /
allowed grammar / forbidden grammar:
- A1: 120–180 / 8 / ~500 most frequent words / present tense only, simple sentences / any past or future,
  subjunctive, conditional, passive, relative clauses, idioms.
- A2: 180–260 / 12 / ~1000 words / present, simple past (+ present perfect where natural), near future,
  reflexives, object pronouns, simple because/when clauses / subjunctive, conditional, passive, pluperfect.
- B1: 260–360 / 18 / ~2000 words / all indicative tenses, simple conditional, relative clauses, common present
  subjunctive / past subjunctive, complex passives, literary tenses.
- B2: 360–480 / 25 / ~4000 words incl. idioms / subjunctives, passive, reported speech, unreal conditionals /
  archaic forms.
- C1: 480–650 / 35 / broad, nuanced vocabulary / full range / nothing.

**Daily story worker:** a daemon thread (15 s initial delay, then every `worker_interval_seconds`) that
idempotently creates `daily_story_count` stories for today, picking topics from the profile's interests or a
default list. It is guarded by a lock, swallows LLM errors with a warning, and can be disabled in settings.
`POST /stories/daily/run` triggers it as a job.

**Complete story:** bump occurrences and last_seen for every lemma. If requested, create unseen words as
**Known** (LingQ-style "finish page"), and log words_read and stories_completed once.

### 6.5 LLM client (`services/llm.py`)
POST `{base}/chat/completions` with `model, messages, temperature, stream:false`. For JSON calls add
`response_format: {type: json_object}` when `llm_json_mode`, and **retry once without it on HTTP 400**.
`extract_json()` strips code fences, tries `json.loads`, then the outermost `{…}` / `[…]`. Wrap all
transport/HTTP/shape errors in `LLMError`. `ping()` = GET `/models` with a 5 s timeout (handle `data: null`).

### 6.6 Dictionary lookup
POST `/lookup {word, lemma, sentence, morph, pos}` → JSON `{lemma, translation (in context), definitions[≤3],
part_of_speech, grammar{tense, mood, person, number, gender, case}, explanation, sentence_translation}` in the
learner's native language, `temperature 0.1`. Cache key = `sha256(f"{lang}|{native}|{word.lower()}|{sentence}")`.
Without an LLM, return spaCy morphology parsed into `grammar` plus an `error` field; never return 500.

### 6.7 TTS / STT
- `synthesize(cfg, text, lang, out_path) -> (path, word_timings | None)`.
- edge: `Communicate(text, voice, boundary="WordBoundary")` (fall back without `boundary` for edge-tts < 7);
  offsets are in 100 ns ticks.
- **windows:** a PowerShell script (`windows_tts.ps1`, spawned with `-NoProfile -ExecutionPolicy Bypass`)
  using `Windows.Media.SpeechSynthesis.SpeechSynthesizer` with `Options.IncludeWordBoundaryMetadata = $true`.
  Bridge WinRT async with `System.WindowsRuntimeSystemExtensions.AsTask` (PowerShell 5.1 cannot await
  IAsyncOperation). Read the `SpeechWord` TimedMetadataTrack cues (`StartPositionInInput`,
  `EndPositionInInput`, `StartTime`). Write the WAV via `DataReader`. Pick the voice by locale (e.g. nl-NL →
  "Microsoft Frank"). Print JSON `{voice, words:[{word,start,end}]}` to stdout as UTF-8. Ignore Edge-style
  voice names ending in "Neural". OneCore voices are invisible to System.Speech, which is why WinRT is needed.
- piper (subprocess with stdin text) and openai `/audio/speech` give no timings → align with Whisper if it's
  installed.
- `cached_tts_url()`: content-addressed cache under `media/tts/` (sha1 of provider|voice|text).
- Story narration as a job: synthesize → timings (provider or Whisper) → `align_tokens`.
- STT: faster-whisper with `word_timestamps=True`, `vad_filter=True`, a cached model, progress callbacks, new
  paragraph on pauses > 2 s, optional WhisperX forced-alignment refinement.

### 6.8 Background jobs
A thread pool (2 workers) plus the `jobs` table. `submit_job(db, kind, fn)` returns the job immediately; `fn`
gets a context with `progress(value, message)`. On error, persist the message. The frontend polls
`GET /api/jobs/{id}`. Use jobs for story generation, flashcard stories, narration, podcast/audio
transcription and daily stories.

### 6.9 Output practice (writing and speaking)
Built-in tasks per kind and level (3 each, written in English so they work for any language). An AI task
generator falls back to a random built-in task. The evaluation prompt asks for JSON
`{corrected_text, corrections[{original, corrected, explanation, type}], summary, strengths[], improvements[],
cefr_estimate, score}` with explanations in the native language. For speaking, it treats the text as an ASR
transcript: ignore punctuation, capitalisation and glitches, and focus on grammar, vocabulary and naturalness.
Clean the response: drop no-op corrections, clamp the score to 0–100 (accept string numbers), uppercase the
CEFR value. **The speaking endpoint is multipart (optional audio file + optional browser transcript + task).**
Save the recording to `media/recordings/`. Without a transcript, transcribe with Whisper; if that's
unavailable, return a 503 saying "use Chrome/Edge for live transcription or install faster-whisper".

### 6.10 Analytics
Totals from study_logs. Vocabulary estimate = known + mastered + 0.5·familiar. Estimated level = highest CEFR
benchmark reached (A1 500, A2 1000, B1 2000, B2 4000, C1 8000). The streak counts consecutive active days
ending today (or yesterday, so it survives until midnight). Also return a 30-day history, today vs goal,
cards due, and a grammar summary per level.

### 6.11 Grammar catalogs
`app/catalogs/grammar_<lang>.py` exports `CATALOG: dict[level, list[(category, title)]]`. Codes are
deterministic slugs, de-duplicated within the catalog. They are seeded automatically when a profile for that
language is created. Ship **Spanish with 314 items** (following the Instituto Cervantes PCIC inventory:
A1 57, A2 65, B1 70, B2 65, C1 57) and **Dutch with 88 items** (de/het, V2 and inversion, perfectum with
hebben/zijn, separable verbs, er, subordinate word order, passive with worden, …).

## 7. HTTP API (all under `/api`; media served at `/media/*`)

| Area | Endpoints |
|---|---|
| System | `GET /status` (llm ping, tokenizer backends per language, tts provider, whisper available, has_profile) · `GET/PATCH /settings` · `GET /profiles` · `GET /profiles/active` · `POST /profiles` (deactivates others, seeds grammar) · `PATCH /profiles/{id}` · `POST /profiles/{id}/activate` · `GET /jobs/{id}` |
| Words | `GET /words/map` (compact `{lemma: {s, t}}` for colouring) · `GET /words?status&q` · `PUT /words` (upsert status/translation; logs new_words) · `DELETE /words/{id}` · `POST /lookup` |
| Stories | `GET /stories?section=read\|listen&source_type&read_status&has_audio&limit` · `POST /stories` (paste text) · `POST /stories/generate` (job) · `POST /stories/daily/run` (job) · `GET /stories/{id}` (marks in_progress) · `PATCH` · `DELETE` · `POST /stories/{id}/complete {mark_unseen_known}` · `POST /stories/{id}/audio` (job) |
| Flashcards | `GET /flashcards?q` · `GET /flashcards/study?limit` (with interval previews) · `POST /flashcards` (creates/updates the word to Learning; background task translates the context sentence, renders word + sentence audio and an image) · `POST /flashcards/generate-story {source: due\|learning\|selected, card_ids, max_words, topic, level}` (job; 422 if no cards match) · `PATCH/DELETE /flashcards/{id}` · `POST /flashcards/{id}/review {rating, mode}` · `POST /flashcards/{id}/media` |
| Import | `POST /import/article {url}` · `POST /import/youtube {url}` (story with video_id + word timings) · `POST /import/podcast/feed {url}` → episodes · `POST /import/podcast/episode {audio_url, title}` (job: download + Whisper) · `POST /import/audio` (multipart, job) |
| Tutor | `GET/POST /tutor/conversations` (POST creates with the AI opening message; 502 without AI) · `GET/DELETE /tutor/conversations/{id}` · `POST /tutor/conversations/{id}/messages` → assistant message with `translation` + `corrections` (falls back to a plain reply if the JSON breaks) |
| Speech | `POST /speech/tts {text, language}` → `{url}` · `POST /speech/stt` (multipart) → `{text}` |
| Output | `GET /output/tasks?kind` · `POST /output/tasks/generate?kind` · `GET /output/submissions?kind` · `GET/DELETE /output/submissions/{id}` · `POST /output/writing {prompt, text}` · `POST /output/speaking` (multipart: file?, transcript, prompt) |
| Analytics | `GET /analytics/summary` · `GET /grammar?level` · `PATCH /grammar/{id} {mastery_score}` |

AI failures return 502 with a human-readable `detail`; missing optional dependencies return 503 with
install instructions; a missing profile returns 409 "Create one in Settings".

## 8. Frontend (Next.js App Router, all pages client components)

**Shell:** a left sidebar (mobile: bottom bar) with **Dashboard, Read, Listen, Speak, Write, Flashcards,
Tutor, Settings**, the active language plus level badge, and a dark-mode toggle (class strategy, set
before paint by an inline script, persisted in localStorage). With no profile, show a welcome card linking
to Settings. Redirect `/library` → `/read` and `/import` → `/listen`. Theme: HSL CSS variables using
`hsl(var(--x) / <alpha-value>)` so opacity modifiers work, a teal primary, a serif reading font, and word
colours as CSS variables in light and dark: unseen = light blue, learning = yellow, familiar = pale yellow,
known = faint, mastered/ignored = none, injected = primary-colour underline.

- **Dashboard:** stat tiles (streak, words read, known incl. mastered, learning, cards due), today's goal bar,
  a CEFR progress meter split into five equal bands (one per level, each filling proportionally, thresholds
  labelled), a 30-day words-read bar chart (one hue, 4 px rounded tops, 2 px gaps, hover tooltip with date,
  words and cards, plus an sr-only table), today's daily stories, and the grammar checklist (level tabs,
  grouped by category; click cycles 0 → 0.5 → 1; per-level progress).
- **Read:** texts only (`section=read`), with filter tabs All / Daily / Generated / From my flashcards /
  Articles & pasted, and actions Today's stories (job), Import article (dialog), Paste text, Generate story
  (topic, interest chips, focus, level, "include my review words", job progress, then open the reader).
- **Listen:** a collapsible "Add listening material" section (YouTube, Podcast RSS with an episode list and
  Transcribe buttons, Audio upload), media items (`section=listen`), and narrated texts
  (`section=read&has_audio=true`). Cards open the reader with `?mode=listen`.
- **Reader `/reader/[id]`:**
  - Tokens render in a `white-space: pre-wrap` serif block, grouped per sentence, as memoized spans.
    Furigana/pinyin use `<ruby>`.
  - Clicking a word opens a Radix Popover anchored to an absolutely positioned span over that token.
    Clicking another word retargets the popover instead of closing it.
  - The popover shows the word, lemma, reading, pronunciation (TTS), contextual translation, definitions,
    POS and grammar badges, an explanation, and a sentence-translation toggle. It has status buttons 1–4 and
    ✕, and "Add to flashcards" (sends lemma, surface form, translation, context sentence and its
    translation, story id).
  - Keyboard shortcuts: `1`–`4`, `X`, `F`, `Esc`. Status changes are optimistic in Zustand and roll back on
    error.
  - The header shows level, word count, "N new of M unique", the source link, and injected-word badges
    (struck through if unused).
  - **Listening mode:** a toggle (on by default with `?mode=listen`) blurs the text, with a "Reveal text"
    banner.
  - A sticky player at the bottom (audio element or the YouTube IFrame API) has play/pause, back 5 s, a
    scrubber, and 0.8×/1.0×/1.2× speed. It reports time via rAF (audio) or 100 ms polling (YouTube); a
    binary search finds the active token, with no highlight during pauses longer than 1.5 s. Karaoke works
    in word or sentence mode, with auto-scroll. Space toggles playback; double-clicking a word seeks there.
  - "Generate narration" (job) when there's no audio.
  - "Finish & mark remaining blue words as known" shows the result.
  - Display prefs (font size, karaoke mode, auto-scroll, readings, playback rate) persist.
- **Flashcards:** the Study tab has mode chips Recognition / Recall / Listening / Cloze / Mixed and a progress
  bar.
  - The card component, per mode:
    - **Recognition:** the word plus auto-played audio, then reveal.
    - **Recall:** native meaning plus image; type or speak (Web Speech API, falling back to
      MediaRecorder → `/speech/stt`).
    - **Listening:** sentence audio only; optional transcription.
    - **Cloze:** the context sentence with the target replaced by `[...]`. Use accent-insensitive matching
      with per-character folding so indices stay aligned; only for CJK fall back to substring matching.
      Fall back to recognition when the card has no context.
  - Grading is lenient: exact → suggest Good, accents only → Hard, wrong → Again. Rating buttons show FSRS
    interval previews. Shortcuts: Enter/Space reveal, 1–4 rate.
  - Learning-step cards due within 20 min re-queue in the session. Key the card component by `${id}-${count}`
    so a re-queued card resets.
  - The Browse tab has a search box and a table with checkboxes. "Story from selected (n)" appears when cards
    are ticked.
  - The header button **"Generate a text with my words"** opens a dialog: source (still learning / due /
    selected), max words, level, topic → job → open the story.
- **Write:** a task picker (built-in tasks for the level, "Another task", "AI task", editable) and a
  textarea with spellcheck off and a word count → **Feedback panel**:
  - score / 100, a "Sounds like A2" badge, the correction count, and the summary
  - text tabs: Changes (word-level LCS diff with `<del>` red and `<ins>` green), Corrected, What you wrote
  - "Hear corrected version" (TTS)
  - strengths and improvements lists
  - each correction with its type badge, explanation, listen button and **"Flashcard"** (saves the corrected
    phrase as a card)
  - a history sidebar to reopen or delete past submissions
- **Speak:** the same task picker and a big record button. **MediaRecorder captures the audio while Web
  Speech recognition (continuous, interim results) shows a live transcript at the same time.** The transcript
  is editable before submitting; the recording plays back. Submit sends multipart audio plus transcript →
  the same Feedback panel, including playback of your own recording. Tell Firefox users that the server
  will transcribe instead.
- **Tutor:** a conversation list with role-play scenarios (free chat, café, directions, job interview,
  doctor, weekend plans). Chat bubbles have Listen (TTS) and Translate buttons. A collapsible **Coach
  feedback** under each AI reply lists the corrections to the user's previous message, or "no mistakes 🎉".
  Mic input, optional auto-speak, and optimistic sending that rolls back on error.
- **Settings:**
  - the profile form (create / switch language / update; interests as comma list; daily goal)
  - a system-status panel with a Test button (LLM ok/error, models list, Whisper, TTS, tokenizer badges)
  - LLM presets: Ollama, LM Studio, OpenAI, Anthropic `https://api.anthropic.com/v1`, Groq
  - the remaining settings fields: temperature slider, JSON mode, TTS provider incl. Windows and its voice,
    Piper/server fields, Whisper settings, image provider, daily stories, FSRS retention, new cards/day
  - a sticky Save button

`api.ts` is a typed fetch wrapper that throws `ApiError(status, detail)`, plus `waitForJob(id, onUpdate)`.
`speech.ts` provides `playAudio(urlOrNull, text, lang)` (synthesizes when no URL) and `listen()` (Web Speech
→ MediaRecorder + Whisper fallback).

## 9. Offline demo (Dutch → English) — required, no AI needed

`python -m app.demo.seed [--no-audio]` wipes the data (keeping settings and alembic_version) and sets
`tts_provider=windows` on Windows, `image_provider=placeholder` and `daily_stories_enabled=false`. It creates:

- an nl→en A2 profile (interests: cycling, food, travel, sustainability; goal 800) and the Dutch grammar
  catalog with some items at 1.0 or 0.5 mastery
- **six texts with sentence-by-sentence English translations:**
  - "Een dag op de markt" (A2, daily, with **fiets, markt, kaas, gezellig, boodschappen** injected and bolded)
  - "De verloren fiets" (A2, focus: perfectum with hebben/zijn)
  - "Koffie bij oma" (A1, completed)
  - "Amsterdam test drijvende zonnepanelen" (B1 news article)
  - "Podcast: Het weer en het weekend" (A2, `podcast`, appears under Listen)
  - "Kaas, koffie en een glimlach" (`flashcard_generated`, uses six card words)
  - Avoid apostrophe words (e.g. `'s`) in story text, because they split oddly with the regex tokenizer.
- **a hand-written glossary for every word in those texts:** `(translation, POS, dictionary lemma, grammar,
  explanation)`. Pre-fill `lookup_cache` for every (word, sentence) pair using the exact cache key, so the
  popover works offline. De-duplicate keys when a word repeats in a sentence. Print any word missing from the
  glossary.
- word statuses (mastered function words, known basics, familiar, learning card words, ignored names); the
  rest stay blue
- **12 flashcards with simulated FSRS histories** (some new, about 7 due now, some days or weeks out),
  placeholder SVG images, word and sentence audio
- 30 days of study logs with a current 12-day streak
- a café role-play tutor conversation with corrections (hebben → zijn with movement verbs, bezoekt → bezocht,
  fotos → foto's)
- one writing submission and one speaking submission with realistic feedback (inversion, Time-Manner-Place,
  irregular participles); the speaking one gets a stand-in recording made with TTS
- narration plus word timings for every text via the offline Windows voice

## 10. Scripts, tooling, docs

- `start-backend.ps1`: creates the venv under `%LOCALAPPDATA%` on first run, installs requirements, has
  `-WithNlp` / `-WithAudio` switches, and runs `python -m uvicorn app.main:app --port 8000`.
- `start-frontend.ps1`: checks Node, sets `NODE_OPTIONS=--use-system-ca`, runs `npm install` if
  `node_modules\next` is missing, then `npm run dev`.
- `localguia.code-workspace`: multi-root folders (root/backend/frontend), Python interpreter = the
  LocalAppData venv, pytest enabled, TS SDK, recommended extensions (Python, Pylance, Ruff, ESLint, Tailwind),
  launch configs for backend (debugpy uvicorn), frontend (node-terminal with NODE_OPTIONS), "Reset demo
  data", and a compound "backend + frontend".
- `docker-compose.yml` with build args (`INSTALL_NLP`, `INSTALL_AUDIO`, spaCy models; `BACKEND_URL` is a
  build arg because Next rewrites are resolved at build time), a `./data` volume, and a whisper model cache.
- README: architecture diagram, feature table, Windows-first quick start (no `&&`), Docker, configuration,
  fully-offline setup, data model, the demo, adding a grammar catalog, development commands, known
  limitations.

## 11. Quality gates (run them, don't claim them)

- `pytest`: FSRS behaviour; tokenizer round-trip, sentences and bold targets; alignment with mismatched
  tokens; subtitle distribution; title parsing; `extract_json` with fences; YouTube URL forms; an
  **end-to-end API flow with a fake LLM** (monkeypatch `LLMClient.chat`, temp data dir via env vars set
  before importing the app, background worker disabled); writing/speaking feedback; AI-down 502 path;
  flashcard-story job with `selected` cards; Read/Listen sections.
- Clean `ruff check`, `mypy app`, and `tsc --noEmit`.
- Start both servers and request every route (including `/reader/{id}?mode=listen` and the redirects).
  Check that no page contains "Failed to compile", "Unhandled Runtime Error" or "Module not found".
- When an AI model is available, generate one story, one lookup, one tutor reply and one writing correction
  end to end.

## 12. Phases (verify each before continuing)

1. **Scaffolding and DB:** layout, config, WAL engine, models, Alembic initial migration, runtime settings
   with masking, status endpoint, start scripts, workspace file. *Accept:* server starts on a fresh DB,
   `/api/status` works without Ollama.
2. **Tokenizer and reader:** tokenizer backends, words API, lookup with cache, Read page, reader with popover
   and status colours. *Accept:* the round-trip test passes; pasting text opens a colour-coded reader.
3. **Story engine and Organic SRS:** prompts and level calibrator, LLM client, generation job, daily worker,
   completion. *Accept:* a fake-LLM test proves the injection text and target flags.
4. **Audio and alignment:** TTS providers (incl. Windows), narration job, alignment, player with karaoke,
   Whisper STT. *Accept:* narration plays with word highlighting offline on Windows.
5. **Flashcards and FSRS:** scheduler, study queue, four modes, media background task, Browse, "Generate a
   text with my words". *Accept:* FSRS tests pass; a card rated Easy leaves the queue.
6. **Importers, Listen, tutor:** article, YouTube, podcast, audio upload, listening mode, tutor with coach
   feedback. *Accept:* routes work or fail with clear messages behind a proxy.
7. **Output practice:** Write and Speak pages, feedback panel with diff, history. *Accept:* fake-LLM tests and
   the UI renders the seeded submissions.
8. **Dashboard, grammar catalogs, demo seed, Docker, README.** *Accept:* the seed reports zero missing
   glossary words; all quality gates pass.

Report at the end: what was verified, what couldn't be (and why), and the exact commands to run it.
