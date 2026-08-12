require "test_helper"

class Prototype::PartialRenderingTest < ComponentTestCase
  test "renders an explicitly labelled settings field with help" do
    render_settings_partial

    assert_selector "label[for='account_notice']", text: "Data-protection notice"
    assert_selector "textarea#account_notice[name='account[notice]'][aria-describedby='account_notice_help']"
    assert_selector "#account_notice_help", text: "Shown before signup."
    assert_no_selector "[role='alert']"
  end

  test "renders disabled and error states accessibly" do
    render_settings_partial(disabled: true, error: "Enter a notice.")

    assert_selector "textarea[disabled][aria-invalid='true'][aria-describedby='account_notice_help account_notice_error']"
    assert_selector "#account_notice_error[role='alert']", text: "Enter a notice."
  end

  test "preserves the shared-room DOM contract" do
    room = rooms(:watercooler)
    render_room_partial(room: room, unread: true)

    assert_selector "a##{dom_id(room, :list)}.room.unread[data-room-id='#{room.id}'][data-sorted-list-name='#{room.name}']"
    assert_selector "[data-rooms-list-target='room'][data-badge-dot-target='unread'][data-sorted-list-target='item']"
  end

  test "renders a room collection" do
    collection = [ rooms(:pets), rooms(:hq) ]

    render_in_view_context do
      render partial: "prototypes/partials/shared_room_item",
        collection: collection, as: :room, locals: { unread: false }
    end

    assert_selector "a.room", count: 2
  end

  test "renders through a Turbo broadcast" do
    room = rooms(:watercooler)

    streams = capture_turbo_stream_broadcasts(:prototype_partial_rooms) do
      room.broadcast_replace_to :prototype_partial_rooms, target: [ room, :list ],
        partial: "prototypes/partials/shared_room_item", locals: { room: room, unread: true }
    end

    stream = streams.sole
    assert_equal "replace", stream["action"]
    assert_equal dom_id(room, :list), stream["target"]
    assert stream.at_css("template a.unread[data-sorted-list-name='#{room.name}']")
  end

  private
    def render_settings_partial(**overrides)
      locals = settings_options.merge(overrides)

      render_in_view_context do
        render partial: "prototypes/partials/settings_field", locals: locals
      end
    end

    def render_room_partial(room:, unread:)
      render_in_view_context do
        render partial: "prototypes/partials/shared_room_item", locals: { room: room, unread: unread }
      end
    end

    def settings_options
      {
        id: "account_notice",
        name: "account[notice]",
        label: "Data-protection notice",
        value: "Community policy",
        help: "Shown before signup.",
        error: nil,
        disabled: false
      }
    end
end
