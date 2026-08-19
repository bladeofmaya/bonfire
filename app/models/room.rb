class Room < ApplicationRecord
  include Referenceable, Streaming

  has_many :memberships, dependent: :delete_all do
    def grant_to(users)
      room = proxy_association.owner
      Membership.insert_all(Array(users).collect { |user| { room_id: room.id, user_id: user.id, involvement: room.default_involvement } })
    end

    def revoke_from(users)
      destroy_by user: users
    end

    def revise(granted: [], revoked: [])
      transaction do
        grant_to(granted) if granted.present?
        revoke_from(revoked) if revoked.present?
      end
    end
  end

  has_many :users, through: :memberships
  has_many :messages, dependent: :destroy
  has_one_attached :stream_poster
  has_rich_text :stream_description

  belongs_to :creator, class_name: "User", default: -> { Current.user }

  validate :direct_rooms_keep_their_type, on: :update
  validate :stream_configuration_is_valid
  before_create :place_shared_room_last

  scope :opens,           -> { where(type: "Rooms::Open") }
  scope :closeds,         -> { where(type: "Rooms::Closed") }
  scope :directs,         -> { where(type: "Rooms::Direct") }
  scope :without_directs, -> { where.not(type: "Rooms::Direct") }

  scope :ordered, -> { order("LOWER(name)") }

  class << self
    def create_for(attributes, users:)
      transaction do
        create!(attributes).tap do |room|
          room.memberships.grant_to users
        end
      end
    end

    def original
      order(:created_at).first
    end
  end

  def receive(message)
    unread_memberships(message)
    push_later(message)
    email_mentions_later(message)
  end

  def open?
    is_a?(Rooms::Open)
  end

  def closed?
    is_a?(Rooms::Closed)
  end

  def direct?
    is_a?(Rooms::Direct)
  end

  def default_involvement
    "mentions"
  end

  def stream_configured?
    stream_enabled? && stream_player_uri.present? && stream_path.to_s.match?(STREAM_PATH_FORMAT) &&
      !stream_path.include?("..") && !stream_path.start_with?("/") &&
      ::Streaming::Configuration.allowed_player_origin?(stream_player_origin)
  end

  def stream_player_origin
    uri = stream_player_uri
    "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.default_port == uri.port}" if uri
  end

  def stream_player_uri
    URI.parse(stream_player_url) if stream_player_url.present?
  rescue URI::InvalidURIError
    nil
  end

  private
    STREAM_PATH_FORMAT = /\A[a-zA-Z0-9](?:[a-zA-Z0-9._\/-]*[a-zA-Z0-9])?\z/

    def stream_configuration_is_valid
      validate_stream_player_url if stream_player_url.present? || stream_enabled?
      validate_stream_path if stream_path.present? || stream_enabled?
      if stream_poster.attached? && !stream_poster.blob.content_type.to_s.start_with?("image/")
        errors.add :stream_poster, "must be an image"
      end
    end

    def validate_stream_player_url
      uri = stream_player_uri
      if uri.nil? || !uri.is_a?(URI::HTTP) || uri.host.blank?
        errors.add :stream_player_url, "is invalid"
      elsif !Rails.env.development? && uri.scheme != "https"
        errors.add :stream_player_url, "must use HTTPS"
      elsif uri.userinfo.present? || uri.query.present? || uri.fragment.present?
        errors.add :stream_player_url, "must not contain credentials, a query, or a fragment"
      elsif !::Streaming::Configuration.allowed_player_origin?(stream_player_origin)
        errors.add :stream_player_url, "origin is not allowed"
      end
    end

    def validate_stream_path
      unless stream_path.to_s.match?(STREAM_PATH_FORMAT) && !stream_path.include?("..") && !stream_path.start_with?("/")
        errors.add :stream_path, "is invalid"
      end
    end

    def place_shared_room_last
      self.position ||= Room.without_directs.maximum(:position).to_i + 1 unless direct?
    end

    # Open and closed rooms convert into each other freely. A direct room can't become
    # either: its participants agreed to a private conversation, not to one whose
    # audience someone else gets to widen afterwards.
    def direct_rooms_keep_their_type
      if type_changed? && type_was == "Rooms::Direct"
        errors.add :type, "can't be changed for a direct room"
      end
    end

    def unread_memberships(message)
      recipients = memberships.where.not(user: message.creator)

      restored_memberships = direct? ? restore_hidden_direct_memberships(recipients) : []

      recipients.visible.disconnected.update_all(
        unread_at: message.created_at,
        unread_count: Arel.sql("unread_count + 1"),
        updated_at: Time.current
      )

      recipients.visible.disconnected.where(user_id: message.mentionees.select(:id)).update_all(
        unread_mention_count: Arel.sql("unread_mention_count + 1"),
        updated_at: Time.current
      )

      restored_memberships.each { |membership| membership.reload.broadcast_direct_list_item }
    end

    def restore_hidden_direct_memberships(recipients)
      recipients.involved_in_invisible.to_a.each do |membership|
        membership.update!(involvement: :everything)
      end
    end

    def push_later(message)
      Room::PushMessageJob.perform_later(self, message)
    end

    def email_mentions_later(message)
      return unless Rails.configuration.x.email_notifications.enabled
      return unless direct? || message.mentionees.exists?

      EmailNotifications::MentionJob.set(wait: EmailNotifications::MentionJob::OFFLINE_GRACE_PERIOD).perform_later(message)
    end
end
