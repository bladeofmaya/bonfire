# ADR 0001: Use ViewComponent selectively for stateful leaf UI

- Status: Accepted
- Date: 2026-08-08
- Decision owners: Bonfire maintainers
- Evidence: `docs/view-component-review.md`

## Context

Bonfire needs faster UI iteration without making its Turbo, Stimulus, caching,
accessibility, or realtime contracts easier to break. The existing interface is
mostly Rails partials and helpers. Most partial calls already use explicit
locals, but some rendering APIs depend on controller instance variables, helper
globals, duplicated control markup, global CSS, cached collections, and partial
paths embedded in broadcasts.

A proof of concept implemented the same settings control and shared-room item
with ViewComponent 4.12.0 and with disciplined explicit-local partials. Both
approaches preserved DOM and Turbo behavior and passed matching tests.
ViewComponent was better for inspectable APIs, isolated tests, previews, and
central ownership of accessibility state. Partials required fewer files, fit
ordinary Rails rendering directly, and remain easier to reconcile when an
upstream security fix crosses a controller and its form/error rendering.

The weighted result was close (204/230 for ViewComponent, 199/230 for
partials), so a universal migration is not justified.

Bonfire expects Basecamp upstream to be most useful for security, dependency,
model, migration, controller, job, and infrastructure maintenance rather than
major UI features. The rendering strategy must keep those backend patches easy
to integrate and must not move domain or authorization behavior into the view
layer.

## Decision

Bonfire will use a hybrid rendering architecture:

1. Use ViewComponent selectively for Bonfire-owned, reusable leaf presentation
   whose state or accessibility contract benefits materially from a named API,
   isolated tests, and previews.
2. Keep explicit-local Rails partials for simple markup, page composition,
   form flows closely coupled to upstream controller changes, and compatibility
   seams where Turbo broadcasts already render a partial path.
3. Keep helpers for narrow formatting and DOM-protocol construction when a
   helper is clearer than a component. Do not use helpers as hidden domain or
   authorization layers.
4. Do not migrate large containers merely because they are visually distinct.
   The sidebar shell, message composition, and composer remain partial/helper
   compositions until smaller contracts are characterized and extracted.

ViewComponent remains a production dependency, but the accepted decision does
not authorize a broad migration.

## Boundary rules

### Prefer ViewComponent when

Most of these conditions should be true:

- the unit is a leaf or small composition with one clear responsibility;
- it is Bonfire-owned rather than a thin reflection of an upstream screen;
- it has several meaningful states, such as empty, disabled, unread, error,
  loading, selected, or long-content behavior;
- the same presentation appears in multiple contexts, or a single occurrence
  has a high-risk accessibility/DOM contract;
- an explicit constructor makes required inputs and defaults clearer;
- isolated structural/accessibility tests reduce otherwise expensive page
  setup;
- previews make realistic state iteration materially faster; and
- its outer DOM, Stimulus, Turbo, cache, and CSS contracts can be stated and
  tested.

Initial likely candidates are settings fields, icon buttons, room-list items,
notification controls, and shared empty/error states.

### Prefer an explicit-local partial when

Any of these conditions dominate:

- the markup is small and has no independent behavior or state model;
- it composes a page or yields a form-builder-heavy layout;
- its primary value is keeping an upstream view/controller patch recognizable;
- it is already a stable Turbo broadcast seam and a component adds no testing
  or preview benefit;
- a component API would mostly forward arbitrary classes, locals, and HTML;
  or
- the content is unique to one screen and controller tests describe it clearly.

Partials must use explicit locals for their primary records and state. They may
use `Current` for documented request identity/account context, but must not hide
authorization or unexpected record lookup.

### Keep outside presentation objects

Components and partials may present decisions; they must not make them. Keep
these in models, policies/guards, controllers, queries, or services:

- authorization and installation-administrator checks;
- room membership and per-user visibility;
- database lookup, ordering persistence, and query scoping;
- message delivery, unread, push, webhook, and job behavior;
- strong parameters and input sanitization policy; and
- mutations or side effects other than rendering/caching presentation.

Pass already-authorized records and explicit presentation state to components.

## Turbo, broadcast, and caching policy

- A component rendered by a broadcast must support the installed Turbo Rails
  `renderable:` path and have a test that asserts action, target, and rendered
  outer DOM.
- Existing broadcast partials may temporarily render a component internally.
  Prefer this adapter when it preserves a stable upstream or broadcast seam.
- Change initial render, reconnect/refresh render, Turbo response, and broadcast
  call sites together when the canonical renderer changes.
- Do not change DOM IDs, Stimulus APIs, stream targets, cache keys, or
  view-transition names as incidental migration cleanup.
- Collection components must demonstrate preloaded queries and no per-item
  query regression.
- Cached components use ordinary Rails cache semantics. The component does not
  own model touch/invalidation policy; dependencies must be explicit and tested
  with cold and warm renders.

## CSS policy

ViewComponent does not isolate CSS. Component adoption must not be presented as
a solution to global selector coupling.

- Give production components a stable root/state class and a documented
  stylesheet owner.
- Continue using semantic color, density, spacing, control, and layout tokens.
- Preserve account custom-CSS compatibility unless a deliberate breaking
  change is documented.
- Test explicit light/dark themes, narrow/wide layouts, and relevant pointer
  capabilities independently of the Ruby renderer.

## Testing and previews

Every production component needs:

- isolated tests for its public states and accessible contract;
- a preview for states that are difficult or slow to reach in the application;
- integration/controller coverage when it participates in forms, authorization
  presentation, Turbo Frames, or Streams; and
- system coverage when behavior depends on Stimulus, focus, realtime updates,
  or responsive interaction.

Previews are development tools, not replacements for integration or system
tests. Pixel-level regression remains a separate future decision.

## Migration approach

Migration is leaf-first and incremental:

1. Characterize current markup and live behavior.
2. Define the component constructor, states, DOM contract, and CSS owner.
3. Add isolated tests and previews.
4. Introduce the component behind an existing partial adapter when useful.
5. Update one production call path and its broadcast/tests at a time.
6. Remove the adapter only when no compatibility value remains.

Each migration must be independently deployable and easy to revert. Do not
combine component extraction with a visual redesign or domain feature unless
the user explicitly scopes them together.

The `Prototype` components, partials, previews, and comparison tests remain as
executable decision evidence during Milestone 1. They are not production APIs.
When the first real components establish final naming and contracts, replace or
remove prototype artifacts rather than maintaining duplicate renderers
indefinitely.

## Consequences

### Positive

- High-value leaf UI gets explicit APIs, isolated tests, and realistic previews.
- Simple Rails rendering stays simple.
- Upstream security/backend work remains recognizable at controller/model/form
  boundaries.
- Turbo partial adapters allow gradual migration.
- The strategy avoids a sidebar/message/composer flag-day rewrite.

### Negative

- The codebase has two rendering conventions and contributors need a clear
  boundary decision.
- ViewComponent remains a dependency even while production adoption is small.
- Components add files and can encourage premature abstraction.
- Preview and component infrastructure require maintenance alongside Rails-main
  and Turbo Rails development branches.
- CSS remains globally coupled until separate stylesheet work addresses it.

### Risks and controls

- **Inconsistent choices:** apply the boundary rules in review and document why
  a new component is justified.
- **Business logic in components:** reject database lookup, authorization, and
  mutation in component classes.
- **Broken realtime behavior:** require broadcast and DOM-contract tests before
  migration.
- **Permanent duplicate renderers:** time-box adapters/prototypes and remove
  them once the migration boundary is stable.
- **Dependency incompatibility:** verify ViewComponent against the locked Ruby,
  Rails, and Turbo versions during upgrades.

## Alternatives considered

### ViewComponent everywhere

Rejected. The proof of concept did not show enough benefit to justify converting
simple partials or large protocol-heavy compositions, and broad conversion
would increase files and migration risk.

### Improved partials only

Rejected as the default. Explicit locals matched component output and Turbo
behavior, but isolated APIs and previews required more project-owned discipline
and adapter infrastructure. Bonfire's planned stateful leaf UI can benefit from
ViewComponent's established tooling.

### No architectural change

Rejected. Existing helper/partial leaks, duplicated controls, and lack of
isolated visual states already slow safe UI iteration.

## Review triggers

Revisit this decision if:

- three production components fail to reduce test or iteration effort;
- adapters/dual conventions cause recurring confusion;
- Rails gains equivalent first-party component/preview facilities;
- ViewComponent becomes incompatible with Bonfire's Rails-main baseline;
- upstream maintenance regularly crosses component boundaries in costly ways;
  or
- a larger message/composer experiment produces materially different evidence.
