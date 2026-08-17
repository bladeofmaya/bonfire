module Message::CustomEmotes
  extend ActiveSupport::Concern

  included do
    after_save :expand_custom_emote_shortcodes
  end

  private
    def expand_custom_emote_shortcodes
      return unless body.body

      html = body.body.to_html
      return unless html.include?(":")

      emotes = Current.account&.active_custom_emotes.to_a.index_by(&:shortcode)
      return if emotes.blank?

      fragment = Nokogiri::HTML5.fragment(html)
      changed = false

      fragment.xpath(".//text()").each do |node|
        next if node.ancestors.any? { |ancestor| ancestor.name.in?(%w[ code pre a action-text-attachment ]) }

        escaped_text = ERB::Util.html_escape(node.text).to_str
        replacement = escaped_text.gsub(/:([a-z0-9][a-z0-9_-]{1,31}):/i) do |token|
          if emote = emotes[Regexp.last_match(1).downcase]
            changed = true
            ActionText::Attachment.from_attachable(emote).to_html
          else
            token
          end
        end

        node.replace(Nokogiri::HTML5.fragment(replacement)) if replacement != node.text
      end

      body.update!(body: fragment.to_html) if changed
    end
end
