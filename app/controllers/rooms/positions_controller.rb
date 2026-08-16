class Rooms::PositionsController < ApplicationController
  before_action :ensure_account_administrator

  def update
    rooms = reorder_rooms
    broadcast_rooms(*rooms)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "channel-order-status",
          "Channel order updated."
        )
      end
      format.html { redirect_back fallback_location: root_url, notice: "Channel order updated." }
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ArgumentError => error
    render plain: error.message, status: :unprocessable_entity
  end

  private
    def ensure_account_administrator
      head :forbidden unless Current.user.administrator?
    end

    def reorder_rooms
      room_ids = Array(params.require(:room_ids)).map { |id| Integer(id, 10) }
      raise ArgumentError, "Channel order contains duplicate rooms" unless room_ids.uniq.length == room_ids.length

      Room.transaction do
        authorized_rooms = Current.user.rooms.without_directs.where(id: room_ids).lock.index_by(&:id)
        raise ActiveRecord::RecordNotFound, "Unknown or inaccessible channel" unless authorized_rooms.length == room_ids.length

        positions = authorized_rooms.values.sort_by { |room| [ room.position, room.id ] }.map(&:position)
        room_ids.zip(positions).map do |room_id, position|
          authorized_rooms.fetch(room_id).tap { |room| room.update!(position: position) }
        end
      end
    end

    def broadcast_rooms(*rooms)
      rooms.each do |room|
        room.users.active.find_each do |user|
          next if user == Current.user
          membership = room.memberships.find_by!(user: user)

          html = render_to_string(
            partial: "users/sidebars/rooms/shared",
            locals: {
              room: room, unread: membership.unread?, unread_mention_count: membership.unread_mention_count,
              administrator: user.administrator?
            }
          )
          broadcast_replace_to user, :rooms, target: [ room, :list ], html: html
        end
      end
    end
end
