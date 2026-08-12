module ComponentPreviewsHelper
  PREVIEW_GROUPS = {
    "messages" => [ "Messages", "Message content, actions, and reactions." ],
    "rooms" => [ "Rooms", "Room-list entries and notification controls." ],
    "ui" => [ "UI primitives", "Small reusable controls shared across product areas." ],
    "prototype" => [ "Prototype evidence", "Experiments retained for architecture review; these are not production components." ]
  }.freeze

  def component_preview_theme
    params[:theme] == "light" ? "light" : "dark"
  end

  def component_preview_viewport
    params[:viewport] == "mobile" ? "mobile" : "desktop"
  end

  def component_preview_groups(previews)
    previews.group_by { |preview| preview.preview_name.split("/").first }
      .sort_by { |group, _| PREVIEW_GROUPS.keys.index(group) || PREVIEW_GROUPS.length }
  end

  def component_preview_group_details(group)
    PREVIEW_GROUPS.fetch(group, [ group.titleize, nil ])
  end

  def component_preview_path(preview, example: nil, **options)
    path = [ preview.preview_name, example ].compact.join("/")
    preview_view_component_path(path, **component_preview_options.merge(options))
  end

  def component_preview_options
    { theme: component_preview_theme, viewport: component_preview_viewport }
  end
end
