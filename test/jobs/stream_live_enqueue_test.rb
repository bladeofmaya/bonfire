require "test_helper"

class StreamLiveEnqueueTest < ActiveJob::TestCase
  self.use_transactional_tests = false

  test "fanout jobs are not visible to workers until the stream transaction commits" do
    room = rooms(:watercooler)

    Room.transaction do
      Room::PushStreamLiveJob.perform_later(room, "session-after-commit")
      EmailNotifications::StreamLiveJob.perform_later(room, "session-after-commit")

      assert_enqueued_jobs 0
    end

    assert_enqueued_jobs 1, only: Room::PushStreamLiveJob
    assert_enqueued_jobs 1, only: EmailNotifications::StreamLiveJob
  end
end
