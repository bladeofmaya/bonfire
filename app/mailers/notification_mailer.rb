class NotificationMailer < ApplicationMailer
  helper :rooms

  def mention
    @user = params[:user]
    @message = params[:message]
    @room = @message.room
    mail to: @user.email_address, subject: "#{@message.creator.name} mentioned you in #{room_name(@room, @user)}"
  end

  def daily_summary
    @user = params[:user]
    @messages = params[:messages]
    @period_on = params[:period_on]
    @messages_by_room = @messages.group_by(&:room)
    mail to: @user.email_address, subject: "Your Bonfire summary for #{@period_on.to_fs(:long)}"
  end

  def new_user_signup
    @user = params[:user]
    @new_user = params[:new_user]
    mail to: @user.email_address, subject: "#{@new_user.name} joined Bonfire"
  end

  def delivery_test
    @user = params[:user]
    mail to: @user.email_address, subject: "Bonfire email delivery test"
  end

  def stream_live
    @user = params[:user]
    @room = params[:room]
    @stream_name = @room.stream_title.presence || @room.name
    mail to: @user.email_address, subject: "#{@stream_name} is live now"
  end

  helper_method :notification_settings_url

  private
    def notification_settings_url
      user_profile_url(anchor: "notifications")
    end

    def room_name(room, user)
      return room.name if room.name.present? || !room.direct?

      room.users.where.not(id: user.id).pluck(:name).to_sentence.presence || user.name
    end
end
