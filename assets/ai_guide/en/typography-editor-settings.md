---
id: typography-editor-settings
title: Body text layout and editor settings
summary: Body font, size, spacing and indent, code block style, toolbar order and size, and editing behavior
features: []
platforms: []
destinations: [settings_editor, settings_typography, settings_code_block_style]
keywords: [editor settings, body font, font, import font, font size, line spacing, letter spacing, paragraph spacing, first-line indent, layout, typography, code block style, code theme, line numbers, toolbar, toolbar order, toolbar size, always show toolbar, open in editor, publish when going back, day photos]
---
Settings for writing live under Editor: body font and layout, code block style, the toolbar, and a few editing behaviors.

## Where
- Settings → Editor (in the **Writing** group of the Settings home page). The page has three groups: **Body text** (Body font & layout, Code block style), **Toolbar** (Toolbar order, Toolbar size, Always show toolbar) and **Behavior** (Open diaries in the editor, Publish new diaries when going back, Show that day's photos automatically).
- While reading or editing an entry, tap the "Font & layout" button in the top bar to adjust as you read; "More settings" in that panel opens the full settings page.

## Body font & layout
- **Font**: the built-in HarmonyOS Sans (default), System font (follows the font your device uses), or tap **Import font file** to import a TTF, OTF or TTC font, which becomes the body font once imported. Imported fonts can be deleted. The chosen font is also used for diary titles and for the titles and excerpts on diary cards.
- **Use for the whole app** (off by default): when on, menus, settings, dialogs and other interface text use this font too, keeping their sizes and weights.
- **Layout**: Font size 10–32 (default 16), Line spacing 1.0–3.0 (default 1.55), Letter spacing −1 to 8 (default 0), Paragraph spacing 0–48 (default 0), First-line indent 0–4 characters (default None). The preview card at the top follows the sliders live, and a value is saved when you let go; **Reset layout** restores the defaults.
- The layout applies when writing, reading and publishing diaries. First-line indent only applies to plain paragraphs; headings, lists, to-dos, quotes, code, and centered or right-aligned paragraphs aren't indented. Code blocks don't use the body font; Code block style sets their look.

## Code block style
Settings → Editor → Code block style, with a preview at the top and three tabs:
- **Theme**: Brightness (Follow theme / Light / Dark) and 10 color themes: Match app, GitHub, One, Solarized, Gruvbox, Catppuccin, Tokyo Night, Nord, Dracula, Rosé Pine.
- **Display**: Line numbers, Header bar (language name and a copy button on top), Detect language, Border, and Corner radius.
- **Font**: Code font (System monospace / Body font / imported fonts), Font size (70%–130% of the body text size), Line height.
- Code highlighting in PDF, Word and web page exports follows the theme chosen here.

## Toolbar
- **Toolbar order**: drag to reorder the editor toolbar, and untick a tool to hide it. Tools below the "Tools below go into More" divider go into the More button at the end of the toolbar. Tap **Save** in the top-right corner when done; **Reset** next to it restores the default order and shows every tool again. The gear on Insert current time sets the time format, and the gear on the code block tool opens Code block style.
- **Toolbar size**: Small / Standard / Large / Extra large. Buttons and icons scale together, and tools that no longer fit in one row go into More.
- **Always show toolbar** (off by default, phones only): keeps the toolbar at the bottom of the editor when the on-screen keyboard is hidden or you type on a physical keyboard. On computers the toolbar is always shown and this switch isn't there.

## Behavior
- **Open diaries in the editor** (off by default): tapping a diary skips the preview page and opens it for editing, laid out just like the preview. Time capsules that haven't opened yet still show their sealed page first.
- **Publish new diaries when going back** (off by default): when off, going back from a new diary saves it to Drafts; when on, going back publishes it as a diary (entries with a time capsule still go through the publish page).
- **Show that day's photos automatically** (on by default): when backfilling a past day, list that day's photos under the title. When off, open them from the editor's top-right menu. That day's photos are only available on phones.

## Notes
- Body layout and code block style are included in full backups; toolbar size and Always show toolbar are kept on this device only.
- The size of interface text isn't set here; see "Theme and interface".
- The AI assistant can't change these settings for you, but it can open Editor, Body font & layout or Code block style.
