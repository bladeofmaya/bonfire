module Rooms::InvolvementsHelper
  def turbo_frame_for_involvement_tag(room, &)
    turbo_frame_tag dom_id(room, :involvement), data: {
      controller: "turbo-frame", action: "notifications:ready@window->turbo-frame#load", turbo_frame_url_param: room_involvement_path(room)
    }, &
  end

  def button_to_change_involvement(room, involvement)
    render Rooms::InvolvementButtonComponent.new(
      involvement: involvement,
      next_involvement: next_involvement_for(room, involvement: involvement),
      url: room_involvement_path(room),
      label: HUMANIZE_INVOLVEMENT.fetch(involvement),
      label_id: dom_id(room, :involvement_label)
    )
  end

  private
    HUMANIZE_INVOLVEMENT = {
      "mentions" => "Notifying about @ mentions",
      "everything" => "Notifying about all messages",
      "nothing" => "Notifications are off",
      "invisible" => "Notifications are off and room invisible in sidebar"
    }

    SHARED_INVOLVEMENT_ORDER = %w[ mentions everything nothing invisible ]
    DIRECT_INVOLVEMENT_ORDER = %w[ everything nothing ]

    def next_involvement_for(room, involvement:)
      if room.direct?
        DIRECT_INVOLVEMENT_ORDER[DIRECT_INVOLVEMENT_ORDER.index(involvement) + 1] || DIRECT_INVOLVEMENT_ORDER.first
      else
        SHARED_INVOLVEMENT_ORDER[SHARED_INVOLVEMENT_ORDER.index(involvement) + 1] || SHARED_INVOLVEMENT_ORDER.first
      end
    end
end
