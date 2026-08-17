class Accounts::CustomEmotesController < ApplicationController
  before_action :ensure_can_administer
  before_action :set_emote, only: %i[ update destroy ]

  def create
    emote = Current.account.custom_emotes.new(emote_params)
    if emote.save
      Current.account.touch
      redirect_to emotes_settings_url, notice: ":#{emote.shortcode}: added"
    else
      redirect_to emotes_settings_url, alert: emote.errors.full_messages.to_sentence
    end
  end

  def update
    if @emote.update(emote_params)
      Current.account.touch
      redirect_to emotes_settings_url, notice: ":#{@emote.shortcode}: updated"
    else
      redirect_to emotes_settings_url, alert: @emote.errors.full_messages.to_sentence
    end
  end

  def destroy
    @emote.disable!
    Current.account.touch
    redirect_to emotes_settings_url, notice: ":#{@emote.shortcode}: removed from the picker"
  end

  private
    def set_emote
      @emote = Current.account.custom_emotes.active.find(params[:id])
    end

    def emote_params
      params.require(:custom_emote).permit(:shortcode, :image)
    end

    def emotes_settings_url
      edit_account_url(tab: "emotes", anchor: "emotes")
    end
end
