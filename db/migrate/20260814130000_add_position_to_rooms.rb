class AddPositionToRooms < ActiveRecord::Migration[8.2]
  def up
    add_column :rooms, :position, :integer
    add_index :rooms, [ :position, :id ]

    execute <<~SQL
      UPDATE rooms
      SET position = (
        SELECT COUNT(*)
        FROM rooms ordered_rooms
        WHERE ordered_rooms.type != 'Rooms::Direct'
          AND (
            LOWER(ordered_rooms.name) < LOWER(rooms.name)
            OR (LOWER(ordered_rooms.name) = LOWER(rooms.name) AND ordered_rooms.id <= rooms.id)
          )
      )
      WHERE type != 'Rooms::Direct'
    SQL
  end

  def down
    remove_index :rooms, column: [ :position, :id ]
    remove_column :rooms, :position
  end
end
