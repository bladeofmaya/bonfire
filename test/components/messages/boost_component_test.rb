require "test_helper"

class Messages::BoostComponentTest < ComponentTestCase
  test "preserves boost identity, deletion controller, and keyboard contracts" do
    boost = boosts(:first)

    render_inline Messages::BoostComponent.new(boost: boost)

    assert_component_root "##{dom_id(boost)}.boost.boost-item[data-controller='boost-delete']"
    assert_selector "[data-boost-delete-booster-id-value='#{boost.booster.id}']"
    assert_selector "[data-boost-delete-perform-class='boost--deleting'][data-boost-delete-reveal-class='expanded']"
    assert_selector "[data-boost-delete-target='content'][role='button']" \
                    "[data-action='click->boost-delete#reveal keydown.enter->boost-delete#reveal:prevent']",
      text: boost.content
    assert_selector "form.button_to input[name='_method'][value='delete']", visible: false
    assert_selector "button.boost__delete[data-action='boost-delete#perform'][data-boost-delete-target='button']"
  end

  test "provides an accessible booster label and decorative delete icon" do
    boost = boosts(:first)

    render_inline Messages::BoostComponent.new(boost: boost)

    assert_selector ".boost__avatar [aria-label='#{boost.booster.name} boosted #{boost.content}']"
    assert_selector ".boost__delete img[aria-hidden='true']"
    assert_selector ".boost__delete", text: "Delete this boost"
  end

  test "uses the larger text style only for emoji content" do
    emoji_boost = boosts(:thirteenth)

    render_inline Messages::BoostComponent.new(boost: emoji_boost)
    assert_selector "[data-boost-delete-target='content'].txt-medium", text: emoji_boost.content

    render_inline Messages::BoostComponent.new(boost: boosts(:first))
    assert_no_selector "[data-boost-delete-target='content'].txt-medium"
  end

  test "adapter cache key changes when the boost or booster changes" do
    boost = boosts(:first)
    original_key = expanded_cache_key(boost)

    boost.booster.touch
    refute_equal original_key, expanded_cache_key(boost)

    booster_key = expanded_cache_key(boost)
    boost.touch
    refute_equal booster_key, expanded_cache_key(boost)
  end

  private
    def expanded_cache_key(boost)
      ActiveSupport::Cache.expand_cache_key([ boost, boost.booster ])
    end
end
