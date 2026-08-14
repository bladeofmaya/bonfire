class AddDataProtectionAcceptance < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :data_protection_notice_version, :integer, default: 0, null: false
    add_column :accounts, :data_protection_notice_digest, :string
    add_column :accounts, :data_protection_notice_published_at, :datetime

    add_column :users, :data_protection_notice_version, :integer
    add_column :users, :data_protection_notice_digest, :string
    add_column :users, :data_protection_notice_accepted_at, :datetime
    add_column :users, :data_protection_notice_accepted_ip, :string
  end
end
