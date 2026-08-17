module CustomEmoteTestHelper
  TINY_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  ).freeze

  def attach_test_emote_image(emote, filename: "emote.png")
    emote.image.attach(io: StringIO.new(TINY_PNG), filename:, content_type: "image/png")
  end

  def tiny_emote_upload
    file = Tempfile.new([ "emote", ".png" ])
    file.binmode
    file.write(TINY_PNG)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "image/png", original_filename: "emote.png")
  end
end
