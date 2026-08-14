class RenameDataProtectionAcceptanceToSignupInfo < ActiveRecord::Migration[8.2]
  def change
    rename_column :accounts, :data_protection_notice_version, :signup_info_version
    rename_column :accounts, :data_protection_notice_digest, :signup_info_digest
    rename_column :accounts, :data_protection_notice_published_at, :signup_info_published_at

    rename_column :users, :data_protection_notice_version, :signup_info_version
    rename_column :users, :data_protection_notice_digest, :signup_info_digest
    rename_column :users, :data_protection_notice_accepted_at, :signup_rules_accepted_at
    rename_column :users, :data_protection_notice_accepted_ip, :signup_rules_accepted_ip
  end
end
