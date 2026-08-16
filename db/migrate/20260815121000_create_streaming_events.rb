class CreateStreamingEvents < ActiveRecord::Migration[8.2]
  def change
    create_table :streaming_events do |t|
      t.string :event_id, null: false
      t.timestamps
    end

    add_index :streaming_events, :event_id, unique: true
  end
end
