# CSS ownership and migration map

Status: Audited baseline. This document describes the current stylesheet graph
and the intended ownership boundaries for incremental cleanup. It does not
authorize a visual redesign or a bulk file move.

## How styles are loaded

Both application and component-preview layouts use `stylesheet_link_tag :all`.
Propshaft therefore exposes every stylesheet in `app/assets/stylesheets/` as a
peer asset. Bonfire does not currently have a manifest that expresses a
tokens → reset → primitives → components → pages cascade.

The application layout injects administrator-provided custom CSS after these
assets. Existing public custom properties and stable product selectors are an
installation extension API and must not be renamed without a compatibility
period.

## Ownership layers

| Layer | Current files | Responsibility |
| --- | --- | --- |
| Reset | `_reset.css` | Browser normalization and reduced-motion defaults only. |
| Design tokens | `colors.css`, `tokens.css` | Theme palettes and shared typography, spacing, control, surface, radius, and responsive contracts that do not depend on component markup. |
| Foundation | `base.css`, `layout.css`, `animation.css`, `colorize.css` | Document defaults, focus behavior, application grid, and globally named animation/icon behavior. |
| Utilities | `utilities.css` | Single-purpose layout, spacing, sizing, visibility, and text classes. Utilities must not know a product area. |
| UI primitives | `buttons.css`, `inputs.css`, `panels.css`, `separators.css`, `spinner.css`, `flash.css`, `lightbox.css` | Reusable controls and surfaces with a narrow class-based API. |
| Product components | `avatars.css`, `autocomplete.css`, `boosts.css`, `community-layout.css`, `composer.css`, `direct-conversations.css`, `embeds.css`, `messages.css`, `nav.css`, `notifications.css`, `sidebar.css` | One product UI boundary and its descendants. |
| Page/vendor adapters | `signup.css`, `pwa.css`, `filters.css`, `actiontext.css`, `code.css`, `components.css` | Page-specific composition, PWA display-mode behavior, third-party markup overrides, syntax presentation, and development-only component gallery styling. |

New rules should go into the narrowest owning layer. Do not create a generic
`misc.css`; a rule with unclear ownership is a signal that its markup boundary
needs clarification.

## Stable token families

`colors.css` is the canonical semantic color source. New styles should consume
the `--color-app-*`, `--color-surface-*`, `--color-border-*`, `--color-text-*`,
`--color-input-*`, and intent tokens. The legacy aliases (`--color-bg`,
`--color-text`, `--color-border-dark`, `--color-border-darker`,
`--color-selected*`, and `--color-negative`) remain public compatibility
aliases until custom installation CSS has a migration path.

Shared non-color decisions now live in `tokens.css`:

- typography provides the sans-serif family and the existing five-size scale;
- spacing preserves the inline (`ch`) and block (`rem`) axes and half/double
  steps used by existing utilities;
- controls expose default size and button/input padding;
- surfaces expose panel widths and narrow/wide padding;
- shape provides a named radius scale; and
- `--layout-wide-breakpoint` records the existing `100ch` contract. CSS custom
  properties cannot be used inside media conditions, so queries remain literal
  until Bonfire adopts a build-time custom-media strategy.

Legacy variables such as `--inline-space`, `--block-space`, `--font-family`,
`--btn-size`, `--panel-*`, and component-local overrides remain compatibility
APIs and now resolve through the canonical tokens where possible. New local
variables should still be namespaced to their owner (`--sidebar-*`,
`--message-*`, `--composer-*`) instead of adding another generic `--size`,
`--width`, or `--padding` variable at `:root`.

## Collision hotspots

### Global settings structure

`settings.css` owns the explicit `.settings-group` and
`.settings-group__legend` primitive. Profile settings and account bot settings
have opted in. A temporary `fieldset:not(.settings-group)` fallback preserves
signup, first-run, session, and composer behavior until those distinct
boundaries are audited; do not evolve the fallback when changing the primitive.

### Shape inferred from descendants

`buttons.css` now defines `.btn--icon` as the explicit circular-button contract.
`Ui::IconButtonComponent`, notification/involvement controls, message menus,
and the sidebar toggle have opted in. A zero-specificity
`.btn:has(.for-screen-reader):has(img, figure)` branch temporarily preserves
legacy upload, lightbox, composer, and miscellaneous controls. Adding an image
or hidden text can still alter those unmigrated callers, so use the component
or `.btn--icon` for new controls.

### Generic component variables

`--hover-*`, `--outline-*`, `--btn-*`, `--input-*`, `--avatar-*`, `--width`,
`--size`, and gap variables intentionally cascade through descendants. They are
powerful but make wrappers part of a child's styling API. Limit overrides to
the nearest owning block and avoid setting these generic names on page roots.

### Utilities carrying theme meaning

`.fill-white`, `.fill-shade`, `.txt-subtle`, and `.txt-reversed` are historical
names backed by semantic theme variables. Their names no longer describe both
themes accurately. Keep them for compatibility; prefer future surface/text
utilities named for intent rather than a literal color.

### Vendor overrides

`actiontext.css` contains intentionally high-specificity and `!important`
rules required to control Trix markup. It is a vendor adapter, not a source for
general input or typography styles. `autocomplete.css` has similar focused
escape hatches. Do not copy their specificity into product styles.

### Structural selectors

`[contents]`, Turbo Frame `display: contents`, `:has(...)`, direct-child rules,
and responsive nesting encode DOM contracts. Moving a wrapper can change grid,
flex, scrolling, button shape, and empty-state behavior without changing a
class. Consult `docs/component-contracts.md` and run the visual regression test
when touching these selectors.

### Community sidebar list items

`community-layout.css` owns the shared `.sidebar-list-item` interaction
contract for channels and direct conversations. Its modifiers express content
kind and state; the legacy `.room` and `.direct` classes remain DOM, Turbo, and
helper compatibility hooks rather than competing visual primitives.

`direct-conversations.css` owns direct-row layout, avatars, badges, close
controls, and the direct-conversation dialog. `sidebar.css` retains the older
sidebar shell and non-community fallbacks. Do not add room/direct hover or
selected rules outside the shared contract.

## Incremental migration order

1. Add shared tokens without changing computed values: density, spacing scale,
   typography scale, control heights/padding, surfaces, radii, and the current
   `100ch` layout breakpoint. **Complete.**
2. Migrate profile and account settings first. Introduce explicit settings
   group/control classes while retaining equivalent output and verify the two
   element-scoped visual baselines. **Complete.**
3. Replace descendant-inferred icon button shape with the existing
   `Ui::IconButtonComponent` and an explicit primitive modifier. **Production
   leaf components complete; legacy fallback removal remains incremental.**
4. Move page-specific rules out of `base.css` only after all call sites are
   found. PWA and notification rules are the first clear candidates.
   **PWA and notification ownership complete.**
5. Migrate one product area at a time. The community sidebar now has an
   explicit shared list-item contract and direct-conversation ownership split;
   keep remaining message/composer boundaries intact until their Turbo,
   Stimulus, cache, and responsive contracts are covered.
6. Only then consider an explicit cascade manifest/layers. Import-order changes
   are visual changes and require the full component plus visual test suites.

## Verification

For a token-only or ownership-only change:

```sh
bin/rails test test/components
bin/rails test test/system/theme_test.rb test/system/visual_regression_test.rb
git diff --check
```

Inspect the component gallery in light/dark and desktop/mobile. If a baseline
changes intentionally, review it before running with
`UPDATE_VISUAL_BASELINES=1`; never regenerate merely to silence a failure.
