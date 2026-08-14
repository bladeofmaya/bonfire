# Bonfire agent guide

This file is the starting point for agents and contributors changing Bonfire.
It describes the architecture that exists today. Read the relevant code before
acting; this guide is a map, not a substitute for verifying an implementation.

## Product and repository

Bonfire is a self-hosted, single-tenant community chat derived from Basecamp's
Campfire. It is being developed independently while retaining an `upstream`
remote for selected fixes. Bonfire-specific product direction lives in
`TODO.md` (intentionally local/ignored at the time of writing).

The main fork branch is `master`; upstream work is based on `upstream/main`.
Do not rename external upstream identifiers or overwrite Bonfire changes while
resolving an upstream merge.

## Stack at a glance

- Ruby 3.4 and Rails 8.2 (currently tracking the Rails `main` branch)
- SQLite for application data in every environment
- Active Storage on local disk for uploads and generated variants
- Redis for Rails cache, Action Cable, and Resque
- Resque/Resque Pool for background jobs
- Puma behind Thruster in the production container
- ERB views, Turbo Frames/Streams, Stimulus, Trix, and Action Text
- Propshaft and import maps; there is no Node build step
- Kamal for the repository's guided deployment workflow

The Docker image is intentionally self-contained: web, workers, Redis, file
serving, and application dependencies run on one server. Persistent state is
mounted at `/rails/storage` in production.

## Runtime architecture

### Request and authentication flow

`config/routes.rb` is the route map. All application controllers inherit from
`ApplicationController`, which composes the cross-cutting concerns in
`app/controllers/concerns/`:

- `Authentication` restores a signed session cookie, accepts scoped bot-key
  authentication where allowed, and rejects bots from normal browser actions.
- `Authorization` provides the account-administrator guard.
- `BlockBannedRequests`, `AllowBrowser`, `SetPlatform`, `SetCurrentRequest`,
  `TrackedRoomVisit`, and `VersionHeaders` add request-wide behavior.
- `RoomScoped` resolves a room through the current user's membership. Prefer it
  when an endpoint must never reach a room the user cannot access.

`Current` (`app/models/current.rb`) carries the request, session, and user.
Assigning `Current.session` also assigns `Current.user`. The installation is
single-tenant: `Current.account` returns `Account.first`. Code must not assume
that an account ID arrives in the URL.

The first-run flow creates the singleton account and initial administrator.
Start at `FirstRunsController`, `FirstRun`, and
`app/views/first_runs/show.html.erb` when changing initial setup.

### Core domain model

- `Account` is the singleton installation record. It owns the account logo,
  custom CSS, join code behavior, and JSON-backed account settings.
- `User` owns sessions, messages, memberships, searches, boosts, bans, push
  subscriptions, and an optional avatar. User concerns implement roles, bots,
  banning, mentions, avatars, and account transfer behavior.
- `Room` owns memberships and messages. It uses STI:
  - `Rooms::Open` grants membership to every active user.
  - `Rooms::Closed` grants membership only to selected users.
  - `Rooms::Direct` is private to an exact participant set and must never be
    converted into an open or closed room.
- `Membership` joins users to rooms and stores notification involvement,
  unread state, and presence/connection state.
- `Message` belongs to a room and creator, stores its body through Action Text,
  optionally has a file attachment, and coordinates broadcasts, search,
  mentions, pagination, boosts, and push delivery through concerns.
- `Boost` is a reaction; `Search` represents saved/current search state;
  `Push::Subscription` stores Web Push subscriptions; `Webhook` and bot jobs
  handle outbound bot integrations.

Preserve these invariants when changing controllers or UI flows:

- Resolve rooms through `Current.user.rooms` or a membership, not `Room.find`.
- Direct-room history must not become visible by converting its STI type.
- Open/closed membership changes and room-list broadcasts must agree.
- A message is not complete at database insertion alone: receive/unread, push,
  webhook, Turbo broadcast, and search behavior may also apply.
- Authorization must be enforced server-side even when the UI hides a control.
- Room-level administration can include a room's creator; installation-wide
  administrator-only actions are stricter. Do not reuse a room administration
  guard without verifying which role the feature requires.

### Persistence and external state

`config/database.yml` points SQLite databases at `storage/db/`. Uploaded files
live under `storage/files/`; tests use `tmp/storage/`. Production uses the
`:local` Active Storage service. Back up the whole production storage mount,
using the provided backup hook so SQLite is captured consistently.

Redis is not the source of truth. It backs caching, Action Cable, and Resque.
Action Cable channel prefixes live in `config/cable.yml`; worker configuration
lives in `config/resque-pool.yml`.

Never print, commit, or replace secrets from `.kamal/secrets`, Rails
credentials, `config/master.key`, deployment environment files, VAPID keys, or
bot keys. Examples may document key names, never real values.

## Realtime and background work

Message creation starts in `MessagesController#create` and the `Message`
concerns. `Message::Broadcasts` appends rendered messages to the room stream and
fans unread events out per user. `Room#receive` updates disconnected
memberships and schedules Web Push.

Important realtime entry points:

- `app/channels/application_cable/connection.rb` authenticates sockets from
  the browser session.
- `RoomMessagesChannel` authorizes Turbo message streams against current room
  membership. Do not replace it with an unguarded Turbo stream.
- `RoomChannel` is the membership-checked base for room-specific channels.
- `PresenceChannel` maintains membership connection counters and read state.
- `UnreadRoomsChannel` and `ReadRoomsChannel` are scoped per user.
- `TypingNotificationsChannel` broadcasts ephemeral typing state.
- `presence_controller.js`, `rooms_list_controller.js`,
  `read_rooms_controller.js`, `refresh_room_controller.js`, and
  `typing_notifications_controller.js` create the matching browser
  subscriptions through the Action Cable helper.

Background jobs live in `app/jobs/`. The current high-value paths are Web Push
(`Room::PushMessageJob`), bot webhooks (`Bot::WebhookJob`), and banned-content
cleanup. Production uses Resque; tests may execute jobs differently according
to test configuration.

## Frontend architecture

### Rendering model

The application is server-rendered ERB with Turbo and Stimulus enhancement.
`app/views/layouts/application.html.erb` owns the document shell, theme startup,
global navigation/sidebar slots, assets, flash messages, and global Stimulus
controllers. `app/javascript/application.js` imports Turbo, Trix, Action Text,
initializers, and eagerly registered controllers through `config/importmap.rb`.

ViewComponent is retained under the accepted hybrid decision; its current
implementations in `app/components/prototype/` remain non-production decision
evidence. Production adoption begins with reusable leaf components such as
`Rooms::SharedListItemComponent`; container composition remains in partials and
helpers. Some partial paths are called directly from Turbo broadcasts, so treat
a partial rename as a runtime change, not housekeeping.
The evidence and decision criteria are in `docs/view-component-review.md`; the
accepted hybrid boundaries are in
`docs/architecture/decisions/0001-hybrid-view-components.md`. The decision
allows selective leaf components, not a broad production migration.
Concrete contracts and migration ordering for each major UI boundary are in
`docs/component-contracts.md`; read the relevant contract before extracting
production markup.

### ViewComponent conventions

Use ViewComponent only for a leaf boundary that meets the ADR criteria. Every
production component inherits from `ApplicationComponent` and lives in a
product-area namespace. Keep its Ruby class and template side by side:

```text
app/components/rooms/shared_list_item_component.rb
app/components/rooms/shared_list_item_component.html.erb
test/components/rooms/shared_list_item_component_test.rb
test/components/previews/rooms/shared_list_item_component_preview.rb
```

The class name for that example is `Rooms::SharedListItemComponent`. Name a
component for the UI responsibility it owns, not the model it happens to
receive. Do not add `Component` namespaces, generic `Common`/`Shared` buckets,
or component-local JavaScript/CSS directories. Existing styles remain in
`app/assets/stylesheets/`, and Stimulus controllers remain in
`app/javascript/controllers/` with ownership documented in the component
contract.

Constructors accept already-authorized records and explicit presentation state:

```ruby
class Rooms::SharedListItemComponent < ApplicationComponent
  def initialize(room:, unread: false, sort_key: room.name)
    @room = room
    @unread = unread
    @sort_key = sort_key
  end
end
```

Do not query, authorize, persist, broadcast, or enqueue work from a component.
Prefer named boolean/variant arguments over arbitrary caller-provided CSS
classes. Preserve documented DOM IDs, Turbo/Stimulus attributes, cache inputs,
and accessible names.

Component tests inherit from `ComponentTestCase`, call `render_inline`, and
assert structure rather than full HTML strings. Shared assertions include
`assert_component_root`, `assert_icon_button`, and
`assert_stimulus_contract`. Add a controller/integration or broadcast test for
the production call path; an isolated component test does not replace it.

Previews live under `test/components/previews/`, mirror the component namespace,
and inherit from `ViewComponent::Preview`. The shared `component_preview`
layout is configured globally and supports `?theme=light|dark` and
`?viewport=mobile|desktop`. In development, browse previews at
`/rails/view_components`. Include meaningful named states such as default,
unread, disabled, error, empty, and long content instead of a single happy-path
example.

High-risk page compositions have element-scoped baselines under
`test/visual_baselines/`. Run `test/system/visual_regression_test.rb` after UI
changes. Regenerate with `UPDATE_VISUAL_BASELINES=1` only after inspecting the
result and commit the changed image with the intentional UI change.

CSS ownership, known cascade hazards, stable token families, and the migration
order are documented in `docs/css-architecture.md`. Read it before moving
selectors, changing global custom properties, or altering stylesheet loading.
Use `.settings-group` with a direct `.settings-group__legend` for settings
fieldsets; the unclassed fieldset fallback exists only for unmigrated flows.
Use `Ui::IconButtonComponent` for native icon-only buttons, or `.btn--icon`
when a non-button element or established component owns the interaction. Do
not rely on hidden text and image descendants to determine button geometry.

Milestone 1 readiness and the extension contract for future channel pinning or
reordering are recorded in `docs/feature-readiness.md`. Ordering changes must
update the membership query, item sort data, broadcasts, and Stimulus
comparator together.

### UI change map

Start with the matching area below, then search for every listed DOM ID,
partial path, and Stimulus identifier before changing markup. “Live contracts”
are dependencies that may update a screen after its initial render; test them
as well as the ordinary request.

#### Application layout and navigation

- **Views:** `app/views/layouts/application.html.erb` owns the document shell,
  global sidebar and navigation slots, flashes, lightbox, PWA metadata, and
  global Stimulus bindings. Room navigation is in
  `app/views/rooms/show/_nav.html.erb`.
- **Server:** `ApplicationController` prepares global request context;
  `app/helpers/application_helper.rb` supplies shared layout helpers, while
individual screens fill the layout's `content_for` slots.

UI tokens, supported primitive variants, interaction states, utility usage,
and stylesheet ownership are documented in `docs/ui-style-guide.md`. Read it
before introducing a new UI class or variant.
- **Browser and styles:** `local_time_controller.js`,
  `lightbox_controller.js`, `theme_controller.js`, and
  `toggle_class_controller.js`; start with `layout.css`, `nav.css`, `base.css`,
  and `utilities.css`.
- **Live contracts:** preserve the `main`, `nav`, and `aside` slots, the
  permanent sidebar frame, body-level controller bindings, and early theme
  initialization. Room navigation also owns the edit-room view-transition
  name.
- **Tests:** there is no isolated layout test. Use the controller or system test
  for the screen being changed; `test/controllers/rooms_controller_test.rb`
  covers the main room shell and `test/controllers/welcome_controller_test.rb`
  covers the signed-out entry point.

#### Sidebar shell

- **Views:** `app/views/users/sidebars/show.html.erb` composes the shell;
  `app/views/users/sidebars/rooms/_shared_list.html.erb` and `_direct_list.html.erb`
  own the collection containers through explicit locals.
- **Server and helper:** `Users::SidebarsController` and
  `app/helpers/users/sidebar_helper.rb`.
- **Browser and styles:** `rooms_list_controller.js`,
  `read_rooms_controller.js`, `turbo_frame_controller.js`,
  `badge_dot_controller.js`, and `sorted_list_controller.js`; use
  `sidebar.css`, `layout.css`, and `nav.css`.
- **Live contracts:** `sidebar_turbo_frame_tag` creates the permanent
  `user_sidebar` frame and subscriptions to user room/read events. The view
  subscribes to the global and per-user room streams and contains the
  `shared_rooms`, `direct_rooms_control`, and `direct_rooms` targets.
- **Tests:** `test/controllers/users/sidebars_controller_test.rb` and
  `test/system/unread_rooms_test.rb`. Controller coverage asserts stable empty
  targets, initial shared/direct sort data, unread-promotion wiring, and the
  permanent frame contract; mutation-controller tests assert exact rendered
  stream actions and targets.

#### Shared-room list

- **View:** `app/views/users/sidebars/rooms/_shared.html.erb`, rendered by the
  sidebar and by room visibility broadcasts.
- **Server and helper:** `Users::SidebarsController` starts from
  `Membership.with_ordered_room`; mutation and broadcast writers are
  `Rooms::OpensController`, `Rooms::ClosedsController`,
  `Rooms::InvolvementsController`, and `RoomsController`.
  `RoomsHelper#link_to_room` builds each entry's shared data contract.
- **Browser and styles:** `rooms_list_controller.js`,
  `badge_dot_controller.js`, and `sorted_list_controller.js`; use
  `sidebar.css` and `buttons.css`. Shared entries currently expose
  `data-sorted-list-name` and are alphabetized by the Stimulus controller;
  numeric descending sorting is used by direct rooms instead.
- **Live contracts:** the collection target is `shared_rooms`; each entry uses
  `[ room, :list ]` for its DOM ID. Open, closed, involvement, and destroy
  actions prepend, replace, or remove this exact partial and target. A prepend
  position is temporary because `sorted_list_controller.js` re-sorts every
  connected item. Persisted ordering must update both the initial membership
  query and the partial/controller sorting data.
- **Tests:** `test/controllers/rooms/opens_controller_test.rb`,
  `test/controllers/rooms/closeds_controller_test.rb`,
  `test/controllers/rooms/involvements_controller_test.rb`,
  `test/controllers/rooms_controller_test.rb`, and
  `test/system/unread_rooms_test.rb`.

#### Direct-room list

- **Views:** `app/views/users/sidebars/rooms/_direct.html.erb` and
  `_direct_placeholder.html.erb`; creation starts in
  `app/views/rooms/directs/new.html.erb`.
- **Component:** `Rooms::DirectListItemComponent` owns a rendered direct-room
  entry. The `_direct` partial owns its dependency-complete fragment cache and
  remains the broadcast adapter. `Rooms::DirectPlaceholderComponent` owns a
  suggested participant action behind `_direct_placeholder`; it remains
  outside `direct_rooms` because it is not a sortable room.
- **Server and helper:** `Rooms::DirectsController`,
  `Autocompletable::UsersController`, and `RoomsHelper#link_to_room`.
- **Browser and styles:** `autocomplete_controller.js`,
  `rooms_list_controller.js`, `badge_dot_controller.js`, and
  `sorted_list_controller.js`; use `sidebar.css` and `autocomplete.css`.
- **Live contracts:** `direct_rooms_control` wraps the creation control and
  `direct_rooms`; successful creation prepends the `direct` partial to
  `direct_rooms`. Preserve room membership scoping and the Direct STI type.
- **Tests:** `test/controllers/rooms/directs_controller_test.rb`,
  `test/controllers/autocompletable/users_controller_test.rb`, and
  `test/system/unread_rooms_test.rb`.

#### Chat message

- **Views:** `app/views/messages/_message.html.erb` owns the outer message DOM;
  `_presentation.html.erb`, `_actions.html.erb`, and `_template.html.erb` own
  its content, controls, and streamed template. Boost UI is under
  `app/views/messages/boosts/`.
- **Component:** `Messages::ActionMenuComponent` owns the confirmed message
  popup, quick boosts, reply/download/share, copy-link, and edit controls.
  `_actions.html.erb` remains its adapter inside the cached message boundary;
  the optimistic `_template.html.erb` retains its non-interactive shell.
  `Messages::BoostComponent` owns one rendered reaction behind the cached and
  broadcast `messages/boosts/boost` adapter.
  `Messages::PresentationComponent` owns the replaceable body wrapper behind
  the `messages/presentation` update-broadcast adapter; content filtering and
  attachment/sound selection remain in `MessagesHelper`.
- **Server and helper:** `MessagesController`, `Messages::BoostsController`,
  `app/helpers/messages_helper.rb`, and
  `app/helpers/messages/attachment_presentation.rb`.
- **Browser and styles:** `messages_controller.js`, `reply_controller.js`,
  `maintain_scroll_controller.js`, `refresh_room_controller.js`,
  `popup_controller.js`, `soft_keyboard_controller.js`, and
  `web_share_controller.js`; use `messages.css`, `boosts.css`, `embeds.css`,
  `code.css`, and `actiontext.css`.
- **Live contracts:** `message_tag` sets message IDs, timestamps, sorting data,
  controller targets, and the composer outlet. `Message::Broadcasts` appends
  `_message` to `[ room, :messages ]`; update and destroy paths replace or
  remove the same DOM identity. `RoomMessagesChannel` guards the stream.
- **Tests:** `test/controllers/messages_controller_test.rb`,
  `test/controllers/messages/boosts_controller_test.rb`,
  `test/system/sending_messages_test.rb`,
  `test/system/boosting_messages_test.rb`, and
  `test/channels/room_messages_channel_test.rb`.

#### Composer

- **View:** `app/views/rooms/show/_composer.html.erb`, inside
  `app/views/rooms/show.html.erb`.
- **Server and helper:** `MessagesController#create`,
  `UnfurlLinksController`, `Autocompletable::UsersController`, and
  `RoomsHelper#composer_form_tag`.
- **Browser and styles:** `composer_controller.js`,
  `drop_target_controller.js`, `typing_notifications_controller.js`,
  `rich_autocomplete_controller.js`, and `refresh_room_controller.js`; use
  `composer.css`, `actiontext.css`, `inputs.css`, and `autocomplete.css`.
- **Live contracts:** keep the `composer` ID, its `#message-area` outlet, room
  ID value, Trix events, drop events, and typing channel aligned. The enclosing
  `message-area` and `[ room, :messages ]` elements are built by
  `MessagesHelper`. A failed submit to a deleted/inaccessible room explicitly
  renders the HTML `composer-frame` fallback even when Turbo requested a stream
  response; preserve that format override.
- **Tests:** `test/controllers/messages_controller_test.rb`,
  `test/controllers/unfurl_links_controller_test.rb`,
  `test/controllers/autocompletable/users_controller_test.rb`, and
  `test/system/sending_messages_test.rb`.

#### Room settings

- **Views:** shared room form structure is under `app/views/rooms/layouts/`;
  type-specific screens are under `app/views/rooms/opens/`,
  `app/views/rooms/closeds/`, and `app/views/rooms/directs/`.
- **Server and helper:** `RoomsController`, `Rooms::OpensController`,
  `Rooms::ClosedsController`, `Rooms::DirectsController`, and
  `app/helpers/rooms_helper.rb`.
- **Browser and styles:** `form_controller.js`,
  `autocomplete_controller.js`, and `filter_controller.js`; use `inputs.css`,
  `buttons.css`, `panels.css`, and `autocomplete.css`.
- **Live contracts:** room type changes affect authorization, membership, and
  sidebar broadcasts. Preserve `[ room, :list ]`, the edit-room
  view-transition name, and the exact shared/direct sidebar partial paths.
- **Tests:** `test/controllers/rooms_controller_test.rb` plus the open, closed,
  and direct controller tests under `test/controllers/rooms/`.

#### Account settings

- **Views:** `app/views/accounts/edit.html.erb` is the hub. Related screens and
  partials live under `app/views/accounts/`, including logos, users, custom
  styles, join codes, and bots.
- **Server and helper:** `AccountsController`, `Account`, the controllers under
  `app/controllers/accounts/`, `app/helpers/accounts_helper.rb`, and shared
  form helpers. Keys stored in `accounts.settings` must be declared in
  `Account`'s `has_json` schema; the JSON column is not a schemaless bag of
  accepted settings. Adding a declared key does not itself require a migration
  while that JSON column remains the storage boundary.
- **Browser and styles:** `form_controller.js`,
  `upload_preview_controller.js`, `copy_to_clipboard_controller.js`, and
  `filter_controller.js`; use `inputs.css`, `buttons.css`, `panels.css`, and
  `avatars.css`.
- **Live contracts:** account logo changes feed both ordinary image rendering
  and PWA icons. Custom CSS is injected after application styles; keep stable
  CSS variables and selectors available to installations that override them.
  Account updates use an ordinary redirect, not a feature-specific broadcast.
  When a setting is consumed elsewhere, inspect and test every consumer.
  The READMErmation document is an `Account` Action Text association,
  rather than a global record or undeclared JSON key, because an installation
  has one singleton account and one currently published rules document. Publishing or
  clearing it updates version, digest, and timestamp metadata; only
  installation administrators may mutate it.
- **Tests:** `test/controllers/accounts_controller_test.rb` and the focused
  tests under `test/controllers/accounts/`; add consumer tests as well when a
  setting changes another screen.

#### Signup and join

- **View:** `app/views/users/new.html.erb` renders signup reached through an
  account join code. First-run account creation is a distinct flow in
  `app/views/first_runs/show.html.erb` and should only change when the product
  requirement applies to both flows.
- **Server and helper:** `UsersController#new`/`create`, `Current.account`, and
  the join-code route in `config/routes.rb`. Account-provided content comes
  from the declared `Account#settings` schema.
- **Browser and styles:** `upload_preview_controller.js` and
  `form_controller.js`; use `signup.css`, `inputs.css`, and `buttons.css`.
- **Live contracts:** signup is unauthenticated and requires a valid account
  join code. It is an ordinary request render with the application navigation
  slot and `.signup`/`.nametag` layout. Treat administrator-provided public copy
  as untrusted content: render it escaped or deliberately sanitized and define
  the blank state so empty settings do not create empty UI chrome.
  When READMErmation is published, signup requires server-validated
  acceptance of the server rules and copies its version/digest, acceptance timestamp,
  and request IP onto the new user. Keep user creation and that metadata in the
  same database write; never rely on the browser's `required` attribute alone.
- **Tests:** `test/controllers/users_controller_test.rb`; cover configured and
  blank optional content as well as the existing join/access rules.

#### User profile

- **Views:** `app/views/users/profiles/show.html.erb`, `_membership.html.erb`,
  and `_transfer.html.erb`.
- **Server and helper:** `Users::ProfilesController`,
  `Users::AvatarsController`, `Sessions::TransfersController`, and
  `app/helpers/users/profiles_helper.rb`.
- **Browser and styles:** `form_controller.js`,
  `upload_preview_controller.js`, `sessions_controller.js`,
  `web_share_controller.js`, and `theme_controller.js`; use `avatars.css`,
  `inputs.css`, `panels.css`, and `separators.css`.
- **Live contracts:** profile membership links are room-scoped, avatar previews
  depend on the upload target markup, and the Appearance fieldset owns the
  persisted theme selector.
- **Tests:** `test/controllers/users/profiles_controller_test.rb`,
  `test/controllers/users/avatars_controller_test.rb`,
  `test/controllers/sessions/transfers_controller_test.rb`, and
  `test/system/theme_test.rb`.

#### Theme

- **Views:** the blocking startup script and root binding are in
  `app/views/layouts/application.html.erb`; the user control is the Appearance
  fieldset in `app/views/users/profiles/show.html.erb`.
- **Server and helper:** `Users::ProfilesController` renders the preference
  control, but the choice is browser-local and does not require a model update.
- **Browser and styles:** `theme_controller.js` manages the `bonfire-theme`
  local-storage value and root `data-theme`; `colors.css` defines both palettes.
  Shared stylesheets consume the semantic color properties.
- **Live contracts:** the inline startup script must run before styles paint and
  agree with the Stimulus controller. Support `light`, `dark`, and the absent
  value used for the system preference.
- **Tests:** `test/system/theme_test.rb`; also inspect changed screens manually
  in both explicit themes and with the system setting.

#### PWA

- **Views:** `app/views/pwa/manifest.json.erb`, `service_worker.js`, and the
  install/browser/system instruction partials under `app/views/pwa/`.
- **Server and helper:** `PwaController`; there is no dedicated PWA helper.
  Application layout metadata and account logo routes provide manifest and
  icon context.
- **Browser and styles:** `pwa_install_controller.js`; PWA instruction styles
  currently live in `base.css` with responsive visibility utilities in
  `utilities.css`.
- **Live contracts:** keep the manifest and service-worker routes, layout link
  tags, scope/start URL, icon URLs, and account logo fallbacks aligned.
- **Tests:** there is currently no focused PWA controller/system test. Cover
  logo behavior with `test/controllers/accounts/logos_controller_test.rb` and
  add focused PWA coverage when changing manifest, install, or worker behavior.

#### Notification controls

- **Views:** `app/views/rooms/involvements/_bell.html.erb` and `show.html.erb`
  control per-room involvement; Web Push setup lives under
  `app/views/users/push_subscriptions/`.
- **Component:** `Rooms::InvolvementButtonComponent` renders the current
  involvement state and its supplied next action. The helper retains ownership
  of the distinct direct/shared cycles and all routing inputs.
  `Rooms::NotificationBellComponent` renders the initial permission/loading
  trigger; the surrounding partial retains the browser-permission controller,
  lazy Turbo Frame, and denial dialog.
- **Server and helper:** `Rooms::InvolvementsController`,
  `Users::PushSubscriptionsController`,
  `Users::PushSubscriptions::TestNotificationsController`, and
  `app/helpers/rooms/involvements_helper.rb`.
- **Browser and styles:** `notifications_controller.js`,
  `presence_controller.js`, `read_rooms_controller.js`,
  `rooms_list_controller.js`, and `turbo_frame_controller.js`; use
  `buttons.css`, `sidebar.css`, and `base.css`.
- **Live contracts:** involvement uses the `[ room, :involvement ]` frame and
  cycles through a different allowed state list for direct rooms. Notification
  permission loads that frame; presence/read/unread channels update membership
  state and sidebar badges. Invisible involvement also changes room-list
  broadcasts.
- **Tests:** `test/controllers/rooms/involvements_controller_test.rb`,
  `test/controllers/users/push_subscriptions_controller_test.rb`,
  `test/models/room/push_test.rb`,
  `test/channels/presence_channel_test.rb`,
  `test/channels/unread_rooms_channel_test.rb`, and
  `test/system/unread_rooms_test.rb`.

### Turbo and DOM contracts

Many UI identifiers are protocol surfaces shared by Rails, Turbo broadcasts,
Stimulus, fragment caches, and CSS. They are not private markup details. Before
renaming one, use `rg` to find both its producer and every consumer, then update
the initial render, Turbo response, broadcast, refresh/reconnect path, and test
together.

#### Turbo Frame IDs

| Frame | Producer and consumers | Contract |
| --- | --- | --- |
| `user_sidebar` | `Users::SidebarHelper#sidebar_turbo_frame_tag`, the application sidebar slot, and links targeting the sidebar | It is `data-turbo-permanent`, defaults navigation to `_top`, and is reloaded by `turbo-frame_controller.js`. Keep its permanence and unpermanize-before-submit behavior aligned. |
| `direct_rooms_control` | `app/views/users/sidebars/show.html.erb` and `app/views/rooms/directs/new.html.erb` | Opening “Ping” replaces this frame in place; cancel targets `user_sidebar`. The frame must continue to contain the `direct_rooms` stream target when showing the normal sidebar. |
| `composer-frame` | `app/views/rooms/show/_composer.html.erb` and `app/views/messages/room_not_found.html.erb` | Message submission responses can replace the composer state without replacing the surrounding `composer` form and message area contracts. |
| `[ room, :involvement ]` | `Rooms::InvolvementsHelper`, the bell partial, and profile membership rows | Notification readiness lazily loads this frame. The same ID must be used in the room navigation and profile list. |
| `[ message, :edit ]` | `app/views/messages/_message.html.erb`, `edit.html.erb`, and message action links | Inline edit and cancel responses replace this exact region. The outer message ID remains stable for sorting and removal. |
| `[ message, :boosting ]`, `[ message, :new_boost ]` | `app/views/messages/boosts/_boosts.html.erb`, `new.html.erb`, and message actions | Boost creation unsubscribes/reconnects the nested Turbo stream and appends into the boost list; keep the two frame roles distinct. |
| `account_users`, `next_page_container` | account edit and `app/views/accounts/users/index.turbo_stream.erb` | Lazy pagination replaces the sentinel and appends the next sentinel inside `account_users`. |

When introducing a frame, document whether links/forms should navigate inside
it, target `_top`, or target another frame. A matching ID alone does not
preserve navigation semantics.

#### Turbo Stream targets and broadcast partials

| Target or stream | Writers | Rendered contract |
| --- | --- | --- |
| `shared_rooms` and `[ room, :list ]` | open, closed, involvement, and room-destroy controllers | `users/sidebars/rooms/shared` is prepended/replaced; removal uses the room-list DOM ID. The global `:rooms` stream reaches every sidebar, while `[ user, :rooms ]` is user-specific. Closed-room visibility, invisible involvement, and unread markup are user-specific, so do not globally replace the whole list with one user's HTML. |
| `direct_rooms` and `[ room, :list ]` | `Rooms::DirectsController` | `users/sidebars/rooms/direct` is prepended to each member's room stream. Its local is named `membership`, not `room`. |
| `[ room, :messages ]` on the guarded room message stream | `Message::Broadcasts`, message create responses, and room refresh responses | `messages/message` is the canonical full-message partial. Initial history, create, reconnect refresh, and live broadcast must produce compatible DOM. |
| `[ message, :presentation ]` | `MessagesController#update` | Only `messages/presentation` is replaced, with `maintain_scroll` stream attributes. Do not move the presentation ID outside this partial without changing the update target. |
| the message's outer DOM ID | message destroy, banned-user cleanup, and refresh replacement | `Message#to_key` is based on `client_message_id`, so DOM identity survives optimistic/client rendering. Do not substitute a database-ID-only convention. |
| `boosts_message_<client_message_id>` and a boost's DOM ID | `Messages::BoostsController` | Creation appends `messages/boosts/boost`; destroy removes the boost by DOM identity. The client message ID connects the cached message markup to the broadcast target. |
| `account_users` and `next_page_container` | account user pagination | The response replaces the current sentinel with user rows, then appends a new sentinel when another page exists. |

Broadcast partial paths are executable API names. Search for
`broadcast_*`, `turbo_stream.*`, and `render_to_string` before moving or
renaming a partial. Preserve local names and preload any associations the
partial reads. Do not weaken `RoomMessagesChannel` authorization by replacing
the guarded room stream with a plain model stream.

#### Stable DOM and Stimulus APIs

The following IDs and data attributes are shared across helpers, views, and
JavaScript:

- `message-area`, `composer`, `[ room, :messages ]`, and
  `[ message, :presentation ]` connect `MessagesHelper`, `RoomsHelper`, the
  composer, message formatting, scrolling, presence, drop handling, and
  refresh controllers.
- `shared_rooms`, `direct_rooms_control`, `direct_rooms`, `user_sidebar`, and
  `[ room, :list ]` connect sidebar rendering, sorting, unread state, and room
  broadcasts.
- Message elements expose `data-user-id`, `data-message-id`, timestamps, sort
  values, and `messages`, `refresh-room`, `reply`, and search targets. Keep
  `app/views/messages/_message.html.erb` and `_template.html.erb` structurally
  compatible; the latter creates the client-side optimistic message shell.
- Stimulus declarations are public contracts: `data-controller`,
  `data-action`, `*-target`, `*-value`, `*-class`, and `*-outlet` names must
  match the controller's `static targets`, `values`, `classes`, and `outlets`.
  Renaming a JavaScript property changes its kebab-case HTML API.
- Custom events are APIs too. Current cross-controller flows include
  `rooms-list:read`, `rooms-list:unread`, `presence:present`,
  `notifications:ready`, `refresh-room:visible`, `refresh-room:online`,
  `refresh-room:offline`, `drop-target:drop`, and message playback events.
  Check dispatchers and `@window`/`@document` listeners together.

Helpers such as `message_area_tag`, `messages_tag`, `message_tag`,
`composer_form_tag`, `link_to_room`, `sidebar_turbo_frame_tag`, and
`turbo_frame_for_involvement_tag` centralize these attributes. Extend the
helper instead of duplicating a nearly matching contract in a view.

#### Fragment and collection-cache dependencies

Cached partials must produce the same DOM contract as uncached and broadcast
renders:

- Messages are collection-cached in room history, message pagination, and room
  refresh, and `_message.html.erb` also uses `cache message`. That fragment
  includes creator presentation, message presentation, actions, and boosts.
  Boost changes invalidate it because `Boost` touches `Message`; message
  changes touch `Room`. If new nested state does not touch the message, add it
  to the cache key or establish an explicit touch dependency.
- Direct-room entries are cached in `_direct.html.erb` using the membership,
  room, and presented participant records. This covers membership unread state,
  room ordering timestamps, participant names, and versioned fresh-avatar URLs.
  Keep participant associations preloaded and extend the key if presentation
  starts reading a dependency not represented by those records.
- Individual boosts use `cache boost` and the boost collection is cached. Keep
  boost DOM IDs and the broadcast partial identical to the cached initial
  render.

Do not remove `cached: true` merely to hide an invalidation bug. Identify the
record whose change should invalidate the fragment and test both a cold render
and a render after the related record changes.

#### View-transition names

Transition names form source/destination pairs and must be unique on a rendered
page:

- `new-room` pairs the sidebar add control with the new-room panel.
- `edit-room-<room.id>` pairs room navigation with the room edit panel.
- `avatar-<user.id>` pairs the sidebar avatar with the profile panel.
- `account-settings` pairs the sidebar settings control with account settings.
- `chat-bots` and `chat-bot-<bot.id>` connect bot lists and forms;
  `custom-styles` connects account settings and the custom-style editor.
- `input-switcher` and `input-btn` connect the composer and search interface.

If a transition is removed or renamed, update both endpoints. Never render the
same non-parameterized transition name twice on one page.

#### Responsive and CSS custom-property contracts

The principal layout breakpoint is `100ch`. Wide screens expose the persistent
sidebar and room navigation; narrow screens use overlay/toggle behavior and
different composer/message spacing. Changes to `layout.css`, `nav.css`,
`sidebar.css`, `messages.css`, `composer.css`, `panels.css`, or
`autocomplete.css` must be checked immediately below and above that breakpoint.

Pointer capability changes behavior independently of width. The styles use
`any-hover`/`hover` and `pointer: fine`/`pointer: coarse` for hover controls,
message actions, and touch affordances. PWA styles also branch on
`display-mode: browser`/`standalone`; theme styles branch on
`prefers-color-scheme`; `_reset.css` honors `prefers-reduced-motion`. Do not use
viewport width as a substitute for these capabilities. Note that the existing
`pointer: course` query in `utilities.css` is spelled as it currently appears;
verify intent before relying on or correcting it.

Treat these custom-property groups as shared APIs:

- Theme semantics and compatibility aliases in `colors.css`, including
  `--color-*`, `--icon-filter`, and `--lch-always-black`. Both explicit themes
  and the system-light block must define compatible values.
- Density and spacing in `utilities.css`: `--inline-space`, `--block-space`,
  their half/double variants, and contextual gap/size overrides.
- Layout geometry in `layout.css` and `panels.css`: `--sidebar-width`,
  `--navbar-height`, `--footer-height`, `--panel-width`, and `--panel-padding`.
- Control geometry in `buttons.css`, `inputs.css`, and `avatars.css`, including
  `--btn-*`, `--input-*`, `--avatar-size`, hover, border, and outline values.

Account custom CSS is loaded after repository styles, so selectors and
properties used for operator customization are effectively public. Prefer
adding semantic properties and compatibility aliases over repurposing or
deleting an existing property.

For a future shared-room ordering feature, keep these boundaries explicit:

- Shared-room order is installation-wide and excludes direct rooms; direct
  chronology/unread promotion is a separate behavior.
- Initial shared order currently comes from `Membership.with_ordered_room` and
  also affects profile membership lists. Live order comes from the
  `sorted-list` data attributes and comparator.
- An administrator may not belong to every closed room. After enforcing an
  installation-administrator guard, an ordering lookup may need a global
  non-direct room scope instead of `Current.user.rooms`.
- Moving or re-rendering entries must preserve per-user visibility,
  `data-room-id`, unread classes, and read/unread subscriptions. Test initial
  order and live updates for two users with different closed/invisible access,
  reject non-administrators (including ordinary room creators), and verify
  direct rooms and unread state are unchanged.

### UI implementation conventions

These conventions describe the intended direction for new and changed UI. The
existing application predates this guide, so encountering older markup that
does not follow a convention is not permission to repeat it. Improve nearby
code when the change is small and safe; keep unrelated cleanup out of focused
feature work.

#### Partial interfaces

- Treat every partial as a function with a named input contract. Pass locals
  explicitly (`room:`, `message:`, `membership:`) instead of relying on a new
  instance variable. A partial may use `Current` for request identity, but its
  main rendered record should still be a local.
- For collection rendering, declare `as:` when the inferred local would be
  ambiguous or differs from the collection name. Keep the same local name in
  initial renders, Turbo responses, broadcasts, and tests.
- Pass layout-partial locals through `locals:` and keep yielded content focused
  on the type-specific fields. The room forms under `app/views/rooms/layouts/`
  are the reference pattern.
- Do not hide required associations or authorization assumptions inside a
  partial. Load/preload them in the controller or query object and enforce
  authorization before rendering.
- A partial used by a broadcast or fragment cache has a wider API than its
  caller suggests. Before changing its path, locals, outer DOM ID, or cache
  dependencies, follow the Turbo and cache contracts above.
- Keep paired server/client templates structurally aligned. In particular,
  changes to `app/views/messages/_message.html.erb` must be evaluated against
  `app/views/messages/_template.html.erb`.

#### Helpers and view ownership

- Use helpers for small, reusable rendering contracts—not domain decisions.
  Helpers are the right owner for repeated DOM IDs, route construction,
  accessible icon-button labels, and Stimulus data wiring.
- Extend the existing owner before creating parallel markup:
  `MessagesHelper` owns message shells, `RoomsHelper` owns room links/forms,
  `Users::SidebarHelper` owns the permanent sidebar frame, and
  `Rooms::InvolvementsHelper` owns notification-state controls.
- Use Rails `dom_id`/array targets for record identity. Do not hand-build a
  second naming scheme when Turbo broadcasts already use `[ record, :suffix ]`.
- Keep authorization in models/controllers and use helpers only to present an
  already-authorized action. Hiding a link or button is never sufficient
  authorization.
- Prefer a partial when the unit is mostly markup and a helper when it must
  consistently construct an element with IDs/data attributes. Do not move a
  large HTML tree into string-concatenating Ruby merely to call it reusable.

#### Semantic HTML and accessible names

- Use landmarks and native elements according to behavior: `nav` for primary
  navigation, headings in a logical hierarchy, `menu`/lists for collections of
  actions or entries, `fieldset` plus `legend` for a named group of controls,
  and `dialog` for modal interaction.
- Use links for navigation and buttons/forms for actions or mutations. Do not
  add `role="button"` to a link when a real button can express the behavior.
  Keep method-changing and destructive actions on `button_to`/forms.
- Every form control needs a visible `label`, a wrapping label, or an explicit
  `aria-label`/`aria-labelledby`. Placeholder text is supplemental and must not
  be the only name.
- Every icon-only interactive control needs a task-oriented accessible name.
  Prefer visible text; otherwise use a `.for-screen-reader` span or `aria-label`.
  Describe the action (“Delete subscription”), not the image (“Minus icon”).
- Mark decorative images `aria-hidden="true"` and do not rely on their `alt`
  text to name a surrounding button. Meaningful standalone images need useful
  alternative text.
- Associate help, error, status, and toggle state with the relevant control.
  Preserve `aria-labelledby`, `aria-describedby`, `aria-checked`, `aria-busy`,
  live/status behavior, and unique IDs when extracting markup.
- Use `.for-screen-reader` for content that must remain in the accessibility
  tree. Do not replace it with `hidden`, `display: none`, or `aria-hidden`.

#### Keyboard and focus behavior

- Prefer native controls so Enter, Space, Tab, form submission, and disabled
  behavior work without custom JavaScript. Avoid positive `tabindex`; use
  `tabindex="-1"` only for intentional programmatic focus or removal from the
  normal order.
- Any pointer interaction must have an equivalent keyboard path. If a custom
  element handles Enter or Space, expose the correct role/state and test both
  keys; a click handler alone is insufficient.
- Preserve established shortcuts when changing their forms: Escape cancels
  transient editors/popups, Up edits the user's last message, Enter behavior
  in the composer remains distinct from newline entry, and the custom-style
  editor supports Control/Command+Enter.
- Opening a popup/dialog or replacing a Turbo Frame must put focus somewhere
  useful; closing/cancelling should return focus to its trigger when practical.
  Native `dialog`, `details`/`summary`, and autofocus behavior are preferred to
  hand-built focus traps.
- Do not make critical controls hover-only. Message actions that change by
  pointer capability must remain focusable and operable on touch and keyboard.
- Destructive actions need an explicit accessible name and the existing Turbo
  confirmation unless the surrounding flow already provides an equivalent
  confirmation step.

#### Touch targets and interaction density

- Preserve at least the current `.btn` hit area (`--btn-size` in
  `buttons.css`) for icon-only controls. Visual icons may stay small while the
  clickable/focusable box remains comfortably sized.
- Keep adequate separation between destructive and frequent actions. Compact
  styling must reduce unused layout space, not shrink controls until they are
  difficult to tap.
- Never depend on hover to reveal the only route to an action. Check
  `hover: none`/`pointer: coarse` behavior and a touch-sized viewport whenever
  changing message, sidebar, composer, or popup controls.
- Account for the on-screen keyboard and safe viewport height. Composer and
  message-list changes must continue to scroll correctly when focus opens a
  mobile keyboard.

#### Light and dark themes

- Use semantic properties from `colors.css` rather than feature-local literal
  colors. If a new semantic role is needed, define it for dark, explicit light,
  and system-light modes, then provide a compatibility alias if existing CSS
  or account custom styles need one.
- Do not infer theme from a single color or duplicate theme state inside a
  component. The root `data-theme`, system preference, and
  `theme_controller.js` are the source of truth.
- Icons using the shared monochrome assets must respect `--icon-filter` or
  `--icon-filter-reversed`; verify actual images, focus rings, disabled states,
  borders, overlays, danger/success states, and rich-text content in both
  palettes.
- Maintain readable contrast without using color as the only indication of
  selection, unread state, validation, success, or danger. Preserve text,
  icon, shape, or accessible state alongside color.

#### Mobile and desktop behavior

- Design one semantic DOM that adapts through CSS where practical. Avoid
  separate mobile/desktop copies of interactive controls because duplicate
  IDs, Turbo targets, and focus order break easily.
- Treat `100ch` as the current layout transition, not a device label. Inspect
  just below and above it, plus a genuinely narrow phone viewport and a wide
  desktop viewport.
- Width and input capability are separate. Test narrow/wide layouts with both
  fine/hover and coarse/no-hover interaction when a change touches controls.
- On narrow screens, verify sidebar overlay/toggle behavior, navigation,
  message action placement, composer height, dialogs, overflow, and the
  software keyboard. On wide screens, verify persistent sidebar width, room
  content width, panel spacing, and hover affordances.
- PWA standalone mode and reduced-motion preferences are additional supported
  states. Do not remove display-mode utilities or restore motion under
  `prefers-reduced-motion` while making layout changes.

### CSS and themes

The layout links all Propshaft stylesheets with `stylesheet_link_tag :all`.
Styles are global and use native CSS nesting, shared utilities, and custom
properties; they are not component-scoped.

- `colors.css` defines the Bonfire palette and compatibility color tokens.
- `utilities.css` defines spacing, density, typography, layout, and utility
  classes used throughout views.
- `base.css`, `inputs.css`, `buttons.css`, and `panels.css` have broad effects.
- Feature stylesheets such as `sidebar.css`, `messages.css`, `composer.css`, and
  `actiontext.css` still depend on shared tokens and DOM context.

The browser preference is stored in local storage as `bonfire-theme`. The root
`data-theme` value is applied before styles render and maintained by
`theme_controller.js`. Test both explicit light/dark choices and the system
setting. Also inspect both sides of the `100ch` desktop/mobile breakpoint and a
coarse-pointer layout before considering a UI change complete.

Account custom CSS is injected after application styles by
`custom_styles_tag`; changing or removing stable custom properties can break an
operator's installation even when repository styles look correct.

### Before changing UI

Use this checklist for every UI change; scale the test set up with the risk.

- [ ] Find the area in the UI change map. Search its partial paths, DOM IDs,
  Stimulus identifiers, stream targets, cache keys, and transition names with
  `rg` before editing.
- [ ] Identify both the initial render and every Turbo/broadcast/refresh path.
  Preserve server-side authorization and use explicit partial locals.
- [ ] Add or update a focused controller/helper test for rendered contracts,
  then run it directly, for example:

  ```sh
  bin/rails test test/controllers/messages_controller_test.rb
  bin/rails test test/controllers/users/sidebars_controller_test.rb
  ```

- [ ] Run the relevant JavaScript-backed system test(s):

  ```sh
  bin/rails test test/system/sending_messages_test.rb   # chat/composer
  bin/rails test test/system/unread_rooms_test.rb       # sidebar/rooms
  bin/rails test test/system/boosting_messages_test.rb  # message actions
  bin/rails test test/system/theme_test.rb              # settings/theme
  ```

- [ ] Exercise keyboard-only operation and, where relevant, coarse-pointer
  behavior. Verify labels, focus, Escape/cancel, submission, and destructive
  confirmations.
- [ ] Inspect explicit light and dark themes plus the system setting. Inspect a
  narrow viewport below `100ch`, a wide viewport above `100ch`, and any
  hover/touch behavior affected by the change.
- [ ] Review the patch for accidental contract changes and whitespace errors:

  ```sh
  git diff
  git diff --check
  ```

- [ ] Run `bin/rails test` for a cross-cutting Rails change and `bin/ci` before
  merging a substantial UI change.

### Guide validation record

On 2026-08-08, two fresh read-only agents followed this guide for representative
tasks without implementation context:

| Scenario | What the guide got right | Gap found and correction made |
| --- | --- | --- |
| Add an administrator-editable data-protection notice to account settings and signup | The agent found the account form/controller, `Current.account`, settings JSON, signup view, styling, authorization, and controller tests. | The guide did not say that `has_json` declares accepted settings, did not map signup as its own UI surface, and did not cover optional public operator content. The Account settings and Signup and join sections now document those requirements and configured/blank tests. |
| Add administrator-controlled shared-room ordering with live sidebar updates | The agent found the sidebar shell/partial/helper, stream targets, broadcast writers, unread controller, and relevant tests. | The guide did not explain `Membership.with_ordered_room`, `sorted_list_controller.js` comparison rules, global versus per-user streams, or administrator versus room-creator authority. The shared-room, stream, authorization, and ordering notes now make those boundaries explicit. |

Both agents reported that the guide's contract-first workflow led them to the
correct code. The missing entry points and ambiguous guidance they identified
were corrected above; repeat this validation when a component architecture or
major navigation model changes.

## Local development

Initial setup:

```sh
bin/setup
```

Normal development:

```sh
bin/dev
```

Foreman reads `Procfile.dev`, starts Rails on
`http://bonfire.localhost:3021`, and attaches the Redis service from
`compose.dev.yml` on `127.0.0.1:6321`. Development uses SQLite and local file
storage; it does not require Postgres or MinIO.

Reset only local development state:

```sh
bin/dev reset
```

This is destructive to the local development database and uploads. It must not
be used to solve a test failure unless resetting local state is the intended
task.

## Tests and quality checks

Tests mirror the application structure under `test/models`,
`test/controllers`, `test/helpers`, `test/channels`, and `test/system`. Fixtures are
in `test/fixtures`; uploaded-file fixtures are in `test/fixtures/files`.

Useful commands:

```sh
# Full model/controller/helper/job suite
bin/rails test

# One focused file (line numbers also work)
bin/rails test test/controllers/messages_controller_test.rb

# Browser tests (requires Chrome/ChromeDriver)
bin/rails test test/system/theme_test.rb
bin/rails test:system

# Project CI: setup, style, security, tests, and fixtures
bin/ci

# Always check patches for whitespace errors
git diff --check
```

For UI work, add or update controller assertions for rendered contracts and a
focused system test for behavior that depends on JavaScript. A passing initial
render test does not prove Turbo broadcasts, mobile behavior, or the opposite
theme still work.

## Upstream maintenance

Bonfire is a product fork of Basecamp's Campfire repository, not a detached
copy. The remotes have distinct roles:

- `origin` is `bladeofmaya/bonfire`; Bonfire development and releases use the
  local `master` branch.
- `upstream` is `basecamp/once-campfire`; Basecamp changes are read from
  `upstream/main`. Do not develop Bonfire features on, rewrite, or push to the
  upstream branch.

Local branches may deliberately have no configured tracking branch, so do not
assume a plain `git pull` has the intended source. Name the remote and branch in
fetch/merge commands and inspect `git remote -v` plus `git branch -vv` first.

### Upstream integration workflow

Keep conflict resolution isolated from `master` so it can be reviewed and
abandoned without mixing it with feature work:

```sh
git status --short
git fetch upstream
git switch master
git switch -c upstream-merge-YYYYMMDD
git merge --no-ff upstream/main
```

If the repository's reusable `upstream-merge` branch is preferred, first merge
the current `master` into it, then merge `upstream/main`; do not reset it over
unreviewed commits. During conflicts:

1. Read the upstream commits that touched the file and identify the bug fix or
   behavior being introduced. Do not resolve a whole file with “ours” merely
   because it contains Bonfire styling.
2. Restore a working upstream implementation first, then reapply the protected
   Bonfire behavior listed below. Preserve new upstream security,
   authorization, migration, realtime, and accessibility changes.
3. Use `git diff --name-only --diff-filter=U` until no unresolved files remain.
   Search changed partial paths, DOM IDs, Stimulus APIs, stream targets, cache
   dependencies, and transition pairs using this guide.
4. Run focused tests while resolving each area, then `bin/ci`. Inspect the UI in
   both themes and on both sides of `100ch` before merging the integration
   branch into `master`.
5. Keep the merge commit and record the upstream commit or tag it integrated.
   This gives the next merge a correct ancestry and prevents already-resolved
   changes from returning.

After verification, merge the integration branch into `master` with a normal
merge commit. Pushing either branch is a separate action and requires the
user's explicit intent.

### Protected Bonfire behavior and likely conflicts

These are the current high-risk areas derived from Bonfire's actual divergence
from `upstream/main`:

| Area | Files to inspect together | Bonfire behavior to preserve while accepting upstream fixes |
| --- | --- | --- |
| Document shell and theme startup | `app/views/layouts/application.html.erb`, `app/javascript/controllers/theme_controller.js`, `app/assets/stylesheets/colors.css` | Dark-first Bonfire palette, explicit light/dark/system choice, early no-flash initialization, `bonfire-theme`, dynamic theme-color metadata, global controller bindings, and account custom CSS order. |
| Global density and controls | `app/assets/stylesheets/base.css`, `buttons.css`, `inputs.css`, `utilities.css`, `layout.css`, `nav.css`, `sidebar.css`, `messages.css`, `composer.css`, and `actiontext.css` | Compact interface sizing, semantic/compatibility color properties, icon filters, the `100ch` layout, pointer-specific controls, and existing custom-property APIs. These global files can conflict behaviorally even when Git reports a clean merge. |
| Profile and appearance settings | `app/views/users/profiles/show.html.erb`, `app/helpers/users/profiles_helper.rb`, `test/controllers/users/profiles_controller_test.rb`, `test/system/theme_test.rb` | Avatar upload geometry, semantic Appearance and conversation fieldsets, browser-local theme selection, and theme regression coverage. |
| Branding and install surfaces | `app/assets/images/bonfire-icon.png`, `app/assets/images/logos/app-icon.png`, `app/assets/images/logos/app-icon-192.png`, `app/views/pwa/manifest.json.erb`, `app/views/pwa/_install_instructions.html.erb`, `app/views/pwa/_system_settings.html.erb` | Bonfire name, icons, manifest metadata, installation language, and account-logo behavior. An upstream merge must not silently restore Campfire assets or copy. |
| Translation-control removal | application/profile/account/session/signup/room form views and `app/helpers/application_helper.rb` | Bonfire intentionally removed the globe popup controls, their helper, and globe asset. If upstream changes those call sites, retain the useful form/content change without reintroducing the translation popup or leaving dead helper references. |
| Signup and first run | `app/views/first_runs/show.html.erb`, `app/views/users/new.html.erb`, `app/views/sessions/new.html.erb`, `app/assets/stylesheets/signup.css` | Bonfire branding, compact form presentation, accessible labels, avatar behavior, and the absence of removed translation/lanyard UI. |
| Account and room settings | `app/views/accounts/edit.html.erb`, `app/views/accounts/bots/_form.html.erb`, `app/views/accounts/bots/index.html.erb`, `app/views/accounts/custom_styles/edit.html.erb`, `app/views/rooms/layouts/_form.html.erb` | Compact controls, semantic groups, account customization, and no removed translation controls. Reconcile new upstream settings explicitly rather than dropping either side's fields. |

The sidebar, message, and composer contracts are currently closer to upstream,
but they are expected to become increasingly conflict-prone as Bonfire adds
room ordering, announcements, embeds, emotes, notifications, and integrations.
Always compare these files as a connected surface:

- `app/views/users/sidebars/show.html.erb`, its room partials,
  `app/helpers/users/sidebar_helper.rb`, and `sidebar.css`.
- `app/views/messages/_message.html.erb`, `_presentation.html.erb`,
  `_template.html.erb`, `app/helpers/messages_helper.rb`, and `messages.css`.
- `app/views/rooms/show/_composer.html.erb`, `app/helpers/rooms_helper.rb`,
  `app/javascript/controllers/composer_controller.js`, and `composer.css`.

After resolving branding-heavy merges, search application code and public
assets for unintended Campfire names or removed asset references. References
inside this upstream-maintenance explanation are intentional.

## Deployment and operations

`bin/bonfire` is the supported operator entry point:

```sh
bin/bonfire status
bin/bonfire setup
bin/bonfire deploy
```

It manages ignored deployment configuration under `.kamal/`, validates the
server, generates required secrets, and invokes Kamal. `config/deploy.yml` is
the deployment template. The container runs `bin/boot`; `bin/start-app`
prepares the database before starting Rails. `Procfile` starts web, Redis, and
Resque workers inside the production process supervisor.

Deployment storage must remain writable by container UID/GID `1000:1000`.
Database or upload changes must account for backup/restore behavior documented
in `docs/self-hosting.md` and the scripts under `hooks/` and `script/admin/`.

Do not deploy, mutate a server, rotate secrets, or run destructive reset/restore
operations unless the user explicitly asks for that external change.

## Working safely

Before changing a behavior:

1. Trace the route, controller concern, model callback/concern, view/helper,
   Stimulus controller, CSS, broadcast path, and existing tests that participate.
2. Preserve authorization and room-membership scoping on the server.
3. Search for DOM IDs, partial paths, and data attributes before renaming them.
4. Keep migrations, feature behavior, tests, accessibility, and operator docs in
   the same focused change.
5. Exercise the smallest relevant tests, then the full suite in proportion to
   risk. UI changes should be checked in light/dark and mobile/desktop states.
6. Preserve unrelated user changes in a dirty worktree and keep upstream merge
   compatibility in mind.

When this guide and the code disagree, treat the code as current evidence and
update `AGENTS.md` as part of the same change.
