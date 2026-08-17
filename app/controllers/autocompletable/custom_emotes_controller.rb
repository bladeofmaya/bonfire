class Autocompletable::CustomEmotesController < ApplicationController
  def index
    emotes = Current.account.custom_emotes.active.with_attached_image.ordered
    emotes = emotes.where("shortcode LIKE ?", "%#{CustomEmote.sanitize_sql_like(params[:query])}%") if params[:query].present?
    @custom_emotes = emotes.limit(20)
  end
end
