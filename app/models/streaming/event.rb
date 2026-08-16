class Streaming::Event < ApplicationRecord
  self.table_name = "streaming_events"

  validates :event_id, presence: true, uniqueness: true
end
