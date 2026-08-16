class RoomsController < ApplicationController
  before_action :set_room, only: %i[ show destroy ]
  before_action :ensure_can_administer, only: %i[ destroy ]
  before_action :remember_last_room_visited, only: :show
  content_security_policy only: :show do |policy|
    if @room&.stream_configured?
      if Streaming::Configuration.direct_player_enabled?
        policy.connect_src :self, @room.stream_player_origin
        policy.media_src :self, "blob:", @room.stream_player_origin
      else
        policy.frame_src :self, @room.stream_player_origin
      end
    end
  end

  def index
    redirect_to room_url(Current.user.rooms.last)
  end

  def show
    @messages = find_messages
    @sidebar_users = @room.users.active.with_attached_avatar.includes(:memberships).ordered
  end

  def destroy
    shared_room = !@room.direct?
    @room.destroy

    broadcast_remove_room
    broadcast_new_last_room if shared_room
    redirect_to root_url
  end

  private
    def set_room
      if room = room_scope.find_by(id: params[:room_id] || params[:id])
        @room = room
      else
        redirect_to root_url, alert: "Room not found or inaccessible"
      end
    end

    # Subclasses narrow this to the room types they're allowed to act on, so that one
    # room namespace can't be used to reach another's rooms.
    def room_scope
      Current.user.rooms
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@room)
    end

    def ensure_permission_to_create_rooms
      head :forbidden unless Current.user.administrator?
    end

    def find_messages
      messages = @room.messages.with_creator.with_attachment_details.with_boosts

      if show_first_message = messages.find_by(id: params[:message_id])
        @messages = messages.page_around(show_first_message)
      else
        @messages = messages.last_page
      end
    end

    def room_params
      params.require(:room).permit(:name)
    end

    def broadcast_remove_room
      broadcast_remove_to :rooms, target: [ @room, :list ]
    end

    def broadcast_new_last_room
      return unless room = Room.without_directs.order(:position, :id).last

      room.users.active.find_each do |user|
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
