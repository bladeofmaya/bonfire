require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "publishing README versions changed content" do
    account = accounts(:signal)

    assert_changes -> { account.reload.readme_version }, from: 0, to: 1 do
      account.publish_readme!("We store your profile data.")
    end

    assert account.readme?
    assert account.readme_digest.present?
    assert account.readme_published_at.present?

    assert_no_changes -> { account.reload.readme_version } do
      account.publish_readme!("We store your profile data.")
    end

    account.publish_readme!("")
    assert_not account.reload.readme?
    assert_nil account.readme_digest
    assert_nil account.readme_published_at
    assert_equal 2, account.readme_version
  end

  test "settings" do
    accounts(:signal).settings.restrict_room_creation_to_administrators = true
    assert accounts(:signal).settings.restrict_room_creation_to_administrators?
    assert_equal({ "restrict_room_creation_to_administrators" => true }, accounts(:signal)[:settings])

    accounts(:signal).update!(settings: { "restrict_room_creation_to_administrators" => "true" })
    assert accounts(:signal).reload.settings.restrict_room_creation_to_administrators?

    accounts(:signal).settings.restrict_room_creation_to_administrators = false
    assert_not accounts(:signal).settings.restrict_room_creation_to_administrators?
    assert_equal({ "restrict_room_creation_to_administrators" => false }, accounts(:signal)[:settings])
    accounts(:signal).update!(settings: { "restrict_room_creation_to_administrators" => "false" })
    assert_not accounts(:signal).reload.settings.restrict_room_creation_to_administrators?
  end

  test "logo_variant is a resized variant of a variable logo" do
    accounts(:signal).logo.attach io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"

    assert_kind_of ActiveStorage::VariantWithRecord, accounts(:signal).logo_variant(:large)
  end

  test "logo_variant is nil when the logo cannot be resized" do
    accounts(:signal).logo.attach io: file_fixture("pixel.bmp").open, filename: "pixel.bmp", content_type: "image/bmp"

    assert_nil accounts(:signal).logo_variant(:large)
  end

  test "logo_variant is nil without a logo" do
    assert_nil accounts(:signal).logo_variant(:large)
  end
end
