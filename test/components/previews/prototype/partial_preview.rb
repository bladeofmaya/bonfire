class Prototype::PartialPreview < ViewComponent::Preview
  class PartialRenderable
    def initialize(path:, locals:)
      @path = path
      @locals = locals
    end

    def render_in(view_context)
      view_context.render partial: @path, locals: @locals
    end

    def format
      :html
    end
  end

  def settings_normal
    render_partial "prototypes/partials/settings_field", settings_field_options
  end

  def settings_empty
    render_partial "prototypes/partials/settings_field", settings_field_options(value: nil)
  end

  def settings_disabled
    render_partial "prototypes/partials/settings_field", settings_field_options(disabled: true)
  end

  def settings_error
    render_partial "prototypes/partials/settings_field", settings_field_options(error: "Enter a notice before publishing.")
  end

  def settings_long_text
    render_partial "prototypes/partials/settings_field", settings_field_options(value: long_notice)
  end

  def room_normal
    render_partial "prototypes/partials/shared_room_item", { room: preview_room("Announcements"), unread: false }
  end

  def room_unread
    render_partial "prototypes/partials/shared_room_item", { room: preview_room("Announcements"), unread: true }
  end

  def room_long_text
    render_partial "prototypes/partials/shared_room_item",
      { room: preview_room("Announcements and important community updates from the team"), unread: false }
  end

  private
    def render_partial(path, locals)
      render PartialRenderable.new(path: path, locals: locals)
    end

    def settings_field_options(**overrides)
      {
        id: "account_readme",
        name: "account[readme]",
        label: "Data-protection notice",
        value: "We explain how community account data is used.",
        help: "Shown to people before they create an account.",
        error: nil,
        disabled: false
      }.merge(overrides)
    end

    def long_notice
      "This community is independently operated. Contact the administrator if you want to access, correct, export, or remove information connected to your account."
    end

    def preview_room(name)
      Rooms::Open.new(id: 10_001, name: name).tap do |room|
        room.define_singleton_method(:persisted?) { true }
      end
    end
end
