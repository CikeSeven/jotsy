---
id: ai-assistant
title: AI assistant
summary: Turn on the AI assistant and add a provider and models; what each module does, what the AI can do for you, and privacy.
features: [ai]
platforms: []
destinations: [ai_settings, ai_recap, settings_features]
keywords: [AI, AI assistant, provider, model, API key, DeepSeek, OpenAI, Claude, Gemini, Ollama, writing assistant, continue, polish, smart fill, reflections, writing prompts, recap, chat, undo, privacy, usage]
---
The AI assistant uses an AI service you set up yourself to help you write, respond to your entries and write recaps, and in chat it can look things up and organize for you directly. Jotsy doesn't provide an AI service: requests go straight from this device to your provider, and costs follow the provider's billing.

## Turn it on and set it up
1. Settings → Features, turn on "AI assistant" (off by default).
2. Settings → AI assistant → Providers → Add provider. Presets include DeepSeek, Qwen, Kimi, OpenAI, Anthropic, Gemini and more; you can also connect Ollama or LM Studio on your computer, or a custom API.
3. Enter the API key, then tap "Fetch model list" and tick models, or use "Add manually" to type a model name.
4. Back in AI settings, tap "Test connection". "Model assignment" sets the default model, a fast model, or a model for a specific feature.

AI entry points appear only after at least one provider and model are set up.

## Modules
Each can be turned on or off in the "Features" group:
- **Writing assistant**: "AI writing" on the editor toolbar, the `/` menu, or "AI…" after selecting text. Continue, polish, expand, change tone, translate and more, or your own commands; replace the text or insert below, undone in one step.
- **Smart fill**: "Generate title with AI" and "Suggest tags & mood with AI" in the editor's ⋮ menu.
- **Reflections**: on the preview page, More → AI reflection; a persona of your choice responds, and you can save it as a comment or "Talk more".
- **Writing prompts**: "Need a writing prompt?" under the title of a new blank entry; nothing is generated until you tap it.
- **Recaps & insights**: recaps for this week, this month, this year or a custom range, optionally for one notebook; the Explore tab has an "AI insights" card.
- **Chat & actions**: tap the AI icon in the Diaries tab's top bar to open the AI assistant home and ask your diary questions; answers cite the related entries.
- **Image understanding**: sends the photos in an entry along with the text.

## Let the AI do things
With "Let the AI use tools" on in chat and a model that supports it, the AI can: search and count entries, check the calendar, to-dos and anniversaries; write new entries, add text to the end of one, change its title, date, mood and other details; add or remove tags, pin, archive, move to the recycle bin, add comments; create, rename, merge and delete tags; create and rename notebooks and put entries in or take them out; manage to-dos, anniversaries and day moods; change the theme, app language, text size and feature switches; and open pages.

Every change can be undone with "Undo", and a reply with several changes also offers "Undo all changes in this reply". Deletions are always confirmed first; with "Confirm every change" on, every change is; with "Let the AI make changes" off, the AI can only look things up and open pages.

The AI can't permanently delete or empty the recycle bin, back up, restore, import, export, share, use cloud backup, pair for LAN sync, change app lock or passcodes, change private or locked notebook settings, manage providers and keys, clean up storage, or turn off the AI assistant itself. For these it only gives you an "Open" button.

## Privacy
- It only goes online when you act; the one automatic action, "Respond after publishing", is off by default.
- Private notebooks, the recycle bin and sealed time capsules are never sent, and you can exclude notebooks and tags under "Privacy". The writing assistant and reflections work on private entries only after you turn on "Allow AI on private entries"; chats and recaps still never read them.
- "Confirm before sending" can be First time, Multiple entries (the default) or Always; the sheet shows the provider, model, number of entries, words and photos. "Send at most" is 100,000 words by default and can be set from 10,000 to 1,000,000.
- API keys and usage stay on this device and aren't backed up or synced; "Usage" shows requests and tokens. Chats, reflections and recaps go into full backups and are never synced over LAN.
