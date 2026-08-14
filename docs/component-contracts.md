# UI component contracts

Status: Accepted baseline for incremental migration under ADR 0001.

These contracts define presentation boundaries before production markup moves.
They do not require every boundary to become a ViewComponent. Bonfire uses
three rendering dispositions:

- **Leaf component:** a ViewComponent is the preferred eventual owner.
- **Partial boundary:** keep an explicit-local partial as a stable Rails/Turbo
  compatibility seam; it may render leaf components internally.
- **Container composition:** keep the page/layout/helper composition until its
  child contracts are stable. Do not wrap it in a class just to call it a
  component.

The accepted strategy and tradeoffs are in
`docs/architecture/decisions/0001-hybrid-view-components.md`. Existing DOM,
Turbo, Stimulus, cache, and accessibility contracts remain authoritative until
characterization tests explicitly permit a change.

## Rules shared by every boundary

### Presentation inputs

- Constructors/partials receive already-authorized records and explicit
  presentation state. Required inputs have no implicit fallback to controller
  instance variables.
- `Current.user` and `Current.account` may be used by page composition for
  documented request context, but leaf components must not use them to decide
  authorization, visibility, membership, or database scope.
- Components do not perform database lookup. Collections and associations are
  loaded/preloaded by controllers or queries.
- Boolean state is named for what is rendered (`unread:`, `disabled:`,
  `selected:`), not inferred from unrelated CSS classes.
- Caller-supplied arbitrary class strings are not a substitute for a component
  API. Define named variants/states; allow a small `data:` escape hatch only
  where Turbo/Stimulus integration requires it.

### Output

- One stable root is preferred for leaf components. Its DOM ID, state classes,
  data attributes, and accessible role/name are part of the public contract.
- Record identity uses `dom_id`; do not invent another ID convention.
- Decorative images are hidden from assistive technology. Icon-only controls
  always have a task-oriented accessible name.
- Light/dark, mobile/desktop, and pointer behavior are CSS concerns exercised by
  previews/tests; component Ruby code does not branch on viewport or theme.

### Domain boundary

Presentation objects must not:

- authorize users or decide installation-administrator status;
- decide room visibility/membership or fetch hidden rooms;
- persist sorting, unread, notification, message, or settings state;
- sanitize according to a domain policy that belongs at ingestion/model level;
- enqueue jobs, broadcast, or mutate records; or
- rescue domain errors in a way that changes application behavior.

They may render a caller-supplied authorized action and may expose deterministic
presentation helpers such as an accessible description ID.

### Tests and previews

Every production leaf component needs isolated structural/accessibility tests.
Add controller/integration tests for its real call site and a broadcast test if
it is rendered live. Add a preview when the state is otherwise difficult to
reach. A container stays under controller/system tests until extracted leaves
have their own coverage.

## Boundary summary

| Boundary | Disposition | Earliest migration stage |
| --- | --- | --- |
| Settings field | Leaf component | First |
| Icon button | Leaf component, narrowly scoped | First |
| Empty/error state | Leaf component for shared presentation; keep protocol-specific wrappers | First |
| Shared-room item | Leaf component behind existing partial | First |
| Notification control | Small composition after characterization | Second |
| Direct-room item | Leaf component behind cached partial | Second, after cache dependencies are fixed/tested |
| Chat message | Partial boundary containing future leaf components | Later |
| Composer | Container composition/partial | Later |
| Room list | Container composition with component collection children | Later |
| Sidebar shell | Container composition/permanent frame | Last |

## Sidebar shell

**Disposition:** container composition. Keep
`app/views/users/sidebars/show.html.erb` and
`Users::SidebarHelper#sidebar_turbo_frame_tag` as the current owners.

### Responsibility

Compose direct/shared lists, creation controls, sidebar toggle, profile/account
tools, stream subscriptions, and the permanent frame. It coordinates children;
it must not absorb their item presentation.

### Inputs

The current controller data should become an explicit render contract before
any extraction:

- `current_user:` for profile/tool presentation only;
- `direct_memberships:` already ordered and preloaded;
- `shared_memberships:` already visible/ordered and preloaded;
- `can_create_rooms:` calculated by controller/domain authorization; and
- optional tool/action slots only after repeated use proves they are needed.

Do not pass an account and ask the shell to derive `can_create_rooms:`.

### Stable output and live contracts

- permanent Turbo Frame `user_sidebar`, with `target="_top"`;
- streams `:rooms` and `[ Current.user, :rooms ]` until subscriptions are moved
  to an explicit caller;
- `direct_rooms_control`, `direct_rooms`, and `shared_rooms` IDs;
- `rooms-list`, `read-rooms`, `turbo-frame`, `badge-dot`, and `sorted-list`
  controllers/actions/classes from the helper/view;
- unpermanize-before-submit and refresh-visible reload behavior;
- sidebar toggle action and `.open` behavior supplied by the application layout;
- `new-room`, `avatar-<user.id>`, and `account-settings` transition endpoints;
  and
- profile/account tools remain navigation links with accessible names.

### Forbidden responsibility

No membership query, direct-room extraction, placeholder selection, room-create
authorization, or stream fanout decision belongs in a sidebar component.

### CSS and verification

Owners: `sidebar.css`, with layout interactions in `layout.css` and `nav.css`.
Characterize full/sidebar frame render, narrow overlay/toggle, wide persistent
layout, stream subscription presence, room-create permission, and profile/tool
links. Existing starting points are
`test/controllers/users/sidebars_controller_test.rb` and
`test/system/unread_rooms_test.rb`.

## Room list

**Disposition:** container composition. A list chooses a collection renderer;
room presentation belongs to item components.

The collection boundaries live in
`app/views/users/sidebars/rooms/_shared_list.html.erb` and
`app/views/users/sidebars/rooms/_direct_list.html.erb`. They accept explicit
locals and are composed by `app/views/users/sidebars/show.html.erb`. Individual
item partials remain the stable Turbo broadcast adapters.

Initial rendering and mutation broadcasts are characterized for shared and
direct lists: stable empty targets, alphabetical shared sort data,
timestamp-based direct sort data, unread-promotion event wiring, and exact
prepend/replace/remove targets. Keep the container as view composition until a
component provides clearer value than these existing explicit contracts.

### Responsibility and inputs

A room-list boundary accepts:

- `kind:` restricted to `shared` or `direct`;
- an already-scoped and already-preloaded `items:` collection;
- a stable target ID (`shared_rooms` or `direct_rooms`); and
- explicit empty content/action when the product needs it.

It may select the appropriate item renderer and attach `sorted-list`. It does
not order database records, decide visibility, or calculate unread state.

### Stable output

- shared list ID `shared_rooms`; direct list ID `direct_rooms`;
- `data-controller="sorted-list"`;
- shared items sort by their explicit name/order data;
- direct list retains `rooms-list:unread@window->sorted-list#updateItem`; and
- no extra wrapper may break `display: contents`, grid/flex ancestry, Turbo
  append targets, or `itemTargetConnected` sorting.

### Verification

Test empty/single/many collections, order after initial render and Turbo insert,
direct unread promotion, shared order stability, and long names. A future
persisted shared order must change the server query and client comparator/item
data together.

## Shared-room item

**Disposition:** leaf component behind
`app/views/users/sidebars/rooms/_shared.html.erb` until all broadcasts can render
the component safely. The production implementation is
`Rooms::SharedListItemComponent`; the partial remains its Turbo compatibility
adapter.

### Public API

```ruby
Rooms::SharedListItemComponent.new(
  room: room,
  unread: membership.unread?,
  sort_key: room.name,
  selected: false
)
```

`room:` must be an authorized non-direct room. `unread:` and `sort_key:` are
explicit because they can be per-user or change when persisted ordering lands.
The component may call routing/DOM helpers but performs no membership lookup.

### States

- normal and unread;
- short, empty-invalid, and very long names (model validation should prevent
  invalid names; preview may still demonstrate defensive rendering);
- open and closed room presentation when visually different in future; and
- future pinned/ordered state only through a new named input.

### Stable output

- root navigation link to `room_path(room)`;
- root ID `[ room, :list ]`;
- classes include `sidebar-list-item`, `sidebar-list-item--channel`, `room`,
  `btn`, and named unread/selected modifiers;
- `data-room-id`, `rooms-list` room target, `badge-dot` unread target, and
  `sorted-list` item target from `link_to_room`;
- explicit sorting data (`data-sorted-list-name` now, a documented order value
  later); and
- visible room name truncates without changing its accessible text.

The component does not decide whether it is broadcast globally or per user.
Controllers retain that responsibility.

### CSS and verification

Owner: shared interaction states in `community-layout.css`; shared control
primitives remain in `buttons.css`, while `sidebar.css` retains legacy shell
contracts. Isolated tests cover the DOM/data contract and states. Keep
controller broadcast tests for open, closed, involvement, rename, and destroy;
test the `renderable:` path before removing the partial adapter.

## Direct-room item

**Disposition:** leaf component behind the cached
`app/views/users/sidebars/rooms/_direct.html.erb` partial. The production
implementation is `Rooms::DirectListItemComponent`; the partial remains the
initial-render and Turbo-broadcast compatibility adapter.

### Public API

```ruby
Rooms::DirectListItemComponent.new(
  room: membership.room,
  participants: preloaded_participants,
  unread: membership.unread?,
  sort_timestamp: membership.room.updated_at,
  selected: false
)
```

Do not pass only `membership` and let the component query `room.users`. The
controller/query prepares participants excluding the viewing user and supplies
the viewing user fallback for a self-only conversation.

### States

- one participant, multiple participants, and self-only fallback;
- normal/unread;
- long/multibyte names;
- up to four displayed avatars with a deterministic overflow presentation; and
- chronological/unread-promoted order.

### Stable output and cache contract

- root ID `[ room, :list ]` and navigation through `link_to_room`;
- root classes include `sidebar-list-item` and
  `sidebar-list-item--direct`; named unread/selected modifiers,
  `data-sorted-list-number`, and all room/unread/sort targets are added by the
  component and helper;
- accessible name starts with “Ping with” and preserves full meaning even when
  visible names are abbreviated;
- avatar URLs use the fresh avatar route and decorative images remain hidden;
  and
- the adapter cache key includes the membership, room, and every presented
  participant, covering unread state, sort timestamp, names, and versioned
  fresh-avatar URLs.

Tests prove participant, membership, and room timestamp changes invalidate the
adapter key. Avatar delivery remains behind the versioned fresh-avatar route;
avatar changes touch the user and therefore also change the participant key.
Shared interaction states are owned by `community-layout.css`; direct row and
dialog presentation is owned by `direct-conversations.css`.

## Chat message

**Disposition:** partial boundary. Keep `messages/message` canonical for initial
history, pagination, refresh, optimistic reconciliation, and broadcasts. Extract
smaller leaves before considering a full `MessageComponent`.

`Messages::ActionMenuComponent` is the first production leaf. The
`messages/actions` partial remains its adapter, preserving the cached message
composition and existing partial call path.

`Messages::BoostComponent` owns an individual reaction. The
`messages/boosts/boost` partial remains its collection-cache and broadcast
adapter, with a key containing both the boost and booster presentation record.

`Messages::PresentationComponent` owns the replaceable message-body wrapper
and delegates content-type presentation to `MessagesHelper`. The
`messages/presentation` partial remains the edit-broadcast adapter.

### Responsibility and inputs

The boundary receives an already-preloaded `message:` plus explicit presentation
permissions/state that cannot be derived without policy/domain work (for
example, `can_edit:` if needed). The current query must preload creator avatar,
Action Text/embeds, attachment variants, and boosts/boosters.

It composes author/avatar/meta, timestamp/permalink, message actions,
presentation, attachment/sound/embed content, boosts, and inline-edit frame.

### States

- text/rich text, attachment, embed, sound, emoji, and unrenderable fallback;
- own/other, mentioned, threaded, first-of-day, and formatted states applied by
  the existing formatter contract;
- editable/non-editable/admin actions;
- no boosts, preset boost, custom boost, and deleting boost; and
- optimistic/pending, confirmed, failed, edited, removed, and search-highlighted
  lifecycle states.

### Stable output

- outer DOM from `MessagesHelper#message_tag`: `dom_id(message)` based on
  `client_message_id`, `.message`, reply controller, IDs/timestamps/sort values,
  messages/search/refresh targets, and `#composer` outlet;
- `[ message, :edit ]` Turbo Frame;
- `[ message, :presentation ]` with reply/messages body targets;
- `[ room, :messages ]` append destination outside the item;
- boost IDs based on the client message ID;
- `_message.html.erb` and `_template.html.erb` remain structurally compatible;
  and
- `cache message` continues to include every nested presentation dependency.

### Forbidden responsibility

No reachability authorization, edit permission lookup, filtering/sanitization
policy, bot webhook, unread/push delivery, search indexing, or broadcast occurs
inside presentation.

### CSS and verification

Owners: `messages.css`, `boosts.css`, `embeds.css`, `code.css`, and
`actiontext.css`. Characterize cold/warm render, every content type, optimistic
template equivalence, create/update/destroy broadcasts, refresh replacement,
input preservation during boosts, keyboard editing, responsive actions, and
light/dark themes before moving the full boundary.

## Composer

**Disposition:** container composition in
`app/views/rooms/show/_composer.html.erb` with form construction in
`RoomsHelper#composer_form_tag`.

The current boundary is characterized at the room-controller level. Keep it as
composition for now: its form, Trix editor, attachment queue, optimistic
message outlet, typing indicator, online/offline state, and deleted-room frame
response are one coordinated browser protocol rather than independent leaves.

### Responsibility and inputs

Accept an authorized `room:` plus explicit posting state such as
`can_post:`, `disabled_reason:`, or future announcement-room guidance. The
controller/domain layer determines whether posting is allowed. The composer
owns the message form presentation, attachment input, Trix editor, toolbar,
send action, search switch, typing indicator, and client message ID.

### States

- ready, submitting, offline, disabled/read-only, and deleted-room response;
- empty/text/rich-text body;
- attachment picked/uploading/rejected;
- toolbar open/closed;
- no typing/one or more remote typers; and
- narrow software-keyboard and wide desktop layouts.

### Stable output

- output is placed in the application `footer` slot;
- `.composer` owns `typing-notifications` and its active class;
- search transition names `input-switcher` and `input-btn`;
- Turbo Frame `composer-frame`;
- form ID `composer`, action `room_messages_path(room)`, and `#message-area`
  messages outlet;
- `composer` targets `fields`, `fileList`, `text`, and `clientid`;
- drop, paste, Trix, submit, refresh online/offline, and typing actions from
  `RoomsHelper`/rich-text helper;
- rich autocomplete URL includes the room ID; and
- accessible names remain “Write a message”, “Attach a file”, “Rich text”, and
  “Send Message”.

Do not turn the whole composer into a component until a form-builder strategy
and `content_for :footer` ownership are proven in a smaller production field.

### CSS and verification

Owners: `composer.css`, `actiontext.css`, `inputs.css`, `buttons.css`, and
autocomplete styles. Existing starting coverage is
`test/system/sending_messages_test.rb`; add online/offline, attachment,
read-only, focus/keyboard, and narrow viewport characterization before
migration.

## Settings field

**Disposition:** production leaf component. Replace the raw-name/id POC API with
a Rails-form-aware contract before adoption.

### Proposed public API

```ruby
Settings::FieldComponent.new(
  form: form,
  attribute: :data_protection_notice,
  label: "Data-protection notice",
  kind: :textarea,
  help: "Shown before signup.",
  disabled: false,
  required: false,
  autocomplete: nil,
  placeholder: nil,
  maxlength: nil,
  choices: nil
)
```

Supported `kind:` values start narrowly (`text`, `email`, `password`,
`textarea`, `select`). Reject unknown kinds. `choices:` is valid only for a
select. Do not accept unrestricted method names, arbitrary safe HTML, or a bag
of options that bypasses the contract. Add named inputs only when a real field
requires them.

### Responsibility and states

The component derives stable field/help/error IDs from the builder/attribute,
renders label and control, connects help/errors through `aria-describedby`, and
renders model errors with `aria-invalid` and an accessible error status.

States: value/blank, help/no help, error/no error, required/optional,
enabled/disabled, every supported kind, long label/help/value, and explicit
light/dark themes. The caller/model owns validation, sanitization, persistence,
and authorization.

### Stable output and CSS

- one `.settings-field` root;
- native label/control association;
- existing `.input` semantics and control size;
- deterministic help/error IDs and no empty description attributes; and
- no layout assumption beyond a documented maximum field width.

Owner: `components.css` initially, split into a named component stylesheet when
CSS ownership work establishes directories/bundling. Test every kind and error
association in isolation; integration-test real account/profile forms.

## Icon button

**Disposition:** narrowly scoped leaf component. Do not build one polymorphic
object that hides every Rails link/form behavior. The production implementation
is `Ui::IconButtonComponent`.

### Public API

```ruby
Ui::IconButtonComponent.new(
  label: "Copy join link",
  icon: "copy-paste.svg",
  variant: :default,
  type: :button,
  disabled: false,
  form: nil,
  data: {}
)
```

This component renders a native `<button>` for client actions or form
submission. Supported variants are explicit (`default`, `reversed`, `danger`,
`success`, `plain`). `icon:` must resolve through the application asset helper;
do not accept raw SVG/HTML.

Navigation remains a link or a separate future `IconLinkComponent`. Server
mutations continue to use `button_to`/forms at the call site or a dedicated
domain action component; an icon component must not hide an HTTP method or
authorization decision.

### Stable behavior

- `.btn` and named variant class;
- task-oriented accessible label via visible or screen-reader text;
- decorative icon `aria-hidden="true"`;
- current minimum hit area/focus behavior;
- native disabled state and optional form association; and
- caller-supplied Stimulus `data:` is preserved after being normalized by Rails.

Preview/test default, variants, disabled, long label, focus-visible, light/dark,
and coarse pointer. Do not make the label optional.

## Notification control

**Disposition:** small composition after existing permission/involvement flows
are characterized. It may contain separate leaf bell and involvement-button
components; do not combine browser permission with domain involvement logic in
one Ruby class. `Rooms::InvolvementButtonComponent` is the first production
leaf; the helper still owns the direct/shared involvement cycles and supplies
the current/next action explicitly. `Rooms::NotificationBellComponent` owns
the loading/alert button and its Stimulus target/action, while the partial keeps
the permission controller, lazy frame, and denial dialog composition.

### Inputs

- authorized `room:` for labels/routes only;
- explicit `involvement:` from the membership;
- `subscriptions_url:` and `involvement_url:` supplied by routing/caller;
- explicit room kind/name used for accessible copy; and
- platform/PWA help content remains partial/slot composition.

The controller/domain layer owns the allowed involvement cycle. The helper may
continue to map the next state until that mapping moves to a domain object; the
component only renders the supplied current/next action.

### States and stable output

States: capability checking/loading, permission ready, first-run attention,
permission denied/unsupported dialog, subscribed, and involvement values
`mentions`, `everything`, `nothing`, and shared-only `invisible`.

Preserve:

- `notifications` controller, subscription URL value, attention class, bell and
  not-allowed dialog targets;
- `notifications:ready` event;
- `[ room, :involvement ]` lazy Turbo Frame and `turbo-frame` load action/URL;
- `role="checkbox"`, labelled state, involvement-specific icon and accessible
  text;
- native modal dialog, close form/button, and PWA/browser/system help; and
- different involvement options for direct/shared rooms supplied by domain
  logic, not inferred in presentation.

Tests need permission unsupported/default/denied/granted behavior, subscription
sync failure, every involvement value, direct/shared allowed cycles, dialog
focus/close, frame lazy load, and sidebar visibility broadcast effects.

## Empty and error states

**Disposition:** leaf component for shared presentation only. Protocol-specific
wrappers remain with their owning screen.

### Proposed public API

```ruby
Ui::StateComponent.new(
  kind: :empty,
  title: "No rooms yet",
  message: nil,
  icon: "messages-empty.svg",
  announce: false
)
```

Optional action content may be a constrained slot. Supported kinds start with
`empty`, `error`, and `unavailable`; do not create variants for arbitrary color
choices. Text is escaped. Rich/domain content must be sanitized before it is
passed or rendered through a dedicated component.

### Stable behavior

- native heading level is supplied by context or the component exposes a
  constrained `heading_level:`; do not create an incorrect page hierarchy;
- decorative icon hidden, or meaningful image alternative text explicit;
- static empty state is not announced automatically;
- newly inserted actionable failure uses an appropriate status/alert role;
- empty action remains keyboard accessible; and
- kind maps to semantic classes/tokens rather than literal colors.

The shared component can replace repeated visual shells such as welcome/search
empty states. It must not replace:

- `messages/unrenderable`, whose message-shaped DOM protects list formatting;
- `messages/room_not_found`, whose `composer-frame` target is a protocol; or
- flash markup in the application layout, whose live announcement behavior is
  global.

Those wrappers may render a shared state body internally after tests preserve
their outer contracts.

### CSS and verification

Owner: a state section in `components.css`, using semantic color/surface tokens.
Preview empty/error/unavailable, with/without message/action, long text,
light/dark, and narrow/wide. Test escaping, heading/role behavior, accessible
name, and protocol adapters separately.

## Migration order and exit criteria

1. Turn the settings-field POC into the first production component and use it
   in one account/profile form.
2. Establish the icon-button and state primitives only from real call sites;
   avoid speculative variant APIs.
3. Replace the shared-room POC with the production API behind the existing
   `_shared` partial; prove initial and all broadcast paths.
4. Characterize and extract notification leaves.
5. Fix/prove direct-item cache invalidation before extraction.
6. Extract message leaves (actions, boosts, attachment presentation) before the
   full message boundary.
7. Reassess composer, room-list containers, and sidebar shell last.

A boundary is ready for production migration only when:

- inputs/states and forbidden responsibilities match this document;
- existing DOM/Turbo/Stimulus/cache contracts have characterization tests;
- component isolated tests and representative previews exist;
- initial, Turbo response, refresh, and broadcast rendering agree;
- both themes and narrow/wide/pointer states have been inspected; and
- the change can be reverted without reverting an unrelated feature.
