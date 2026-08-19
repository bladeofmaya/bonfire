class AddEmailNotificationPreferences < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :email_notifications_enabled, :boolean, default: false, null: false
    add_column :users, :email_mentions_enabled, :boolean, default: true, null: false
    add_column :users, :email_daily_summary_enabled, :boolean, default: false, null: false
    add_column :users, :email_digest_hour, :integer, default: 9, null: false
    add_column :users, :email_time_zone, :string, default: "UTC", null: false

    create_table :email_notification_deliveries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :message, foreign_key: true
      t.string :kind, null: false
      t.date :period_on
      t.datetime :delivered_at
      t.timestamps
    end

    add_index :email_notification_deliveries, [ :user_id, :message_id, :kind ],
      unique: true, where: "message_id IS NOT NULL", name: "idx_email_deliveries_unique_message"
    add_index :email_notification_deliveries, [ :user_id, :period_on, :kind ],
      unique: true, where: "period_on IS NOT NULL", name: "idx_email_deliveries_unique_period"
  end
end
