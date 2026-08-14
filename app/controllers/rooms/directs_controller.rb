class Rooms::DirectsController < RoomsController
  before_action :set_room, only: %i[ edit update destroy ]
  before_action :ensure_account_administrator, only: %i[ edit update destroy ]
  def new
    @room = Rooms::Direct.new
    @users = User.active.where.not(id: Current.user.id).ordered
  end

  def create
    if selected_users_ids.blank?
      @room = Rooms::Direct.new(name: direct_room_name)
      @users = User.active.where.not(id: Current.user.id).ordered
      @selection_error = "Choose at least one person to ping."
      return render :new, status: :unprocessable_entity
    end

    room = Rooms::Direct.find_or_create_for(selected_users, name: direct_room_name)
    room.memberships.where(user: Current.user, involvement: :invisible).update_all(involvement: :everything, updated_at: Time.current)

    broadcast_create_room(room)
    redirect_to room_url(room)
  end

  def edit
    @participants = @room.users.active.with_attached_avatar.ordered
  end

  def update
    @room.update!(name: direct_room_name.presence)
    broadcast_update_room(@room)

    redirect_to room_url(@room)
  end

  private
    def selected_users
      User.where(id: selected_users_ids.including(Current.user.id))
    end

    def selected_users_ids
      params.fetch(:user_ids, [])
    end

    def direct_room_name
      params.fetch(:room, {}).permit(:name)[:name]
    end

    def broadcast_create_room(room)
      memberships = room.memberships.to_a
      ActiveRecord::Associations::Preloader.new(
        records: memberships, associations: [ :user, { room: :users } ]
      ).call

      memberships.reject(&:involved_in_invisible?).each(&:broadcast_direct_list_item)
    end

    def broadcast_update_room(room)
      memberships = room.memberships.visible.to_a
      ActiveRecord::Associations::Preloader.new(
        records: memberships, associations: [ :user, { room: :users } ]
      ).call

      memberships.each(&:broadcast_replace_direct_list_item)
    end

    def ensure_account_administrator
      head :forbidden unless Current.user.administrator?
    end

    def room_scope
      Current.user.rooms.directs
    end
end
