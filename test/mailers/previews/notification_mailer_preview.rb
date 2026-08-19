class NotificationMailerPreview < ActionMailer::Preview
  def mention
    message = Message.includes(:room, :creator).last
    NotificationMailer.with(user: message.mentionees.first || message.room.users.where.not(id: message.creator_id).first, message:).mention
  end

  def daily_summary
    user = User.active.where.not(email_address: nil).first
    messages = user.reachable_messages.includes(:room, :creator).where.not(creator: user).last(8)
    NotificationMailer.with(user:, messages:, period_on: Date.yesterday).daily_summary
  end

  def new_user_signup
    NotificationMailer.with(user: User.administrator.first, new_user: User.member.last).new_user_signup
  end
end
