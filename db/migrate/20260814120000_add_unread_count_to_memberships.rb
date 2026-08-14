class AddUnreadCountToMemberships < ActiveRecord::Migration[8.2]
  def up
    add_column :memberships, :unread_count, :integer, default: 0, null: false
    execute "UPDATE memberships SET unread_count = 1 WHERE unread_at IS NOT NULL"
  end

  def down
    remove_column :memberships, :unread_count
  end
end
