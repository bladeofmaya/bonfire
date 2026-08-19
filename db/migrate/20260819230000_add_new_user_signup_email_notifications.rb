class AddNewUserSignupEmailNotifications < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :email_new_user_signup_enabled, :boolean, default: false, null: false

    add_reference :email_notification_deliveries, :subject_user, foreign_key: { to_table: :users }
    add_index :email_notification_deliveries, [ :user_id, :subject_user_id, :kind ],
      unique: true, where: "subject_user_id IS NOT NULL", name: "idx_email_deliveries_unique_subject_user"
  end
end
