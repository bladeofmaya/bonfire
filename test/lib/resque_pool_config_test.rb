require "test_helper"
require "erb"

class ResquePoolConfigTest < ActiveSupport::TestCase
  test "production workers consume both application queues" do
    template = Rails.root.join("config/resque-pool.yml").read
    config = YAML.safe_load(ERB.new(template).result)

    assert_operator config.fetch("default"), :>, 0
    assert_operator config.fetch("email"), :>, 0
  end
end
