require "test_helper"

class Streaming::ConfigurationTest < ActiveSupport::TestCase
  teardown { Streaming::Configuration.reset! }

  test "validates a complete ES256 configuration" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    Streaming::Configuration.stubs(
      private_key_pem: key.to_pem,
      key_id: "current-key",
      issuer: "https://bonfire.example.test",
      audience: "rtmp-homebrew",
      allowed_player_origins: [ "https://stream.example.test" ],
      previous_jwks: []
    )

    assert Streaming::Configuration.validate!
  end

  test "rejects incomplete configuration and non-origin player URLs" do
    Streaming::Configuration.stubs(
      private_key_pem: nil,
      key_id: nil,
      issuer: nil,
      audience: "rtmp-homebrew",
      allowed_player_origins: []
    )
    assert_raises(Streaming::Configuration::Error) { Streaming::Configuration.validate! }

    key = OpenSSL::PKey::EC.generate("prime256v1")
    Streaming::Configuration.stubs(
      private_key_pem: key.to_pem,
      key_id: "current-key",
      issuer: "https://bonfire.example.test",
      allowed_player_origins: [ "https://stream.example.test/player" ],
      previous_jwks: []
    )
    assert_raises(Streaming::Configuration::Error) { Streaming::Configuration.validate! }
  end

  test "strips private key material from configured overlap keys" do
    Streaming::Configuration.stubs(:value).with(:previous_jwks, env: "RTMP_HOMEBREW_PREVIOUS_JWKS").returns(
      { "keys" => [ { "kty" => "EC", "kid" => "old", "d" => "private" } ] }.to_json
    )

    assert_equal [ { "kty" => "EC", "kid" => "old" } ], Streaming::Configuration.previous_jwks
  end
end
