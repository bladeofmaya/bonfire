class Rooms::InvolvementButtonComponent < ApplicationComponent
  INVOLVEMENTS = %w[ mentions everything nothing invisible ].freeze

  attr_reader :involvement, :next_involvement, :url, :label, :label_id

  def initialize(involvement:, next_involvement:, url:, label:, label_id:)
    validate_involvement(involvement)
    validate_involvement(next_involvement)

    @involvement = involvement
    @next_involvement = next_involvement
    @url = url
    @label = label
    @label_id = label_id
  end

  def icon
    "notification-bell-#{involvement}.svg"
  end

  private
    def validate_involvement(value)
      raise ArgumentError, "unsupported involvement: #{value}" unless INVOLVEMENTS.include?(value)
    end
end
