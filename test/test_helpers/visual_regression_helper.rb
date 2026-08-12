require "chunky_png"

module VisualRegressionHelper
  VISUAL_BASELINE_PATH = Rails.root.join("test/visual_baselines")
  MAX_CHANGED_PIXEL_RATIO = 0.002
  MAX_CHANNEL_DELTA = 12

  def assert_visual_match(name, selector:, max_changed_pixel_ratio: MAX_CHANGED_PIXEL_RATIO)
    prepare_visual_capture
    actual = ChunkyPNG::Image.from_blob(find(selector).native.screenshot_as(:png))
    baseline_path = VISUAL_BASELINE_PATH.join("#{name}.png")

    if ENV["UPDATE_VISUAL_BASELINES"] == "1"
      baseline_path.dirname.mkpath
      actual.save(baseline_path)
    end

    assert baseline_path.exist?, "Missing visual baseline #{baseline_path}. Run UPDATE_VISUAL_BASELINES=1 bin/rails test test/system/visual_regression_test.rb"

    baseline = ChunkyPNG::Image.from_file(baseline_path)
    assert_equal [ baseline.width, baseline.height ], [ actual.width, actual.height ],
      "#{name} dimensions changed; run with UPDATE_VISUAL_BASELINES=1 after reviewing the UI"

    changed_pixels = changed_pixel_count(baseline, actual)
    changed_ratio = changed_pixels.fdiv(actual.width * actual.height)

    assert_operator changed_ratio, :<=, max_changed_pixel_ratio,
      "#{name} changed by #{(changed_ratio * 100).round(3)}% (#{changed_pixels} pixels); " \
      "run with UPDATE_VISUAL_BASELINES=1 after reviewing the UI"
  end

  private
    def prepare_visual_capture
      page.execute_script <<~JS
        document.documentElement.dataset.theme = "dark";
        document.documentElement.style.colorScheme = "dark";
        document.querySelectorAll("video, audio").forEach((element) => element.pause());

        const style = document.createElement("style");
        style.dataset.visualRegression = "true";
        style.textContent = `
          *, *::before, *::after {
            animation: none !important;
            caret-color: transparent !important;
            transition: none !important;
          }
        `;
        document.head.appendChild(style);
      JS
    end

    def changed_pixel_count(baseline, actual)
      baseline.pixels.zip(actual.pixels).count do |expected, observed|
        color_channels(expected).zip(color_channels(observed)).any? do |left, right|
          (left - right).abs > MAX_CHANNEL_DELTA
        end
      end
    end

    def color_channels(pixel)
      [ ChunkyPNG::Color.r(pixel), ChunkyPNG::Color.g(pixel),
        ChunkyPNG::Color.b(pixel), ChunkyPNG::Color.a(pixel) ]
    end
end
