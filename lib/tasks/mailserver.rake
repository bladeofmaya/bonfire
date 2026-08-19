namespace :bonfire do
  namespace :mailserver do
    desc "Send a test email to the installation's first administrator"
    task test: :environment do
      administrator = User.active.administrator.order(:created_at, :id).first
      abort "No active administrator with a registered email address was found." unless administrator&.email_address.present?

      NotificationMailer.with(user: administrator).delivery_test.deliver_now
      puts "Test email sent to #{administrator.email_address}."
    end
  end
end
