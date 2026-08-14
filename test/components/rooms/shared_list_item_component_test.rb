require "test_helper"

class Rooms::SharedListItemComponentTest < ComponentTestCase
  test "preserves the shared-room DOM and Stimulus contracts" do
    room = rooms(:watercooler)

    render_inline component(room, unread: true)

    room_path = Rails.application.routes.url_helpers.room_path(room)

    assert_component_root "##{dom_id(room, :list)}.channel-order-item[data-sorted-list-position='#{room.position}']"
    assert_selector ".sidebar-list-item.sidebar-list-item--channel.sidebar-list-item--unread"
    assert_selector "a[href='#{room_path}'][data-room-id='#{room.id}']"
    assert_selector "[data-rooms-list-target='room'][data-badge-dot-target='unread']"
    assert_selector ".overflow-ellipsis", text: room.name
  end

  test "renders the shared selected-state contract" do
    render_inline component(rooms(:watercooler), selected: true)

    assert_selector ".sidebar-list-item.sidebar-list-item--channel.room-list--current"
  end

  test "uses the explicit sort key without changing the visible name" do
    room = rooms(:watercooler)

    render_inline component(room, sort_key: "0001")

    assert_selector "[data-sorted-list-name='0001']", text: room.name
    assert_no_selector "a.unread"
  end

  test "renders collections with an explicit room collection parameter" do
    components = Rooms::SharedListItemComponent.with_collection([ rooms(:pets), rooms(:hq) ])

    render_inline components

    assert_selector "a.room", count: 2
    assert_selector "[data-sorted-list-name='#{rooms(:pets).name}']"
    assert_selector "[data-sorted-list-name='#{rooms(:hq).name}']"
  end

  test "renders through the production partial adapter in a Turbo broadcast" do
    room = rooms(:watercooler)

    streams = capture_turbo_stream_broadcasts(:production_rooms) do
      room.broadcast_replace_to :production_rooms, target: [ room, :list ],
        partial: "users/sidebars/rooms/shared", locals: { room: room, unread: true }
    end

    stream = streams.sole
    assert_equal "replace", stream["action"]
    assert_equal dom_id(room, :list), stream["target"]
    assert stream.at_css("template [data-sorted-list-name='#{room.name}'] a.unread")
  end

  test "renders an accessible administrator drag and keyboard handle" do
    room = rooms(:pets)
    render_inline Rooms::SharedListItemComponent.new(room: room, reorderable: true)

    assert_selector "button.channel-order-item__handle.btn--plain[aria-label='Reorder #{room.name}']" \
                    "[aria-describedby='channel-order-instructions']" \
                    "[data-action='keydown->channel-order#moveWithKeyboard'] [data-lucide='grip-vertical']"
  end

  private
    def component(room, unread: false, selected: false, sort_key: room.name)
      Rooms::SharedListItemComponent.new(room: room, unread: unread, selected: selected, sort_key: sort_key)
    end
end
