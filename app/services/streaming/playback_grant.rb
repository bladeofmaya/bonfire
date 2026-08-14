class Streaming::PlaybackGrant
  LIFETIME = 60.seconds
  CLOCK_SKEW = 5.seconds

  attr_reader :room, :user, :issued_at, :expires_at

  def initialize(room:, user:, now: Time.current)
    @room = room
    @user = user
    @issued_at = now
    @expires_at = now + LIFETIME
  end

  def token
    Streaming::Configuration.validate!
    JWT.encode(claims, Streaming::Configuration.private_key, "ES256", kid: Streaming::Configuration.key_id)
  end

  def claims
    {
      iss: Streaming::Configuration.issuer,
      aud: Streaming::Configuration.audience,
      sub: "bonfire-user:#{user.id}",
      iat: issued_at.to_i,
      nbf: (issued_at - CLOCK_SKEW).to_i,
      exp: expires_at.to_i,
      jti: SecureRandom.uuid,
      room_id: room.id.to_s,
      mediamtx_permissions: [ { action: "read", path: room.stream_path } ]
    }
  end
end
