class Rooms::StreamsController < ApplicationController
  include RoomScoped

  before_action :ensure_account_administrator

  def update
    @room.assign_attributes(stream_params)

    if @room.save
      @room.clear_stream_state! if stream_identity_changed_or_disabled?
      @room.stream_poster.purge if remove_stream_poster?
      broadcast_sidebar_update
      redirect_to "#{stream_settings_url}#streaming", notice: "Stream settings updated"
    else
      prepare_room_form
      render stream_settings_template, status: :unprocessable_entity
    end
  end

  private
    def ensure_account_administrator
      head :forbidden unless Current.user.administrator?
    end

    def stream_params
      params.require(:room).permit(:stream_enabled, :stream_player_url, :stream_path, :stream_title, :stream_description, :stream_poster)
    end

    def remove_stream_poster?
      ActiveModel::Type::Boolean.new.cast(params.dig(:room, :remove_stream_poster))
    end

    def stream_identity_changed_or_disabled?
      !@room.stream_enabled? || @room.saved_change_to_stream_path?
    end

    def stream_settings_url
      @room.open? ? edit_rooms_open_url(@room) : edit_rooms_closed_url(@room)
    end

    def stream_settings_template
      @room.open? ? "rooms/opens/edit" : "rooms/closeds/edit"
    end

    def prepare_room_form
      if @room.open?
        @users = User.active.ordered
      else
        selected_user_ids = @room.users.pluck(:id)
        @selected_users, @unselected_users = User.active.ordered.partition { |user| selected_user_ids.include?(user.id) }
      end
    end

    def broadcast_sidebar_update
      return if @room.direct?

      @room.users.active.find_each do |user|
        membership = @room.memberships.find_by!(user: user)
        broadcast_replace_to user, :rooms, target: [ @room, :list ],
          partial: "users/sidebars/rooms/shared",
          locals: {
            room: @room, unread: membership.unread?, unread_mention_count: membership.unread_mention_count,
            administrator: user.administrator?
          }
      end
    end
end
