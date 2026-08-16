class Streaming::Configuration
  class Error < StandardError; end

  class << self
    def configured?
      private_key_pem.present? && key_id.present? && issuer.present? && audience.present? && allowed_player_origins.any?
    end

    def validate!
      raise Error, "RTMP Homebrew signing configuration is incomplete" unless configured?
      private_key
      previous_jwks
      allowed_player_origins.each { |origin| validate_origin!(origin) }
      true
    rescue OpenSSL::PKey::PKeyError, JSON::ParserError => error
      raise Error, "RTMP Homebrew signing configuration is invalid: #{error.class}"
    end

    def validate_startup!
      validate! if configured_values_present?
    end

    def private_key
      @private_key ||= OpenSSL::PKey::EC.new(private_key_pem)
    end

    def key_id = value(:key_id, env: "RTMP_HOMEBREW_KEY_ID")
    def issuer = value(:issuer, env: "RTMP_HOMEBREW_ISSUER")
    def audience = value(:audience, env: "RTMP_HOMEBREW_AUDIENCE") || "rtmp-homebrew"
    def event_secret = value(:event_secret, env: "RTMP_HOMEBREW_EVENT_SECRET")

    def allowed_player_origins
      raw = value(:allowed_player_origins, env: "RTMP_HOMEBREW_ALLOWED_PLAYER_ORIGINS")
      Array(raw.is_a?(String) ? raw.split(",") : raw).map(&:strip).compact_blank.uniq
    end

    def allowed_player_origin?(origin)
      origin.present? && allowed_player_origins.include?(origin)
    end

    def previous_jwks
      raw = value(:previous_jwks, env: "RTMP_HOMEBREW_PREVIOUS_JWKS")
      return [] if raw.blank?
      parsed = raw.is_a?(String) ? JSON.parse(raw) : raw
      Array(parsed.respond_to?(:[]) && (parsed["keys"] || parsed[:keys]) || parsed).map do |key|
        key.to_h.except("d", :d)
      end
    end

    def reset!
      @private_key = nil
    end

    private
      def private_key_pem
        value(:private_key, env: "RTMP_HOMEBREW_PRIVATE_KEY")&.gsub("\\n", "\n")
      end

      def credentials
        Rails.application.credentials.rtmp_homebrew || {}
      end

      def value(key, env:)
        ENV[env].presence || credentials[key]
      end

      def configured_values_present?
        private_key_pem.present? || key_id.present? || issuer.present? ||
          value(:previous_jwks, env: "RTMP_HOMEBREW_PREVIOUS_JWKS").present?
      end

      def validate_origin!(origin)
        uri = URI.parse(origin)
        valid = uri.is_a?(URI::HTTPS) && uri.host.present? && uri.path.in?([ "", "/" ]) && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
        raise Error, "RTMP Homebrew player origin is invalid" unless valid || Rails.env.development? && uri.is_a?(URI::HTTP)
      end
  end
end
