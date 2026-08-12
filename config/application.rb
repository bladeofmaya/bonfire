require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Bonfire
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks rails_ext])

    # Fallback to English if translation key is missing
    config.i18n.fallbacks = true

    # ViewComponent is used selectively for reusable leaf UI. Keep generated
    # components, previews, and their layout in predictable locations.
    config.view_component.generate.path = "app/components"
    config.view_component.generate.preview = true
    config.view_component.generate.preview_path = "test/components/previews"
    config.view_component.previews.default_layout = "component_preview"
  end
end
