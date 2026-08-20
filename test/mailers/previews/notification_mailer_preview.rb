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

  def delivery_test
    NotificationMailer.with(user: User.administrator.first).delivery_test
  end

  def stream_live
    source = Room.where(stream_enabled: true).first || Room.first
    room = source.dup
    room.id = source.id
    room.stream_enabled = true
    room.stream_title = "Friday Night at the Bonfire"
    room.stream_description = <<~HTML
      <p>Join us for a relaxed community stream with conversation, games, and a few surprises.</p>
      <h2>Tonight’s plan</h2>
      <ul>
        <li>Community updates</li>
        <li>Live questions from chat</li>
        <li>A first look at what we’re building next</li>
      </ul>
      <p>Bring a drink and <a href="https://example.com">invite a friend</a>.</p>
    HTML

    NotificationMailer.with(user: User.active.where.not(email_address: nil).first, room:).stream_live
  end
end
