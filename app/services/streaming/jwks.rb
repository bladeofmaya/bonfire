class Streaming::Jwks
  def self.as_json
    Streaming::Configuration.validate!
    current = JWT::JWK.new(Streaming::Configuration.private_key, Streaming::Configuration.key_id).export
    { keys: [ current, *Streaming::Configuration.previous_jwks ].uniq { |key| key[:kid] || key["kid"] } }
  end
end
