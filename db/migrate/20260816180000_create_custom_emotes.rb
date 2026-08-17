class CreateCustomEmotes < ActiveRecord::Migration[8.2]
  def change
    create_table :custom_emotes do |t|
      t.references :account, null: false, foreign_key: true
      t.string :shortcode, null: false
      t.datetime :disabled_at
      t.timestamps
    end

    add_index :custom_emotes, [ :account_id, :shortcode ], unique: true
    add_reference :boosts, :custom_emote, foreign_key: true
  end
end
