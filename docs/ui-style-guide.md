# Bonfire UI style guide

Status: Working baseline. Update this document when a production UI primitive
or its supported states change.

Bonfire uses server-rendered ERB, selective ViewComponents, semantic CSS, and a
small utility layer. The goal is a consistent interface whose Turbo, Stimulus,
accessibility, and account-custom-CSS contracts remain understandable.

Browse component states in development at `/rails/view_components`. Check each
changed primitive in light and dark themes and at desktop and mobile widths.

## Choosing markup ownership

- Use a ViewComponent for a reusable or stateful leaf with a clear API, such as
  an icon button, room-list item, notification control, or context menu.
- Use an explicit-local partial for page composition, form-builder-heavy
  markup, or a stable Turbo broadcast adapter.
- Keep database lookup, authorization, mutation, broadcasting, and membership
  decisions out of components.
- Do not create a component merely to wrap a unique page section.

See `docs/architecture/decisions/0001-hybrid-view-components.md` and
`docs/component-contracts.md` for the complete boundary rules.

## Design tokens

Use variables from `tokens.css` for sizing and density and semantic colors from
`colors.css`. Avoid introducing literal colors or one-off spacing values unless
the value represents an asset-specific constraint.

### Typography

- `--font-size-small`: metadata, section labels, supporting text
- `--font-size-medium`: ordinary interface text
- `--font-size-large`: prominent control or section text
- `--font-size-x-large` and `--font-size-xx-large`: page-level headings only

Use `.txt-small`, `.txt-medium`, `.txt-large`, `.txt-x-large`, and
`.txt-xx-large` when a utility is clearer than a feature selector.

### Spacing

- `--space-inline`: ordinary horizontal gap or padding
- `--space-block`: ordinary vertical gap or padding
- `--space-*-half`: compact relationships inside one control
- `--space-*-double`: separation between distinct sections

Prefer `.gap`, `.gap-half`, `.pad*`, and `.margin*` for ordinary composition.
Feature CSS should own spacing that is part of a stable component layout.

### Shape and controls

- `--control-size`: standard interactive-control height
- `--control-padding` and `--control-input-padding`: standard control padding
- `--radius-small`: compact badges and minor elements
- `--radius-medium`: list items and inputs
- `--radius-large`: panels and dialogs
- `--radius-pill`: badges and pill controls
- `--radius-round`: avatars and circular icon buttons

### Semantic colors

- `--color-app-bg`: application background
- `--color-surface`: primary navigation and panel surface
- `--color-surface-secondary`: raised or contrasting surface
- `--color-surface-hover`: hover and keyboard-focus backdrop
- `--color-surface-active`: selected/current backdrop
- `--color-border` and `--color-border-subtle`: structural separators
- `--color-primary`: primary action and unread badge
- `--color-text-primary`, `--color-text-secondary`, `--color-text-muted`:
  text hierarchy
- `--color-danger` and `--color-success`: destructive and successful states
- `--color-input-bg`, `--color-input-border`, `--color-input-focus-ring`:
  form controls

Do not select colors by theme in component markup. Both themes implement the
same semantic variables.

## Core UI elements

### Buttons

Base class: `.btn` from `buttons.css`.

- `.btn--icon`: circular icon-only control; always provide an accessible label
- `.btn--reversed`: visually prominent primary action
- `.btn--negative`: destructive action
- `.btn--plain`: unframed action
- `.btn--borderless`: ordinary button without its structural border
- `.btn--faux`: button-shaped non-interactive presentation

Prefer `Ui::IconButtonComponent` for repeated icon-only buttons. Do not create
a new button class solely to change padding or color if an existing variant
expresses the intent.

### Inputs

Base class: `.input` from `inputs.css`.

- `.input--transparent`: transparent field with current-color border
- `.input--invisible`: visually hidden/minimal input used by an enhanced control
- `.input--actor`: wrapper for composite inputs such as autocomplete
- `.input--file`: file input presentation
- `.input--code`: monospaced code or token input

Inputs must retain a visible keyboard focus state and use a real label or
accessible name.

### Switches

Required structure:

```erb
<label class="switch">
  <input type="checkbox" class="switch__input">
  <span class="switch__btn" aria-hidden="true"></span>
</label>
```

The `.switch` wrapper is mandatory because it provides the positioning context
for the absolutely positioned track. Never place `.switch__btn` directly in a
row or dialog.

### Avatars

Use `.avatar` and set `--avatar-size` at the owning component boundary. Current
standard sizes:

- Member-list avatar: `2.25rem` (36px at the default root size)
- Direct-message avatar: `1.5rem`, with grouped avatars contained inside the
  same `1.5rem` footprint
- Compact inline avatar: define a documented smaller size locally
- Profile or upload avatar: owned by the profile/upload component

Use `.avatar__group` for a participant group. Images are decorative when the
adjacent text already names the person.

### Panels and dialogs

- `.panel`: page-level content panel
- `.panel--wide`: wider settings or administration panel
- `.dialog`: native modal foundation
- `.dialog__close`: standard close-button placement
- `.shadow`: shared raised-surface shadow

Dialogs should use a feature root class for width and internal layout. A Turbo
Frame dialog must clear or replace its frame when closed and explicitly declare
whether its form targets the frame or `_top`.

### Context menus

Use `Ui::ContextMenuComponent`. Pass already-authorized items; the component
may omit itself when the item list is empty, but must not decide authorization.

### Sidebar list items

Room and direct-message entries should implement the same interaction states:

1. Default: transparent surface and secondary text
2. Hover: `--color-surface-hover`, without introducing a new border
3. Keyboard focus: visible focus treatment at least as strong as hover
4. Selected/current: `--color-surface-active` and stronger text weight
5. Unread: stronger label plus a consistent unread indicator or count
6. Disabled/hidden: muted presentation without removing its accessible name

Use `.sidebar-list-item` for the shared interaction contract, then add exactly
one content modifier:

- `.sidebar-list-item--channel` for a shared room;
- `.sidebar-list-item--direct` for a direct conversation;
- `.sidebar-list-item--unread` for unread emphasis; and
- `.room-list--current` for the selected room, either on the root or its
  navigation link.

`community-layout.css` owns default, hover, focus, selected, and unread states.
`direct-conversations.css` may define the direct row's columns, avatars, unread
count, and close action, but must not redefine those shared interaction states.

### Badges

Use pill geometry, `--color-primary`, and `--color-primary-fg` for unread
counts. Badge text must remain meaningful without color and must have an
accessible label when the number lacks surrounding context.

## Utility CSS

`utilities.css` is for low-level layout and text composition:

- flex/grid alignment
- gap, padding, and margin
- sizing and min-width fixes
- overflow and ellipsis
- text size/alignment
- simple fill, border, shadow, and visibility behavior

Do not compose a complex production component entirely from utilities when a
semantic root/state class would make its contract clearer. Utilities are not a
replacement for component variants.

## Interaction-state checklist

For every interactive primitive, verify:

- default
- hover on a hover-capable pointer
- keyboard focus
- active/pressed
- selected/current
- unread, error, or success where applicable
- disabled
- long text and text truncation
- light and dark themes
- mobile and desktop widths
- touch devices where hover-only controls need an alternative

## Stylesheet ownership

- `_reset.css`: browser normalization
- `tokens.css` and `colors.css`: design tokens and theme values
- `base.css`: element defaults and truly global behavior
- `utilities.css`: low-level composition utilities
- `buttons.css`, `inputs.css`, `avatars.css`, `panels.css`,
  `context-menu.css`: reusable primitives
- `layout.css` and `nav.css`: application shell
- `sidebar.css`: stable legacy sidebar structure and non-community fallbacks
- `community-layout.css`: community rail shell and shared sidebar-list-item
  interaction states
- `direct-conversations.css`: direct-message rows and create/edit dialog
- feature files such as `messages.css`, `composer.css`, `signup.css`, and
  `profile-settings.css`: feature-owned presentation
- `components.css`: component gallery and preview workspace only

A selector should have one primary owner. Avoid defining the same root selector
in both a primitive file and a feature/layout file; use a named modifier or a
more specific feature root instead.

## Tailwind

Bonfire does not currently use Tailwind or a Node CSS build. Do not introduce
Tailwind utilities piecemeal. Reconsider it only after shared primitives and
interaction states are normalized, with an explicit decision about the build
pipeline, account custom CSS, and upstream merge cost.
