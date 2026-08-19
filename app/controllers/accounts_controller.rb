class AccountsController < ApplicationController
  before_action :ensure_can_administer, only: :update
  before_action :set_account

  def edit
    users = account_users.ordered.without_bots
    @administrators, @members = users.partition(&:administrator?)
    if Current.user.administrator?
      @custom_emotes = @account.active_custom_emotes
      @email_notification_users = User.active.without_bots.where(email_notifications_enabled: true).ordered.with_attached_avatar
      @email_configuration_checks = email_configuration_checks
    end
    set_page_and_extract_portion_from users, per_page: 500
  end

  def update
    readme = account_params.delete(:readme)
    @account.transaction do
      @account.update!(account_params)
      @account.publish_readme!(readme) unless readme.nil?
    end
    redirect_to edit_account_url, notice: "Account settings saved"
  end

  private
    def set_account
      @account = Current.account
    end

    def account_params
      params.require(:account).permit(
        :name,
        :logo,
        :readme,
        settings: [ :restrict_room_creation_to_administrators ]
      )
    end

    def account_users
      if Current.user.can_administer?
        User.where(status: [ :active, :banned ])
      else
        User.active
      end
    end

    def email_configuration_checks
      provider = Rails.configuration.x.email_notifications.provider
      checks = [
        [ "Provider: #{provider == 'postmark' ? 'Postmark' : 'SMTP'}", %w[postmark smtp].include?(provider) ],
        [ "Canonical mail host", ENV["MAILER_HOST"].present? || ENV["TLS_DOMAIN"].present? ],
        [ "Sender address", ENV["EMAIL_FROM"].present? ]
      ]
      checks + if provider == "postmark"
        [ [ "Postmark server token", ENV["POSTMARK_SERVER_TOKEN"].present? ] ]
      else
        [
          [ "SMTP server and port", ENV["SMTP_ADDRESS"].present? && ENV["SMTP_PORT"].present? ],
          [ "SMTP credentials", ENV["SMTP_USERNAME"].present? && ENV["SMTP_PASSWORD"].present? ]
        ]
      end
    end
end
