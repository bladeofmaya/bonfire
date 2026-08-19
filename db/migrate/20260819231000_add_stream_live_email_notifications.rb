class AddStreamLiveEmailNotifications < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :email_stream_live_enabled, :boolean, default: false, null: false

    add_reference :email_notification_deliveries, :room, foreign_key: true
    add_column :email_notification_deliveries, :stream_session_id, :string
    add_index :email_notification_deliveries, [ :user_id, :room_id, :stream_session_id, :kind ],
      unique: true, where: "stream_session_id IS NOT NULL", name: "idx_email_deliveries_unique_stream_session"
  end
end
