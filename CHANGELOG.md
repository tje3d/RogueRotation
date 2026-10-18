# Changelog

All notable changes to **RogueRotation**, a next-action rotation helper for
Combat Rogues on World of Warcraft 3.3.5a (WotLK). Newest first.

## 1.1.0 — 2026-10-18

### Added
- **Button hints** — every suggested action now shows the action-bar key it is
  bound to in the top-right corner of its icon, so you can read the spell and
  the button to press at a glance.
- Hints are resolved from the real action bars — main, bonus and MultiBar
  slots, macro casts included — and refresh when you rebind keys, move spells
  between bars or edit macros. A spell that is not on a bound slot shows no
  hint.

## 1.0.0 — 2026-10-18

### Added
- First public release: a live next-action queue that shows the action to
  press right now (drawn larger) plus the next two actions beside it.
- GCD-aware suggestions — Killing Spree and Adrenaline Rush are suggested
  while the global cooldown is still running, instead of only after it
  expires.
- Trinket-gated Killing Spree — KS only goes when a trinket effect is up and
  no usable trinket is left unused; it waits while both trinkets are still
  off cooldown.
- Adrenaline Rush rides with Killing Spree — AR is held back while KS is
  ready or within ~6 seconds of coming off cooldown, so it is never wasted
  just ahead of a KS burst.
- Core rotation — keeps Slice and Dice up, uses Blade Flurry on cooldown,
  Eviscerate at 4–5 combo points, Sinister Strike to build.
- Buff trackers for Slice and Dice / Blade Flurry / Adrenaline Rush with
  swipe and countdown, plus a cooldown row for Blade Flurry / Adrenaline
  Rush / Killing Spree / Tricks of the Trade — TOT bounces while usable in
  combat.
- Lightweight engine — event-driven aura cache, per-tick cooldown cache,
  adaptive refresh (10 Hz with a target, 2 Hz idle), no per-tick
  allocations.
- Movable frame — drag it anywhere.
