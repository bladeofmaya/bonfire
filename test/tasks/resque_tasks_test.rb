require "test_helper"
require "open3"

class ResqueTasksTest < ActiveSupport::TestCase
  test "scheduler startup task is registered" do
    output, error, status = Open3.capture3(
      { "RAILS_ENV" => "test" }, "bundle", "exec", "rake", "-T", "resque", chdir: Rails.root.to_s
    )

    assert status.success?, error
    assert_includes output, "rake resque:scheduler"
  end
end
