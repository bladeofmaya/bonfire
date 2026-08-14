require "test_helper"

class Streaming::JwksTest < ActiveSupport::TestCase
  test "publishes current and previous public keys without private material" do
    previous_key = OpenSSL::PKey::EC.generate("prime256v1")
    previous_jwk = JWT::JWK.new(previous_key, "test-previous-key").export
    current_key = configure_streaming(previous_jwks: [ previous_jwk ])

    jwks = Streaming::Jwks.as_json

    assert_equal %w[ test-current-key test-previous-key ], jwks[:keys].map { |key| key[:kid] || key["kid"] }
    assert jwks[:keys].none? { |key| key.key?(:d) || key.key?("d") }

    token = Streaming::PlaybackGrant.new(room: configured_room, user: users(:david)).token
    public_key = JWT::JWK.import(jwks[:keys].first).public_key
    assert JWT.decode(token, public_key, true, algorithm: "ES256").first
    assert current_key.private?
  end

  private
    def configured_room
      rooms(:watercooler).tap do |room|
        room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live")
      end
    end
end
