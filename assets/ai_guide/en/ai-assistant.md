---
id: ai-assistant
title: AI assistant
summary: Turn on the AI assistant and add a provider and models; what each module does, what the AI can do for you, and privacy.
features: [ai]
platforms: []
destinations: [ai_settings, ai_recap, settings_features]
keywords: [AI, AI assistant, provider, model, API key, DeepSeek, OpenAI, Claude, Gemini, Ollama, proxy, writing assistant, continue, polish, smart fill, reflections, writing prompts, recap, chat, persona, writing commands, about me, answer language, describe image, undo, privacy, clear AI records, usage]
---
The AI assistant uses an AI service you set up yourself to help you write, respond to your entries and write recaps; in chat it can also look things up and organize for you. Jotsy doesn't provide an AI service: requests go straight from this device to your provider, and costs follow the provider's billing.

## Turn it on and set it up
1. Settings → Features, turn on "AI assistant" (off by default).
2. Settings → AI assistant → Providers → Add provider. Presets include DeepSeek, Qwen, Kimi, OpenAI, Anthropic, Gemini and more; you can also connect Ollama, LM Studio or a custom API.
3. Enter the API key, then "Fetch model list" and tick models, or "Add manually". A provider's "Advanced" has "HTTP proxy" and "Custom headers". To reach Ollama or LM Studio on a computer from your phone, replace localhost with the computer's LAN address and let the server listen on 0.0.0.0.
4. Back in AI settings, tap "Test connection". "Model assignment" sets the default model, a fast model, or a model for a specific feature.

AI entry points appear only after at least one provider and model are set up.

## Modules
Each can be turned on or off in the "Features" group, which also holds its options:
- **Writing assistant**: "AI writing" on the editor toolbar, the `/` menu, or "AI…" after selecting text. Continue, polish, expand, change tone, translate and more, or your own commands; replace the text or insert below, undone in one step.
- **Smart fill**: "Generate title with AI" and "Suggest tags & mood with AI" in the editor's ⋮ menu, plus "Generate title" next to the title (can be hidden). "Suggest on the publish page" is off by default; when on, the entry is sent once each time you open the publish page, and nothing is filled in until you tap a suggestion.
- **Reflections**: on the preview page, More → AI reflection; a persona responds, and you can "Save as comment" or "Talk more". "Respond after publishing" is off by default; when on, each new entry is sent once when published, only to a provider you've already confirmed, and never when confirmation is set to Always.
- **Writing prompts**: "Need a writing prompt?" under the title of a new blank entry; nothing is generated until you tap it.
- **Recaps & insights**: recaps for this week, this month, this year or a custom range, optionally for one notebook; old ones are under "Earlier recaps" and can be saved with "Save as entry". Explore has an "AI insights" card.
- **Chat & actions**: tap the AI icon in the Diaries tab's top bar for a new chat; answers cite related entries. The clock icon opens "Chats" (on the left in wide windows) to search, rename, pin or delete; the pencil starts a new chat. Under an answer you can copy, "Save as entry", "Regenerate" or delete it; your question has "Edit and resend". "Export chat" in the ⋮ menu exports the messages you tick as Markdown, plain text or JSON. The chips under the input box switch the scope, the persona and "Model and thinking" (the model, and thinking Auto, Off, Low, Medium or High), remembered per chat. The photo button left of the chips sends photos (on phones you can also take one), up to 9 per message, with or without text; if the current model can't see photos a note says so, the photos are still kept and the AI can still add them to entries.
- **Image understanding**: sends photos from entries and photos you send in chat to the model; with it off, none of them are sent. In chat the AI looks at an entry's photos when it needs to, and can pick which ones; it sends at most "Photos per request" at a time and continues with the rest. While editing, tap a photo and choose "Describe with AI" to insert a description below it.

## Personal touch
The "Personal touch" group in Settings → AI assistant:
- **Personas**: the default persona for Reflections, Chat and Recaps; hide built-in ones or "Copy as mine" to edit them, or "New persona".
- **Writing commands**: reorder, hide, rewrite prompts or add your own with "New command".
- **About me & style**: "About me" and "Writing style" are sent with every request; leave them empty to send nothing.
- **Answer language** (Diary / App / Custom), **Answer length** (Short / Medium / Detailed) and **Creativity** (Precise / Balanced / Creative; only for providers that accept a temperature).

## Let the AI do things
With "Let the AI use tools" on in chat and a model that supports it, the AI can: search and count entries; check the calendar, to-dos and anniversaries; write new entries, add text to the end of one (including photos you sent in the chat), change its title, date, mood and other details; look at the photos in entries; add or remove tags, pin, archive, move to the recycle bin, add comments; create, rename, merge and delete tags; create and rename notebooks and put entries in or take them out; manage to-dos (including reminders, repeats, steps and lists), anniversaries and day moods; change the theme, app language, text size, feature switches and common switches of the editor, preview page, calendar and to-dos (such as opening entries straight in the editor, the first day of the week, the lunar calendar, showing completed to-dos), and tell you how they are set now; and open pages. If a reply runs out of steps ("Max steps per reply"), say "continue" to let it keep going.

Thinking and look-ups such as searching and reading are folded into "Thought for N seconds · Used N tools"; open it to see each step and the entries or to-dos involved. Opening pages, changes and actions that need your confirmation show as cards. After a card takes you to a home tab or a notebook, press back to return to the chat.

Every change can be undone with "Undo" on its card, and several changes also get "Undo all". Deletions are always confirmed first; with "Confirm every change" on, every change is; with "Let the AI make changes" off, the AI can only look things up and open pages.

The AI can't permanently delete or empty the recycle bin, back up, restore, import, export, share, use cloud backup, pair for LAN sync, change app lock or passcodes, change private or locked notebook settings, manage providers and keys, clean up storage, change its own settings or turn itself off, and it doesn't adjust style pages (background, navigation bar, entry cards, preview page style and so on). For these it only gives you an "Open" button.

## Privacy
- Requests are sent when you use an AI feature. Two switches, both off by default, also send: "Suggest on the publish page" once each time you open the publish page, and "Respond after publishing" once for each new entry you publish.
- Titles and text are always sent; under "Sent with entries", date, mood, tags and weather are on and location is off by default.
- Private notebooks, the recycle bin and sealed time capsules are never sent. Under "Chats and recaps" you can turn off "Include archived entries" and exclude notebooks and tags; "Send at most" is 100,000 words by default and can be set from 10,000 to 1,000,000.
- "Allow AI on private entries" is off by default; when on, the writing assistant, smart fill, reflections and "Describe with AI" work on private entries. Entries the AI looks up in chats, and recaps, still never include them.
- "Confirm before sending" can be First time, Multiple entries (the default) or Always; the sheet shows the provider, model, number of entries, words and photos. "Ask again for every provider" shows the first-time confirmation again.
- Photos you send in chat are kept on this device in the same folder as entry photos and go into full backups; Storage lists them as "AI chat", where you can view, compress or delete them. After you delete a chat, its photos that no entry uses are removed at the next cleanup.
- API keys and usage stay on this device and aren't backed up or synced; "Usage" shows requests and tokens. Chats, reflections and recaps go into full backups and are never synced over LAN; "Clear all AI records" deletes them all from this device. This can't be undone, and your entries aren't affected.
