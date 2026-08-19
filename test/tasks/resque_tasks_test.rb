require "test_helper"
require "rake"

class ResqueTasksTest < ActiveSupport::TestCase
  test "scheduler startup task is registered" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("resque:scheduler")

    assert Rake::Task.task_defined?("resque:scheduler")
    assert_includes Rake::Task["resque:scheduler"].prerequisites, "scheduler_setup"
  end
end
