require "test_helper"

class Room::ReferenceableTest < ActiveSupport::TestCase
  test "renders a channel reference as an internal room link" do
    room = rooms(:watercooler)
    attachment = ActionText::Attachment.from_attachable(room)
    content = ActionText::Content.new(%(<div>#{attachment.to_html}</div>))
    html = content.to_s

    assert_equal room, attachment.attachable
    assert_includes html, %(href="#{Rails.application.routes.url_helpers.room_path(room)}")
    assert_includes html, ">All Talk</a>"
    assert_equal "All Talk", room.attachable_plain_text_representation(nil)
  end
end
