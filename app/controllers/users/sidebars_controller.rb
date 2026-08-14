class Users::SidebarsController < ApplicationController
  def show
    all_memberships     = Current.user.memberships.visible.with_ordered_room
    @direct_memberships = extract_direct_memberships(all_memberships)
    @other_memberships  = all_memberships.without(@direct_memberships)
    preload_direct_participants
    @direct_participants = @direct_memberships.to_h do |membership|
      [ membership.id, direct_participants_for(membership) ]
    end
  end

  private
    def extract_direct_memberships(all_memberships)
      all_memberships.select { |m| m.room.direct? }.sort_by { |m| m.room.updated_at }.reverse
    end

    def preload_direct_participants
      ActiveRecord::Associations::Preloader.new(
        records: @direct_memberships, associations: [ :user, { room: :users } ]
      ).call
    end

    def direct_participants_for(membership)
      membership.room.users.to_a.without(membership.user).presence || [ membership.user ]
    end
end
