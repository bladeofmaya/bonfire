ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

require "rails/test_help"
require "minitest/unit"
require "mocha/minitest"
require "webmock/minitest"
require "turbo/broadcastable/test_helper"
require_relative "test_helpers/component_test_helper"
require_relative "test_helpers/component_test_case"
require_relative "test_helpers/custom_emote_test_helper"
require_relative "test_helpers/visual_regression_helper"

WebMock.enable!

class ActiveSupport::TestCase
  include ActiveJob::TestHelper

  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  include SessionTestHelper, MentionTestHelper, TurboTestHelper, CustomEmoteTestHelper

  def configure_streaming(previous_jwks: [])
    key = OpenSSL::PKey::EC.generate("prime256v1")
    Streaming::Configuration.stubs(
      configured?: true,
      validate!: true,
      private_key: key,
      key_id: "test-current-key",
      issuer: "https://bonfire.example.test",
      audience: "rtmp-homebrew",
      allowed_player_origins: [ "https://stream.example.test" ],
      previous_jwks: previous_jwks
    )
    Streaming::Configuration.stubs(:allowed_player_origin?).returns(false)
    Streaming::Configuration.stubs(:allowed_player_origin?).with("https://stream.example.test").returns(true)
    key
  end

  setup do
    ActionCable.server.pubsub.clear

    Rails.configuration.tap do |config|
      config.x.web_push_pool.shutdown
      config.x.web_push_pool = WebPush::Pool.new \
        invalid_subscription_handler: config.x.web_push_pool.invalid_subscription_handler
    end

    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.reset!
  end
end
