class Rooms::StreamsController < ApplicationController
  include RoomScoped

  before_action :ensure_account_administrator

  def update
    @room.assign_attributes(stream_params)

    if @room.save
      @room.stream_poster.purge if remove_stream_poster?
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
      params.require(:room).permit(:stream_enabled, :stream_player_url, :stream_path, :stream_title, :stream_poster)
    end

    def remove_stream_poster?
      ActiveModel::Type::Boolean.new.cast(params.dig(:room, :remove_stream_poster))
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
end
