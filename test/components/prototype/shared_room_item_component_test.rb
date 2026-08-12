require "test_helper"

class Prototype::SharedRoomItemComponentTest < ComponentTestCase
  test "preserves the shared-room DOM contract" do
    room = rooms(:watercooler)

    render_inline Prototype::SharedRoomItemComponent.new(room: room, unread: true)

    assert_selector "a##{dom_id(room, :list)}.room.unread[data-room-id='#{room.id}'][data-sorted-list-name='#{room.name}']"
    assert_selector "[data-rooms-list-target='room'][data-badge-dot-target='unread'][data-sorted-list-target='item']"
  end

  test "renders collections with an explicit room collection parameter" do
    render_inline Prototype::SharedRoomItemComponent.with_collection([ rooms(:pets), rooms(:hq) ])

    assert_selector "a.room", count: 2
  end

  test "renders directly through a Turbo broadcast" do
    room = rooms(:watercooler)

    streams = capture_turbo_stream_broadcasts(:prototype_rooms) do
      room.broadcast_replace_to :prototype_rooms, target: [ room, :list ],
        renderable: Prototype::SharedRoomItemComponent.new(room: room, unread: true)
    end

    stream = streams.sole
    assert_equal "replace", stream["action"]
    assert_equal dom_id(room, :list), stream["target"]
    assert stream.at_css("template a.unread[data-sorted-list-name='#{room.name}']")
  end
end
