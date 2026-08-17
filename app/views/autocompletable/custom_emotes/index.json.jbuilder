json.array! @custom_emotes do |emote|
  json.name ":#{emote.shortcode}:"
  json.value emote.id
  json.sgid emote.attachable_sgid
  json.shortcode emote.shortcode
  json.avatar_url rails_blob_path(emote.image, only_path: true)
end
