---
id: appearance-theme
title: Theme and interface
summary: Light or dark mode, theme color (incl. gray and black and white), UI font size and font, tab animation and language
features: []
platforms: []
destinations: [settings_appearance, settings_typography, tab_settings]
keywords: [theme, theme color, appearance, dark mode, night mode, light mode, follow system, gray, black and white, monochrome, font size, UI font, use for the whole app, tab switch curve, animation, language, English, Chinese, Japanese, Russian]
---
Jotsy's overall look is set on the Appearance page: light or dark mode, theme color, UI font size and the tab switching animation. The interface language has its own row on the Settings home page, and the UI font is switched on in the body font settings.

## Where
- Settings → Appearance: the **Theme** group at the top (light / dark mode and theme color), then the **Interface** group (Font size, Tab switch curve), then the **Page styles** group (entries for Background & Material, Navigation bar style, Diary card style, Diary preview page and Explore).
- Settings → Language: in the **General** group of the Settings home page; the row shows the current language.
- UI font: Settings → Editor → Body font & layout → **Use for the whole app**.

## Light and dark mode
- At the top of the Theme group, pick **System** (follows the system's dark mode setting), **Light** or **Dark**. It applies right away.

## Theme color
- The palette in the Theme group shows the current color's code at the top, a row of color families in the middle, and eight shades of the chosen family below. Tap a family, then a shade. The default theme color is #1E6586: the 6th shade of the 7th family in the row (blue); look for that code to go back to the default.
- Picking a color from the **gray** family makes the whole interface true grayscale with no hue; destructive buttons such as Delete stay red.
- The last family is **black and white**: buttons, switches and so on are pure black in light mode and pure white in dark mode, and everything else is grayscale.
- The theme color tints buttons, switches, selections and page backgrounds across the app. The diary preview page can use its own "Color basis"; see "Diary card, preview page and navigation bar styles".

## UI font size
- Interface group → **Font size**: drag the slider in the dialog (85%–125% in 5% steps). The preview text below changes as you drag, and the size applies only after you tap **Confirm**. The default is 100%.
- This scales menus, buttons, settings and other interface text. The size of diary text is set separately in Body font & layout; see "Body text layout and editor settings".

## UI font
- The interface uses the built-in HarmonyOS Sans by default. To use another font everywhere, first choose it in Settings → Editor → Body font & layout (System font, or an imported TTF / OTF / TTC font), then turn on **Use for the whole app** (off by default).
- When it's on, menus, settings, dialogs and all other text switch to that font, keeping their sizes and weights. When it's off, the font is used only for diary titles, diary text and diary cards.

## Tab switch curve
- Interface group → **Tab switch curve**: sets how the animation feels when switching between the bottom tabs (Diaries, Calendar, Explore, Settings and so on). Choose **Smooth (Circ)** (default), **Balanced (Cubic)** or **Linear**.

## Interface language
- Settings → Language, then choose **中文**, **English**, **日本語** or **Русский** in "Select language". Each language is listed in its own script, so you can find yours even if you can't read the current interface.
- On first launch Jotsy picks the system language; if it isn't one of these, English is used.
- China-specific features (lunar dates, solar terms, Chinese public holidays and pinyin search) don't change with the interface language. The changelog exists only in Chinese and English; Japanese and Russian show the English version.

## Notes
- All of these apply immediately; no restart is needed.
- The AI assistant can change light or dark mode, the theme color, the interface language and the UI font size for you. For example, say "switch to dark mode", "make the theme color green", "change the language to English" or "make the text a bit bigger". "Use for the whole app" and the tab switch curve have to be changed in Settings yourself; the AI can open the page for you.
