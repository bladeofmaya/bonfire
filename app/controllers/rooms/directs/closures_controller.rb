class Rooms::Directs::ClosuresController < ApplicationController
  before_action :set_membership

  def create
    @membership.update!(involvement: :invisible, unread_at: nil, unread_count: 0)
    @membership.broadcast_remove_to Current.user, :rooms,
      target: ActionView::RecordIdentifier.dom_id(@membership.room, :list)

    head :no_content
  end

  private
    def set_membership
      @membership = Current.user.memberships.joins(:room)
        .where(room: { type: "Rooms::Direct" })
        .find_by!(room_id: params[:direct_id])
    end
end
