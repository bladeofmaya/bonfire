class AddStreamConfigurationToRooms < ActiveRecord::Migration[8.2]
  def change
    add_column :rooms, :stream_enabled, :boolean, default: false, null: false
    add_column :rooms, :stream_player_url, :string
    add_column :rooms, :stream_path, :string
    add_column :rooms, :stream_title, :string
  end
end
