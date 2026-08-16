class AddUnreadMentionCountToMemberships < ActiveRecord::Migration[8.2]
  def change
    add_column :memberships, :unread_mention_count, :integer, default: 0, null: false
  end
end
