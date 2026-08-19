class Users::ProfilesController < ApplicationController
  before_action :set_user

  def show
    @direct_memberships, @shared_memberships =
      Current.user.memberships.with_ordered_room.partition { |m| m.room.direct? }
  end

  def update
    @user.update user_params
    redirect_to user_profile_url, notice: update_notice
  end

  private
    def set_user
      @user = Current.user
    end

    def user_params
      permitted = %i[ name avatar email_address password bio ]
      if Rails.configuration.x.email_notifications.enabled
        permitted.concat %i[
          email_notifications_enabled email_mentions_enabled email_daily_summary_enabled
          email_digest_hour email_time_zone
        ]
      end
      params.require(:user).permit(*permitted).compact
    end

    def update_notice
      params[:user][:avatar] ? "It may take up to 30 minutes to change everywhere." : "Profile updated"
    end
end
