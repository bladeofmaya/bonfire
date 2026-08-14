class RenameSignupInfoToReadme < ActiveRecord::Migration[8.2]
  def up
    rename_column :accounts, :signup_info_version, :readme_version
    rename_column :accounts, :signup_info_digest, :readme_digest
    rename_column :accounts, :signup_info_published_at, :readme_published_at
    rename_column :users, :signup_info_version, :readme_version
    rename_column :users, :signup_info_digest, :readme_digest

    execute <<~SQL.squish
      UPDATE action_text_rich_texts
      SET name = 'readme'
      WHERE record_type = 'Account' AND name = 'signup_info'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE action_text_rich_texts
      SET name = 'signup_info'
      WHERE record_type = 'Account' AND name = 'readme'
    SQL

    rename_column :users, :readme_digest, :signup_info_digest
    rename_column :users, :readme_version, :signup_info_version
    rename_column :accounts, :readme_published_at, :signup_info_published_at
    rename_column :accounts, :readme_digest, :signup_info_digest
    rename_column :accounts, :readme_version, :signup_info_version
  end
end
