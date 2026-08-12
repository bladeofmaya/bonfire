# ViewComponent review

Status: complete. ADR 0001 accepts a selective hybrid architecture.

This review asks whether ViewComponent would make Bonfire's UI faster and safer
to change. The audit and proof of concept resulted in
`docs/architecture/decisions/0001-hybrid-view-components.md`, which accepts
selective ViewComponent use without authorizing a broad migration.

## Current rendering baseline

At the time of this audit, Bonfire has:

- 39 ERB partials;
- 26 Ruby helper files;
- 36 Stimulus controllers;
- 26 globally loaded stylesheets;
- eight view files participating in fragment or collection caching; and
- six controller files that render partial paths directly in Turbo
  broadcasts or `render_to_string`.

At the start of the audit there was no ViewComponent dependency or component
directory. Reuse came from partials, block/layout partials, helpers that
construct HTML, shared CSS classes, and Stimulus data contracts. Most partial
calls already passed explicit locals; the architecture was not uniformly
implicit or broken. ViewComponent was subsequently added for the proof of
concept and retained by ADR 0001.

## Fragility audit

### Implicit inputs and side effects

The clearest local problems are a small number of partials/helpers whose public
arguments do not describe what they read or change:

| Unit | Apparent API | Hidden dependency or side effect | Risk |
| --- | --- | --- | --- |
| `app/views/rooms/show/_invitation.html.erb` | `room:` | Reads `@room` instead of its local | Rendering it outside `RoomsController#show` can fail or use the wrong room. |
| `app/views/rooms/layouts/_edit.html.erb` | `room:` | Authorization reads `@room`; it also assigns `@page_title` | The local and instance variable can diverge; rendering changes page state. |
| `app/views/rooms/layouts/_new.html.erb` | yielded content | Assigns `@page_title` | The layout partial has an undocumented page-level output. |
| `app/views/users/_ban_button.html.erb` | `user:` | Accessible labels read `@user` | Reuse for a different local user can announce the wrong person. |
| `RoomsHelper#link_to_edit_room(room)` | `room` argument | Route and transition name use `@room` | The method signature promises more isolation than it provides. |
| `Users::ProfilesHelper#profile_form_with(model)` | `model` argument | Always submits `@user` | The helper name/signature obscure its true scope and have already encouraged reuse by bot forms. |

`Current.user` and `Current.account` are also read by many views and helpers.
That is acceptable for request identity and account presentation when it is
documented, but components must not turn those globals into hidden domain or
authorization decisions.

Conclusion: explicit constructor arguments would help these units, but the
same benefit is available immediately by correcting partial locals and helper
arguments. This alone does not justify ViewComponent.

### Global CSS coupling

The layout loads all Propshaft stylesheets. Styles are not scoped to partials or
future components, and broad classes/selectors are shared across unrelated
screens:

- `base.css`, `utilities.css`, `buttons.css`, `inputs.css`, and `panels.css`
  define application-wide element and utility behavior;
- feature styles depend on DOM ancestry, shared utility classes, and mutable
  custom properties;
- the `100ch` breakpoint and pointer queries coordinate layout across
  `layout.css`, `nav.css`, `sidebar.css`, `messages.css`, and `composer.css`;
- account custom CSS loads after application CSS and depends on stable selectors
  and custom properties.

ViewComponent does not provide CSS isolation. A Ruby component wrapped around
existing markup would remain just as vulnerable to a broad selector change.
Clear CSS ownership and stable component root classes must be evaluated
separately from the rendering technology.

### Duplicated controls and accessibility details

Button/input structure is repeated across signup, sessions, settings, bots,
rooms, profiles, messages, and notification screens. Common details include:

- reversed, negative, icon-only, and submit button variants;
- decorative icon handling and `.for-screen-reader` labels;
- upload input plus preview/delete controls;
- input actor rows with icon, label, field, errors, and help text;
- destructive confirmation, focus, and Stimulus data attributes.

Some helpers centralize narrow cases (`submit_room_button_tag`,
`profile_form_submit_button`, `button_to_copy_to_clipboard`), but there is no
single settings-field or icon-button API. Similar-looking controls can therefore
drift in accessible naming, touch size, disabled state, and theme behavior.

These leaf controls are good component candidates: their state space is clear,
they can be tested without a full page, and they do not own domain decisions.

### Turbo, Stimulus, and DOM protocols

The most fragile UI boundaries are protocols rather than partial syntax:

- helpers construct `message-area`, `composer`, room/message DOM IDs, Stimulus
  targets, values, classes, outlets, and custom-event listeners;
- sidebar/message/composer partials must match Turbo Frame and Stream targets;
- optimistic message markup in `_template.html.erb` must match server-rendered
  message markup;
- view-transition names connect elements rendered in different files;
- global and per-user room streams carry different visibility/unread context.

A component can centralize these attributes, but changing from a partial to a
component does not permit the protocol to change. Characterization tests must
assert the existing outer DOM before migration.

### Broadcast paths

The following live update paths render partials by name:

- shared rooms from open, closed, and involvement controllers;
- direct rooms from `Rooms::DirectsController`;
- full messages from `Message::Broadcasts`;
- message presentation updates from `MessagesController`;
- boosts from `Messages::BoostsController`.

The installed Turbo Rails version supports a `renderable:` option, so a
ViewComponent can be broadcast directly. That makes components technically
compatible, but each call site must be changed and tested with its initial
render. Closed-room broadcasts also pre-render HTML per user, which requires a
real view context and per-user presentation state.

Partial paths are useful compatibility seams during an incremental migration.
A partial may temporarily render a component so existing broadcasts keep
working; moving every broadcast on the first component commit would increase
risk without improving the UI.

### Fragment and collection caching

Messages, boosts, and direct-room memberships are cached by record. Their
fragments contain nested records and stable DOM targets used by broadcasts.
ViewComponent supports ordinary Rails fragment caching, but componentization
does not fix missing touch dependencies or choose a correct cache key.

Any proof of concept involving a cached item must demonstrate:

1. identical cold and warm markup;
2. invalidation after every nested state it presents changes;
3. stable DOM IDs and Turbo targets; and
4. compatible collection rendering and broadcast rendering.

The shared-room candidate is intentionally useful here because it participates
in live broadcasts without already being fragment-cached. Message migration
should wait until the approach is proven on that simpler boundary.

### Test and preview ergonomics

Current presentation assertions live mostly in controller tests, with system
tests for JavaScript behavior. There are no isolated partial/helper rendering
tests beyond content-filter helpers and no preview/gallery surface. This makes
small visual state changes require substantial page setup and makes uncommon
states hard to inspect.

ViewComponent provides isolated component tests, previews, slots, and collection
rendering. A disciplined partial alternative can use explicit locals and view
tests, but previews and a typed rendering API would need a small project-owned
harness. The proof of concept must compare the real setup cost rather than
crediting either option with hypothetical tooling.

### Upstream merge cost

Bonfire expects upstream to be most valuable as a source of security and
maintenance work rather than major new product features. Likely integrations
are dependency updates, vulnerability fixes, migrations, model invariants,
controller authorization/input handling, background jobs, and infrastructure.
The component strategy must keep those backend changes easy to review and must
not move authorization or domain behavior into presentation objects.

UI merge cost therefore matters less than explicit APIs, tests, and iteration
speed, but it is not zero. Security fixes often cross a controller and its form
or error rendering, and an upstream maintenance change can still touch shared
partials. Converting a large upstream partial creates delete/add conflicts and
makes those cross-layer patches more manual. A leaf-first hybrid can keep page
composition recognizable while extracting Bonfire-owned controls.

The sidebar shell, message, and composer are poor first conversions because
they are large, protocol-heavy, and likely to keep changing upstream. Settings
controls and room list items are bounded enough to compare without a flag-day
fork from upstream structure.

## Candidate boundaries

| Candidate | Expected value | Risk | Review disposition |
| --- | --- | --- | --- |
| Settings field/control | Explicit label/help/error/disabled API; accessible states; previews across themes | Low; ordinary form builder integration must remain ergonomic | First proof-of-concept candidate |
| Shared-room list item | Encapsulates DOM ID, sorted-list data, unread class, long names, and broadcast rendering | Medium; global/per-user stream context and ordering must remain exact | First proof-of-concept candidate |
| Icon button | Reduces repeated accessible-label/icon/touch markup | Low, but an over-general API could become class-string plumbing | Consider after settings field proves conventions |
| Direct-room item | Clear visual unit | Medium/high due caching, nested users/avatars, chronology, and unread updates | Later leaf migration |
| Message | High reuse and state value | High due cache, optimistic template, broadcasts, edit/boost targets, attachments, and authorization | Characterize first; do not use as initial proof |
| Composer | Valuable previews for online/offline/file/rich-text states | High due form builder, Trix, Stimulus outlets/events, and frame replacement | Later composition |
| Sidebar shell | Obvious visual component but owns many streams and page-level state | Very high; slots alone do not simplify its live protocols | Do not migrate first |

## Decision criteria

The proof of concept must implement the same two leaf units twice: once with
ViewComponent and once with disciplined partials using explicit locals. Score
each criterion from 1 (worse) to 5 (strong) and attach code/test evidence. A
weighted score informs the ADR but does not override a failed compatibility
gate.

| Criterion | Weight | Evidence required |
| --- | ---: | --- |
| Explicit rendering API | 5 | Required/optional inputs are visible at the call site; unknown or missing inputs fail clearly; no controller instance variables. |
| Turbo/broadcast compatibility | 5 | Initial render, `renderable:` or partial broadcast, replace/remove target, and per-user closed-room render produce identical outer DOM. |
| DOM/Stimulus preservation | 5 | Characterization assertions cover IDs, targets, values, classes, outlets, events, sorting data, and transition names. |
| Isolated tests | 4 | Light/dark-independent structural tests cover normal, unread, disabled, empty, and long-text states with minimal setup. |
| Preview/visual iteration | 4 | Both candidates can be opened in realistic states at narrow/wide widths and explicit themes without navigating the full product. |
| Accessibility | 4 | API makes labels/help/errors/state difficult to omit; keyboard and accessible-name assertions remain readable. |
| Slots/content composition | 3 | Optional icon/help/actions/content are supported without an unbounded options hash or raw HTML string API. |
| Collection rendering | 3 | Shared-room collection remains concise, ordered, preload-friendly, and free of per-item queries. |
| Caching | 3 | Cache keys/invalidation are explicit and warm/cold output is identical; no duplicate nested cache ownership. |
| CSS ownership | 3 | Candidate root/state classes have a clear stylesheet owner; solution does not claim false CSS isolation. |
| Development speed | 4 | Compare steps and time to add a new state, change markup, run a focused test, and inspect a preview. |
| Changed-file/rendering complexity | 3 | Record files/lines/call sites changed and whether wrappers/adapters are required for ordinary and broadcast rendering. |
| Maintenance cost | 4 | Naming, base class/helpers, test setup, preview setup, dependency upgrades, and debugging path are understandable to a new contributor. |
| Upstream-merge cost | 2 | Backend security/model/controller patches remain easy to integrate; upstream partial structure stays reconcilable where those patches cross into forms or errors. |

### Compatibility gates

An option cannot be adopted broadly if it fails any of these:

- no weakening of server authorization or per-user room visibility;
- exact preservation of documented Turbo/DOM/Stimulus/cache contracts;
- supported rendering from Turbo broadcasts without controller-only state;
- no query regression for collections;
- keyboard/accessibility behavior remains at least equivalent;
- current Ruby/Rails compatibility; and
- each migration remains independently deployable and reversible.

Current ViewComponent documentation supports actively supported Ruby versions
from 3.2 and Rails versions from 7.1, including Bonfire's Ruby 3.4 and Rails-main
baseline. Compatibility must be rechecked against the exact locked version
before adoption because Bonfire tracks Rails and Turbo Rails development
branches.

### Interpretation

- Choose **ViewComponent** if it wins clearly on explicit APIs, isolated tests,
  and previews without making form/broadcast rendering materially harder.
- Choose **improved partials** if explicit locals plus a small preview/test
  harness provide comparable safety with fewer files and lower upstream cost.
- Choose a **hybrid** if ViewComponent is valuable for Bonfire-owned leaf UI but
  partials remain the safer compatibility boundary for upstream-heavy page
  composition and broadcasts.

The measured proof of concept supported the hybrid hypothesis, which ADR 0001
accepts with explicit adoption boundaries. It does not approve a broad
migration.

## Proof-of-concept requirements

The next review step should cover:

1. a settings field/control with label, help, error, blank, disabled, and
   long-text states;
2. a shared-room item with normal, unread, long-name, and ordering data states;
3. explicit light/dark and narrow/wide previews;
4. isolated structural/accessibility tests;
5. initial collection rendering and a real Turbo broadcast path; and
6. a side-by-side partial implementation with the same states and assertions.

Do not convert the full sidebar, message, or composer during this experiment.
Keep existing partial paths as adapters where that reduces broadcast and
upstream risk.

## Proof-of-concept results (2026-08-08)

ViewComponent 4.12.0 was added for the proof of concept and retained by ADR
0001. No production screen renders the prototype. Development previews are
available under `/rails/view_components`:

- `prototype/settings_field_component`;
- `prototype/shared_room_item_component`; and
- `prototype/partial` for the explicit-local alternative.

Append `?theme=light|dark&viewport=mobile|desktop` to any example URL. Automated
preview tests exercise both themes/width modes across the suite; the state
examples cover normal, empty, disabled, error, long text, and unread output.

### Implemented comparison

Both approaches render semantically matching markup for:

- a data-protection settings textarea with label, help, blank value, disabled
  state, validation error, and long content; and
- a shared-room item with stable room-list ID, sorting data, Stimulus targets,
  normal/unread state, long name, collection rendering, and a real Turbo
  `replace` broadcast.

The comparison test removes only the prototype-identification attribute before
asserting equal normalized HTML. Production sidebar and settings rendering were
not changed.

### Size and setup

| Surface | ViewComponent | Explicit-local partial |
| --- | ---: | ---: |
| Runtime rendering files | 5 files / 65 lines, including `ApplicationComponent` | 2 files / 22 lines |
| Dedicated behavior tests | 2 files / 62 lines | 1 file / 79 lines |
| Preview definitions | 2 files / 62 lines | 1 file / 78 lines |
| Additional dependency | ViewComponent plus 6 Gemfile/lock lines | None |

The approaches share 91 lines of preview/equivalence tests and 31 lines of
preview layout/component CSS. File/line counts are evidence about ceremony,
not a quality score: the component classes contain named APIs and derived
accessibility state that the partial keeps inline.

The partial preview needed a small custom `render_in` adapter because
ViewComponent previews render renderable objects, not partial option hashes.
This is real project-owned preview infrastructure that would need a permanent
home if partials are chosen.

### Rendering and test ergonomics

| Question | ViewComponent result | Partial result |
| --- | --- | --- |
| Required inputs | Constructor keywords are inspectable and unknown/missing arguments fail immediately. | Locals are explicit at each call but have no central signature; missing locals fail during template rendering. |
| Isolated rendering | `render_inline(component)` is direct and keeps test setup small. | `render_in_view_context` works, but values must be captured as locals because the block runs as the view context. |
| Collection | `with_collection_parameter :room` plus `with_collection` is explicit. | Rails collection rendering is equally concise and already familiar. |
| Turbo broadcast | `renderable: component` worked with the installed Turbo Rails branch. | `partial:` plus `locals:` worked and matches current production practice. |
| Preview | A preview renders the component directly. | Matching preview states required the custom partial-renderable adapter. |
| Accessibility | Named methods centralize `aria-describedby` and error IDs. | Matching output is possible, but the derivation remains embedded in ERB. |
| CSS | No isolation advantage; both use the same root and global styles. | No isolation advantage. |
| Upstream/security work | Leaf component is unlikely to obstruct model/controller security patches, but form changes can cross the boundary. | Existing Rails form/partial structure is easiest to reconcile when an upstream security fix changes controller errors or fields. |

### Provisional scoring

Using the defined 1–5 criteria and excluding slots and caching because these two
leaf prototypes did not exercise them:

- ViewComponent: **204 / 230 weighted points**;
- explicit-local partials: **199 / 230 weighted points**.

This is not a meaningful win by itself. ViewComponent scored higher on explicit
APIs, isolated tests, previews, and accessibility-state ownership. Partials
scored higher on file count, rendering simplicity, maintenance, and upstream
reconciliation. Both passed Turbo, DOM, collection, and CSS compatibility.

### Verification

```text
bin/rails test test/components/prototype
15 runs, 63 assertions, 0 failures, 0 errors

bin/rails test
337 runs, 984 assertions, 0 failures, 0 errors, 3 skips
```

ADR 0001 retains the dependency. Manually inspect these previews before the
first production migration and replace/remove prototype artifacts once final
production contracts exist.

### What remains unanswered

- Slots were unnecessary for these leaves and remain an architectural, not
  measured, benefit.
- Neither candidate was fragment-cached; message/direct-item cache behavior is
  still characterized by existing application contracts rather than this POC.
- Preview tests verify rendered theme/viewport wrappers and states, not pixel
  diffs. Visual regression remains a later milestone.
- The experiment did not measure elapsed developer time under controlled
  repetition; changed-file count and workflow steps are the available proxies.

The evidence supports the accepted hybrid decision: ViewComponent for
Bonfire-owned, stateful leaf presentation; explicit partials for simple markup
and upstream-facing composition. ADR 0001 defines when each convention is
allowed and retains the dependency.

## Primary references

- [ViewComponent getting started](https://viewcomponent.org/guide/getting-started.html)
- [Slots](https://viewcomponent.org/guide/slots.html)
- [Collections](https://viewcomponent.org/guide/collections.html)
- [Previews](https://viewcomponent.org/guide/previews.html)
- [Testing](https://viewcomponent.org/guide/testing.html)
- [Ruby and Rails compatibility](https://viewcomponent.org/compatibility.html)
- [Turbo Rails broadcastable rendering](https://github.com/hotwired/turbo-rails/blob/main/app/models/concerns/turbo/broadcastable.rb)
