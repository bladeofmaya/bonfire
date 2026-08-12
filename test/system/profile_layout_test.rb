require "application_system_test_case"

class ProfileLayoutTest < ApplicationSystemTestCase
  setup do
    sign_in "david@37signals.com"
  end

  test "long conversation names truncate inside the profile panel" do
    long_name = "Steel of Sky the third, lord of the lands between and protector of the realm"
    rooms(:watercooler).update! name: long_name

    visit user_profile_path

    link = find(".membership-item a[title='#{long_name}']")
    fieldset = find("fieldset.conversations-settings")

    assert_operator width_of(link, :scrollWidth), :>, width_of(link, :clientWidth)
    assert_operator width_of(fieldset, :scrollWidth), :<=, width_of(fieldset, :clientWidth)
  end

  private
    def width_of(element, property)
      page.evaluate_script("arguments[0].#{property}", element)
    end
end
