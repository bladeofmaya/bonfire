class AddLiveStateToRooms < ActiveRecord::Migration[8.2]
  def change
    add_column :rooms, :stream_session_id, :string
    add_column :rooms, :stream_live_at, :datetime
    add_column :rooms, :stream_last_seen_at, :datetime
    add_column :rooms, :stream_notified_session_id, :string
  end
end
