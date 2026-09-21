---
name: figma-sync
description: |
  Keeps Figma designs and the Flutter frontend of reciclalo_app (frontend/lib/) in sync in both directions, using the Figma MCP tools directly — no Code Connect, no Stitch bridge. Use whenever the user wants to:
  (1) Implement a Figma frame/screen/component into the Flutter app ("implement this Figma screen", "build the picker map screen from Figma", "code up this Figma component")
  (2) Push an already-implemented Flutter screen or widget back into Figma so the design file reflects current code ("push this screen to Figma", "update the Figma file to match the current picker flow", "sync my HomeScreen back to Figma")
  (3) Generally "sync Figma with code" or "keep the designs up to date" for this repo, in either direction.
  This is a thin orchestrator on top of the generic figma-design-to-code, figma-generate-design, and figma-use skills — it adds reciclalo_app-specific conventions (design tokens, folder layout, Spanish UI strings, flutter analyze gate) that those generic skills don't know about. Trigger this instead of (or before) calling Figma MCP tools directly whenever the request is repo-specific, not a generic Figma question.
---

# Figma Sync (reciclalo_app)

Orchestrates two on-demand, one-directional flows between Figma and this repo's Flutter frontend. Neither flow is automatic (no git hook, no CI step) — each runs only when explicitly invoked, because design and code diverge for good reasons and a blind auto-sync would just create noise or overwrite deliberate choices on either side.

This skill does **not** use Figma Code Connect (`add_code_connect_map`, `get_code_connect_map`, `figma connect publish`, etc.) — this repo doesn't use it. It also does **not** route through Stitch (`mcp__stitch__*`) — Figma is the direct source of truth on the design side, and the Flutter code is the direct source of truth on the implementation side. If Code Connect or Stitch tools come up, that's a sign you're in the wrong skill.

## Step 0: figure out the direction

If the user's request doesn't make it obvious, ask which direction and which target before doing anything:
- **Figma → Code**: they'll give you a Figma URL, node/frame name, or describe a screen that exists in Figma but not (yet correctly) in the app.
- **Code → Figma**: they'll name a screen/widget file, a route, or a part of the app that changed and needs the design file updated to match.

Don't guess the target node or file — ask if it's ambiguous. Getting this wrong means editing the wrong frame or the wrong screen, which is expensive to undo in Figma.

## Flow A: Figma → Code

1. Load the `figma-design-to-code` skill and the `figma-use` skill before calling any MCP tool — they carry the mandatory setup and calling-convention details for `get_design_context` and friends. Don't reimplement that guidance here.
2. Call `get_design_context` on the target node, and `get_variable_defs` to pull the Figma variables (colors, spacing, radii, type) it uses.
3. **Map Figma tokens onto this repo's existing tokens** in `frontend/lib/theme/app_theme.dart` (`EcoColors`, `EcoSpacing`, `EcoRadius`, `EcoShadows`, the text scale) instead of writing literal values. Read `app_theme.dart` first so you know what's already defined. If a Figma value doesn't cleanly match an existing token (e.g. a color or spacing value that's close but not identical to anything in `app_theme.dart`), stop and flag it to the user rather than silently inventing a new token or fudging it to the nearest existing one — a small drift here compounds across screens.
4. **Place the code in the right spot.** Per this repo's conventions: collector/picker-specific screens and widgets go under `screens/picker/` and `widgets/picker/`; anything shared between roles goes directly under `screens/` and `widgets/`. Before writing a new widget, check whether an existing one already covers it (`EcoAppBar`, `EcoMapWidget`, etc.) — reuse it rather than recreating it from the Figma layer tree.
5. **Watch for the `FilledButton` width trap**: `buildEcoTheme()` sets `FilledButtonThemeData.minimumSize` to full width (`Size.fromHeight(EcoSpacing.touchTarget)`), meant for full-width CTAs. If the Figma design shows a `FilledButton` inside a `Row` or as an `AlertDialog` action (i.e. not the sole/full-width child of a `Column`), it will crash with "BoxConstraints forces an infinite width" unless you override `style: FilledButton.styleFrom(minimumSize: Size(0, EcoSpacing.touchTarget))`.
6. Write UI strings and domain comments in Spanish, matching the rest of the codebase; keep Dart/Flutter keywords and identifiers in English.
7. Before calling it done, run `flutter analyze` from `frontend/` and confirm zero issues — that's this repo's bar, not optional cleanup. If tests exist for the touched area, run them too (`flutter test`).
8. Report back which screen/widget file(s) you created or changed, and call out anything you flagged in step 3 that still needs a human token decision.

## Flow B: Code → Figma

1. Load the `figma-generate-design` skill and the `figma-use` skill before calling any MCP tool — same reasoning as Flow A, don't duplicate their instructions here.
2. Read the target screen/widget's code and note which `app_theme.dart` tokens it uses (colors, spacing, radii, text styles).
3. Call `get_variable_defs` on the Figma file **first** to see what Figma variables already exist. Reuse the existing variable that corresponds to each token (e.g. the Figma variable mirroring `EcoColors.primary`) instead of pushing a new hardcoded fill — the goal is that the Figma file's variables stay the visual mirror of `app_theme.dart`, not a second, drifting copy of the same colors. If a token has no corresponding Figma variable yet, flag it rather than inventing one arbitrarily — creating design variables is a design-system decision, not just an implementation detail.
4. Use `use_figma` / `generate_figma_design` to create or update the corresponding frame so it matches the current implementation.
5. This flow is on-demand only — never trigger it automatically off a file save or commit. Run it only when the user explicitly asks to push a screen to Figma.
6. Report back exactly which frame/node was created or updated, with its name and link, so the user can review it in Figma before treating it as final — treat the push as a draft for their review, not a fait accompli.

## Why this skill is thin

The heavy lifting (how to call `use_figma` correctly, how to read `get_design_context` output, how to structure a design push) already lives in the generic `figma-*` skills — this file only adds what's specific to reciclalo_app: where files go, which tokens to use, the Spanish-string convention, and the `flutter analyze` gate. If you find yourself duplicating generic Figma MCP mechanics here, that instruction belongs in the companion skill instead.
