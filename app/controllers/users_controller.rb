class UsersController < ApplicationController
  require_unauthenticated_access only: %i[ new create ]

  before_action :set_user, only: :show
  before_action :verify_join_code, only: %i[ new create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    account = Current.account

    if account.readme? && @user.signup_rules_acknowledgement != "1"
      @user.errors.add :signup_rules_acknowledgement, "must be accepted"
      render :new, status: :unprocessable_entity
    else
      record_signup_rules_acceptance(account) if account.readme?
      if @user.save
        EmailNotifications::NewUserSignupJob.perform_later(@user) if Rails.configuration.x.email_notifications.enabled
        start_new_session_for @user
        redirect_to root_url
      else
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to new_session_url(email_address: user_params[:email_address])
  end

  def show
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def verify_join_code
      head :not_found if Current.account.join_code != params[:join_code]
    end

    def user_params
      params.require(:user).permit(:name, :avatar, :email_address, :password, :signup_rules_acknowledgement)
    end

    def record_signup_rules_acceptance(account)
      @user.assign_attributes(
        readme_version: account.readme_version,
        readme_digest: account.readme_digest,
        signup_rules_accepted_at: Time.current,
        signup_rules_accepted_ip: request.remote_ip
      )
    end
end
