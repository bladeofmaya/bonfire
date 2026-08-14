class Membership < ApplicationRecord
  include Connectable

  belongs_to :room
  belongs_to :user

  after_destroy_commit { user.reset_remote_connections }

  enum :involvement, %w[ invisible nothing mentions everything ].index_by(&:itself), prefix: :involved_in

  scope :with_ordered_room, -> { includes(:room).joins(:room).order("LOWER(rooms.name)") }
  scope :without_direct_rooms, -> { joins(:room).where.not(room: { type: "Rooms::Direct" }) }

  scope :visible, -> { where.not(involvement: :invisible) }
  scope :unread,  -> { where.not(unread_at: nil) }

  def read
    update!(unread_at: nil, unread_count: 0)
  end

  def unread?
    unread_at.present?
  end

  def broadcast_direct_list_item
    association(:user).load_target
    ActiveRecord::Associations::Preloader.new(records: [ self ], associations: { room: :users }).call

    broadcast_prepend_to user, :rooms, target: :direct_rooms,
      partial: "users/sidebars/rooms/direct",
      locals: { participants: room.users.to_a.without(user).presence || [ user ] }
  end

  def broadcast_replace_direct_list_item
    association(:user).load_target
    ActiveRecord::Associations::Preloader.new(records: [ self ], associations: { room: :users }).call

    broadcast_replace_to user, :rooms,
      target: ActionView::RecordIdentifier.dom_id(room, :list),
      partial: "users/sidebars/rooms/direct",
      locals: { participants: room.users.to_a.without(user).presence || [ user ] }
  end
end
