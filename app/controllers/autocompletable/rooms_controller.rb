class Autocompletable::RoomsController < ApplicationController
  def index
    current_room = Current.user.rooms.find(params[:room_id])
    rooms = visible_shared_rooms.where.not(id: current_room.id)
    rooms = rooms.where("rooms.name LIKE ?", "%#{params[:query]}%") if params[:query].present?

    set_page_and_extract_portion_from rooms.ordered, per_page: 20
  end

  private
    def visible_shared_rooms
      Room.without_directs.joins(:memberships)
        .merge(Current.user.memberships.visible)
        .distinct
    end
end
