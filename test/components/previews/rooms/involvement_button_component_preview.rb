class Rooms::InvolvementButtonComponentPreview < ViewComponent::Preview
  STATES = {
    mentions: [ "everything", "Notifying about @ mentions" ],
    everything: [ "nothing", "Notifying about all messages" ],
    nothing: [ "invisible", "Notifications are off" ],
    invisible: [ "mentions", "Notifications are off and room invisible in sidebar" ]
  }.freeze

  STATES.each do |involvement, (next_involvement, label)|
    define_method involvement do
      render Rooms::InvolvementButtonComponent.new(
        involvement: involvement.to_s,
        next_involvement: next_involvement,
        url: "/rooms/123/involvement",
        label: label,
        label_id: "preview_involvement_label"
      )
    end
  end
end
