class Rooms::DirectPlaceholderComponent < ApplicationComponent
  attr_reader :user, :url

  def initialize(user:, url:, avatar_source: nil)
    @user = user
    @url = url
    @avatar_source = avatar_source
  end

  def accessible_label
    "Start a ping with #{user.name}"
  end

  def short_name
    user.name.split.first
  end

  def avatar_source
    @avatar_source || helpers.fresh_user_avatar_path(user)
  end
end
