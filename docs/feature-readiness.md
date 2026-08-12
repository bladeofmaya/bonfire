# Milestone 1 feature-readiness review

Status: Ready for incremental feature work.

This review closes the architecture/prototyping prerequisite for Bonfire's
first product features. It does not mean the UI migration is finished. Large
containers remain partial composition by design, and each future extraction
must remain independently deployable.

## Readiness checklist

| Requirement | Evidence | Status |
| --- | --- | --- |
| Documented entry points | `AGENTS.md` maps request, domain, realtime, frontend, and UI change paths. | Ready |
| Accepted component strategy | ADR 0001 chooses a hybrid approach; `docs/component-contracts.md` defines boundaries and migration order. | Ready |
| Representative previews | `/rails/view_components` groups production states and supports light/dark plus desktop/mobile modes. | Ready |
| Protected live contracts | Controller, component, channel, system, and visual tests cover Turbo targets, broadcast adapters, unread state, messages, composer, and settings. | Ready |
| Stable room-list item API | Shared/direct leaf components accept explicit presentation and sorting state behind stable broadcast adapter partials. | Ready with constraints below |
| CSS iteration boundary | `docs/css-architecture.md`, canonical tokens, explicit settings/icon primitives, and element-scoped baselines constrain visual changes. | Ready |

## Room-list ordering contract

Channel pinning and manual ordering should build on the existing boundaries,
not bypass them.

### Current API

- `Users::SidebarsController` supplies visible, authorized memberships and
  preloaded direct participants.
- `_shared_list.html.erb` and `_direct_list.html.erb` own collection targets;
  they do not decide persistence or authorization.
- `Rooms::SharedListItemComponent` accepts `room:`, explicit `sort_key:`, and
  `unread:`. It emits stable `[ room, :list ]` identity plus
  `data-sorted-list-name`.
- `Rooms::DirectListItemComponent` accepts `room:`, `participants:`,
  `sort_timestamp:`, and `unread:`. It emits the same identity plus
  `data-sorted-list-number`.
- `sorted_list_controller.js` sorts shared strings ascending and direct numeric
  values descending. Direct unread events promote an item by updating its
  numeric value in the browser.
- `users/sidebars/rooms/shared` and `direct` remain executable Turbo broadcast
  adapter names. Create/visibility/type/destroy writers target `shared_rooms`,
  `direct_rooms`, or `[ room, :list ]`.

### Constraints for pinning and reordering

The leaf API is stable enough to carry ordering state because sorting inputs
are explicit. Persistence is not implemented yet. When it is added:

1. Store shared-room order at the correct scope. A global room position is
   appropriate only if every user sees the same order; per-user pins/order
   belong on `Membership`.
2. Replace `Membership.with_ordered_room` with a deterministic server order
   that includes pinned/manual position and a stable fallback such as room name
   then ID. Initial HTML and client sorting must agree to avoid a visible jump.
3. Evolve the shared item from a name-specific sort attribute to an explicit
   ordering key or tuple. Preserve `data-sorted-list-target="item"`, DOM IDs,
   unread classes, and room-link data.
4. Keep direct rooms chronological unless product requirements explicitly add
   direct-message pinning. Their unread promotion is a separate behavior from
   shared channel order.
5. Update every open/closed/involvement/create/rename broadcast writer with the
   same ordering state. A prepend remains temporary only when the connected
   item has enough data for the client to place it correctly.
6. Add model tests for deterministic order, controller tests for initial and
   broadcast markup, and a system test for reorder persistence across reload
   and live insertions.

Do not implement persisted ordering solely by changing DOM order or the
Stimulus comparator. The database query, leaf sort data, live broadcasts, and
client comparator form one contract.

## What remains intentionally ongoing

- Container migration proceeds only when a concrete feature benefits from it.
- Legacy fieldset and inferred icon-button fallbacks can be removed as their
  remaining distinct flows are audited.
- Product-area CSS continues to migrate incrementally; sidebar, messages, and
  composer should not be reorganized independently of feature work.
- Visual baselines protect today’s output but do not replace accessibility,
  controller, component, or realtime tests.

The next feature may now begin from its relevant contract instead of waiting
for a broad frontend rewrite.
