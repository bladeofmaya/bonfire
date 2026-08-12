class Messages::BoostComponent < ApplicationComponent
  attr_reader :boost

  def initialize(boost:, avatar_source: nil)
    @boost = boost
    @avatar_source = avatar_source
  end

  def avatar_source
    @avatar_source || helpers.fresh_user_avatar_path(boost.booster)
  end

  def emoji?
    boost.content.all_emoji?
  end

  def accessible_avatar_label
    "#{boost.booster.name} boosted #{boost.content}"
  end
end
