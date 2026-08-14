require "test_helper"

class Streaming::JwksControllerTest < ActionDispatch::IntegrationTest
  test "is public cacheable and contains public keys only" do
    configure_streaming

    get rtmp_homebrew_jwks_url

    assert_response :success
    assert_match(/public/, response.headers["Cache-Control"])
    assert_match(/max-age=300/, response.headers["Cache-Control"])
    key = response.parsed_body.fetch("keys").sole
    assert_equal "test-current-key", key["kid"]
    assert_nil key["d"]
  end

  test "returns unavailable without signing configuration" do
    Streaming::Configuration.stubs(configured?: false)
    Streaming::Configuration.stubs(:validate!).raises(Streaming::Configuration::Error)

    get rtmp_homebrew_jwks_url
    assert_response :service_unavailable
  end
end
