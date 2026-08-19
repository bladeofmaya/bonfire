require "fileutils"
require "json"
require "io/console"
require "open3"
require "optparse"
require "resolv"
require "shellwords"
require "time"

module Bonfire
  module Deployment
    CONFIG_PATH = ".kamal/deploy.env"
    SECRETS_PATH = ".kamal/secrets"
    MIGRATION_PATH = ".kamal/migration.json"

    CONFIG_KEYS = %w[
      DEPLOY_HOST
      DEPLOY_SERVER
      DEPLOY_SSH_USER
      DEPLOY_STORAGE_PATH
      DEPLOY_STORAGE_UID
      KAMAL_SERVICE
      KAMAL_IMAGE
      KAMAL_REGISTRY
      KAMAL_BUILDER_ARCH
      EMAIL_NOTIFICATIONS_ENABLED
      EMAIL_PROVIDER
      EMAIL_FROM
      MAILER_HOST
      MAILER_PROTOCOL
      POSTMARK_MESSAGE_STREAM
      SMTP_ADDRESS
      SMTP_PORT
      SMTP_AUTHENTICATION
      SMTP_STARTTLS
    ].freeze

    SECRET_KEYS = %w[SECRET_KEY_BASE VAPID_PRIVATE_KEY VAPID_PUBLIC_KEY].freeze
    OPTIONAL_SECRET_KEYS = %w[
      RAILS_MASTER_KEY
      POSTMARK_SERVER_TOKEN
      SMTP_USERNAME
      SMTP_PASSWORD
      RTMP_HOMEBREW_PRIVATE_KEY
      RTMP_HOMEBREW_KEY_ID
      RTMP_HOMEBREW_ISSUER
      RTMP_HOMEBREW_AUDIENCE
      RTMP_HOMEBREW_ALLOWED_PLAYER_ORIGINS
      RTMP_HOMEBREW_EVENT_SECRET
    ].freeze
    SENSITIVE_KAMAL_ARGUMENTS = %w[config secrets console shell dbc].freeze
    SENSITIVE_KAMAL_SEQUENCES = [ %w[app exec], %w[accessory exec] ].freeze

    DEFAULTS = {
      "DEPLOY_SSH_USER" => "root",
      "DEPLOY_STORAGE_PATH" => "/var/lib/kamal/bonfire/storage",
      "DEPLOY_STORAGE_UID" => "1000",
      "KAMAL_SERVICE" => "bonfire",
      "KAMAL_IMAGE" => "bonfire",
      "KAMAL_REGISTRY" => "localhost:5555",
      "KAMAL_BUILDER_ARCH" => "amd64",
      "EMAIL_NOTIFICATIONS_ENABLED" => "false",
      "EMAIL_PROVIDER" => "postmark",
      "MAILER_PROTOCOL" => "https",
      "POSTMARK_MESSAGE_STREAM" => "outbound",
      "SMTP_AUTHENTICATION" => "plain",
      "SMTP_STARTTLS" => "true"
    }.freeze

    class Error < StandardError; end

    class EnvironmentFile
      attr_reader :path

      def initialize(path, allowed_keys:)
        @path = path
        @allowed_keys = allowed_keys
      end

      def exist?
        File.file?(path)
      end

      def read
        return {} unless exist?

        File.readlines(path, chomp: true).each_with_object({}) do |line, values|
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?("#")

          key, value = stripped.split("=", 2)
          unless value && @allowed_keys.include?(key)
            raise Error, "Invalid or unsupported setting in #{path}: #{key.inspect}"
          end

          values[key] = value
        end
      end

      def write(values, mode: 0o600)
        unknown_keys = values.keys - @allowed_keys
        raise Error, "Unsupported settings: #{unknown_keys.join(", ")}" if unknown_keys.any?

        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, File::WRONLY | File::CREAT | File::TRUNC, mode) do |file|
          values.each { |key, value| file.puts "#{key}=#{value}" }
        end
        File.chmod(mode, path)
      end
    end

    class Runner
      def initialize(root)
        @root = root
      end

      def available?(command)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
          File.executable?(File.join(directory, command))
        end
      end

      def capture(*command, env: {})
        stdout, stderr, status = Open3.capture3(env, *command, chdir: @root)
        [ stdout, stderr, status.success? ]
      end

      def run(*command, env: {})
        system(env, *command, chdir: @root)
      end

      def pipe(source_command, target_command)
        reader, writer = IO.pipe
        source_pid = Process.spawn(*source_command, chdir: @root, out: writer)
        target_pid = Process.spawn(*target_command, chdir: @root, in: reader)
        reader.close
        writer.close

        _, source_status = Process.wait2(source_pid)
        _, target_status = Process.wait2(target_pid)
        source_status.success? && target_status.success?
      ensure
        reader&.close unless reader&.closed?
        writer&.close unless writer&.closed?
      end
    end

    class CLI
      def initialize(root: File.expand_path("../..", __dir__), input: $stdin, output: $stdout, error: $stderr, runner: nil)
        @root = root
        @input = input
        @output = output
        @error = error
        @runner = runner || Runner.new(root)
        @config_file = EnvironmentFile.new(File.join(root, CONFIG_PATH), allowed_keys: CONFIG_KEYS)
        @secrets_file = EnvironmentFile.new(
          File.join(root, SECRETS_PATH), allowed_keys: SECRET_KEYS + OPTIONAL_SECRET_KEYS
        )
      end

      def run(arguments)
        command = arguments.shift || "help"

        case command
        when "help", "--help", "-h" then help
        when "status" then status(arguments)
        when "setup" then setup(arguments)
        when "deploy" then deploy(arguments)
        when "console" then console(arguments)
        when "kamal" then kamal(arguments)
        when "migrate" then migrate(arguments)
        when "mailserver" then mailserver(arguments)
        else
          @error.puts "Unknown command: #{command}"
          @error.puts "Run bin/bonfire help for usage."
          64
        end
      rescue OptionParser::ParseError, Error => error
        @error.puts "Error: #{error.message}"
        1
      rescue Interrupt
        @error.puts "\nCancelled."
        130
      end

      private
        def help
          @output.puts <<~HELP
            Usage: bin/bonfire COMMAND [options]

            Commands:
              status   Report local configuration and remote deployment status
              setup    Configure and optionally bootstrap a new deployment
              deploy   Deploy the current Git commit with Kamal
              console  Open a Rails console on the production server
              kamal    Run a Kamal command with Bonfire's private environment
              migrate  Move an existing deployment to a new server
              mailserver  Configure or inspect outbound email delivery
              help     Show this help

            Start a new installation with:
              bin/bonfire setup

            Run `bin/bonfire COMMAND --help` for command-specific options.
          HELP
          0
        end

        def status(arguments)
          options = { remote: true }
          parser = OptionParser.new do |option_parser|
            option_parser.banner = "Usage: bin/bonfire status [options]"
            option_parser.on("--local", "Skip DNS, SSH, and Kamal checks") { options[:remote] = false }
            option_parser.on("-h", "--help", "Show this help") do
              @output.puts option_parser
              return 0
            end
          end
          parser.parse!(arguments)

          config = configured_values
          unless @config_file.exist?
            @output.puts "Bonfire is not configured. Run `bin/bonfire setup`."
            return 1
          end

          print_configuration(config)
          print_secret_status
          print_git_status
          check_remote(config) if options[:remote]
          0
        end

        def setup(arguments)
          options = { yes: false, configure_only: false }
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: bin/bonfire setup [options]"
            opts.on("--host HOST", "Deployment host/domain") { |value| options["DEPLOY_HOST"] = value }
            opts.on("--server HOST", "SSH/Kamal server (defaults to deployment host)") { |value| options["DEPLOY_SERVER"] = value }
            opts.on("--user USER", "SSH user (default: root)") { |value| options["DEPLOY_SSH_USER"] = value }
            opts.on("--storage PATH", "Persistent storage path") { |value| options["DEPLOY_STORAGE_PATH"] = value }
            opts.on("--service NAME", "Kamal service name") { |value| options["KAMAL_SERVICE"] = value }
            opts.on("--image NAME", "Container image name") { |value| options["KAMAL_IMAGE"] = value }
            opts.on("--registry HOST", "Container registry") { |value| options["KAMAL_REGISTRY"] = value }
            opts.on("--arch ARCH", "Builder architecture") { |value| options["KAMAL_BUILDER_ARCH"] = value }
            opts.on("--configure-only", "Write local configuration without changing a server") { options[:configure_only] = true }
            opts.on("--yes", "Accept the final server-change confirmation") { options[:yes] = true }
            opts.on("-h", "--help", "Show this help") do
              @output.puts opts
              return 0
            end
          end
          parser.parse!(arguments)

          existing = @config_file.read
          values = DEFAULTS.merge(existing).merge(options.slice(*CONFIG_KEYS)).compact
          values["DEPLOY_HOST"] ||= prompt("Deployment host/domain")
          values["DEPLOY_SERVER"] ||= values.fetch("DEPLOY_HOST")
          validate_configuration!(values)

          @config_file.write(values)
          @output.puts "Saved private deployment configuration to #{CONFIG_PATH}."
          ensure_secrets
          print_configuration(values)
          return configured_only_message if options[:configure_only]

          ensure_local_tools!
          addresses = Resolv.getaddresses(values.fetch("DEPLOY_HOST"))
          raise Error, "DEPLOY_HOST does not resolve in DNS" if addresses.empty?
          @output.puts "  DNS:          #{addresses.join(", ")}"

          remote = remote_probe(values)
          print_remote_probe(remote)
          raise Error, "Cannot connect to the deployment server over SSH" unless remote[:reachable]

          unless existing.key?("KAMAL_BUILDER_ARCH") || options.key?("KAMAL_BUILDER_ARCH")
            values["KAMAL_BUILDER_ARCH"] = detected_architecture(remote[:output])
            @config_file.write(values)
            @output.puts "  Architecture detected as #{values.fetch("KAMAL_BUILDER_ARCH")}."
          end

          unless options[:yes] || confirm("Bootstrap and deploy to #{deployment_server(values)}?", default: false)
            @output.puts "Server unchanged. Configuration is ready; run `bin/bonfire setup` when ready."
            return 0
          end

          environment = values
          return 1 unless run_step("Bootstrapping the deployment server", environment, "kamal", "server", "bootstrap")
          return 1 unless run_step("Deploying Bonfire for the first time", environment, "kamal", "setup")

          @output.puts "Bonfire is deployed at https://#{values.fetch("DEPLOY_HOST")}."
          0
        end

        def deploy(arguments)
          options = { yes: false, allow_dirty: false, verbose: false }
          parser = OptionParser.new do |option_parser|
            option_parser.banner = "Usage: bin/bonfire deploy [options]"
            option_parser.on("--yes", "Skip deployment confirmation") { options[:yes] = true }
            option_parser.on("--allow-dirty", "Allow deployment with uncommitted changes") { options[:allow_dirty] = true }
            option_parser.on("--verbose", "Enable detailed Kamal output") { options[:verbose] = true }
            option_parser.on("-h", "--help", "Show this help") do
              @output.puts option_parser
              return 0
            end
          end
          parser.parse!(arguments)

          raise Error, "No deployment configuration. Run `bin/bonfire setup` first." unless @config_file.exist?
          ensure_secrets_file!

          config = configured_values
          validate_configuration!(config)
          ensure_local_tools!
          branch, commit, dirty = git_state
          if dirty && !options[:allow_dirty]
            raise Error, "The Git worktree has uncommitted changes. Commit them or pass --allow-dirty."
          end

          print_configuration(config)
          @output.puts "Source:     #{branch} at #{commit}#{" (dirty)" if dirty}"
          unless options[:yes] || confirm("Deploy this source to #{deployment_server(config)}?", default: false)
            @output.puts "Deployment cancelled."
            return 0
          end

          command = [ "kamal", "deploy" ]
          command << "--verbose" if options[:verbose]
          return 1 unless run_step("Deploying Bonfire", config, *command)

          @output.puts "Deployment completed: https://#{config.fetch("DEPLOY_HOST")}"
          0
        end

        def kamal(arguments)
          raise Error, "No deployment configuration. Run `bin/bonfire setup` first." unless @config_file.exist?
          ensure_secrets_file!
          raise Error, "Install required local tools: kamal" unless @runner.available?("kamal")
          validate_safe_kamal_arguments!(arguments)

          config = configured_values
          validate_configuration!(config)

          # Kamal owns .kamal/secrets, including its supported secret-provider
          # syntax. Do not source, parse, or copy those values into this process.
          @runner.run("kamal", *arguments, env: config) ? 0 : 1
        end

        def console(arguments)
          parser = OptionParser.new do |option_parser|
            option_parser.banner = "Usage: bin/bonfire console"
            option_parser.on("-h", "--help", "Show this help") do
              @output.puts option_parser
              return 0
            end
          end
          parser.parse!(arguments)
          raise Error, "The console command does not accept arguments" if arguments.any?
          raise Error, "No deployment configuration. Run `bin/bonfire setup` first." unless @config_file.exist?
          ensure_secrets_file!
          raise Error, "Install required local tools: kamal" unless @runner.available?("kamal")

          config = configured_values
          validate_configuration!(config)

          @runner.run("kamal", "console", env: config) ? 0 : 1
        end

        def validate_safe_kamal_arguments!(arguments)
          sensitive_argument = arguments.find { |argument| SENSITIVE_KAMAL_ARGUMENTS.include?(argument) }
          sensitive_sequence = SENSITIVE_KAMAL_SEQUENCES.find do |sequence|
            arguments.each_cons(sequence.length).any? { |window| window == sequence }
          end
          return unless sensitive_argument || sensitive_sequence

          raise Error, "That Kamal command can expose secrets or execute arbitrary code and is disabled by the LLM-safe wrapper"
        end

        def migrate(arguments)
          options = { yes: false, dry_run: false, resume: false, allow_dirty: false, dns_timeout: 600 }
          parser = OptionParser.new do |option_parser|
            option_parser.banner = "Usage: bin/bonfire migrate USER@HOST [options]"
            option_parser.on("--dry-run", "Run preflight checks without changing either server") { options[:dry_run] = true }
            option_parser.on("--resume", "Resume the migration recorded in #{MIGRATION_PATH}") { options[:resume] = true }
            option_parser.on("--yes", "Accept server-change confirmations (DNS is still verified)") { options[:yes] = true }
            option_parser.on("--allow-dirty", "Allow deployment with uncommitted changes") { options[:allow_dirty] = true }
            option_parser.on("--dns-timeout SECONDS", Integer, "Seconds to wait for DNS (default: 600)") { |value| options[:dns_timeout] = value }
            option_parser.on("-h", "--help", "Show this help") do
              @output.puts option_parser
              return 0
            end
          end
          parser.parse!(arguments)

          raise Error, "No deployment configuration. Run `bin/bonfire setup` first." unless @config_file.exist?
          ensure_secrets_file!
          raise Error, "Expected one target such as root@203.0.113.10" unless arguments.one?

          target_user, target_server = parse_destination(arguments.first)
          config = configured_values
          validate_configuration!(config)
          ensure_migration_tools!
          ensure_clean_worktree!(allow_dirty: options[:allow_dirty])

          source_user = config.fetch("DEPLOY_SSH_USER")
          source_server = deployment_server(config)
          raise Error, "The migration target is the current deployment server" if source_user == target_user && source_server == target_server

          target_config = config.merge("DEPLOY_SERVER" => target_server, "DEPLOY_SSH_USER" => target_user)
          validate_configuration!(target_config)
          print_migration_plan(config, target_config)
          preflight_migration!(config, target_config)
          return dry_run_message if options[:dry_run]

          state = migration_state(options, config, target_config)
          unless options[:yes] || confirm("Move Bonfire to #{target_user}@#{target_server}? A maintenance window is required.", default: false)
            @output.puts "Migration cancelled."
            return 0
          end

          perform_migration(state, config, target_config, options)
        end

        def mailserver(arguments)
          command = arguments.shift || "help"
          case command
          when "setup" then mailserver_setup(arguments)
          when "status" then mailserver_status(arguments)
          when "test" then mailserver_test(arguments)
          when "help", "--help", "-h" then mailserver_help
          else
            raise Error, "Unknown mailserver command: #{command}. Use setup, status, or test."
          end
        end

        def mailserver_help
          @output.puts <<~HELP
            Usage: bin/bonfire mailserver COMMAND [options]

            Commands:
              setup   Configure Postmark (recommended) or generic SMTP
              status  Report mail configuration without revealing credentials
              test    Send a test email to the installation's first administrator

            Recommended setup:
              bin/bonfire setup --configure-only
              bin/bonfire mailserver setup --provider postmark --from "Bonfire <notifications@example.com>"
              bin/bonfire mailserver status
              bin/bonfire deploy
              bin/bonfire mailserver test
          HELP
          0
        end

        def mailserver_setup(arguments)
          options = { "EMAIL_PROVIDER" => "postmark" }
          token_file = password_file = nil
          parser = OptionParser.new do |option_parser|
            option_parser.banner = "Usage: bin/bonfire mailserver setup [options]"
            option_parser.on("--provider NAME", %w[postmark smtp], "Provider: postmark (recommended) or smtp") { |value| options["EMAIL_PROVIDER"] = value }
            option_parser.on("--from ADDRESS", "Verified sender, for example Bonfire <notifications@example.com>") { |value| options["EMAIL_FROM"] = value }
            option_parser.on("--host HOST", "Canonical Bonfire host used in email links") { |value| options["MAILER_HOST"] = value }
            option_parser.on("--token-file PATH", "Read the Postmark server token from a private file") { |value| token_file = value }
            option_parser.on("--message-stream NAME", "Postmark message stream (default: outbound)") { |value| options["POSTMARK_MESSAGE_STREAM"] = value }
            option_parser.on("--smtp-address HOST", "SMTP server") { |value| options["SMTP_ADDRESS"] = value }
            option_parser.on("--smtp-port PORT", Integer, "SMTP port (default: 587)") { |value| options["SMTP_PORT"] = value.to_s }
            option_parser.on("--smtp-username USER", "SMTP username") { |value| options["SMTP_USERNAME"] = value }
            option_parser.on("--smtp-password-file PATH", "Read the SMTP password from a private file") { |value| password_file = value }
            option_parser.on("-h", "--help", "Show this help") do
              @output.puts option_parser
              return 0
            end
          end
          parser.parse!(arguments)
          raise Error, "The setup command does not accept positional arguments" if arguments.any?
          ensure_mailserver_files!

          config = @config_file.read
          secrets = @secrets_file.read
          provider = options.fetch("EMAIL_PROVIDER")
          sender = options["EMAIL_FROM"] || prompt("Verified sender address (for example Bonfire <notifications@example.com>)")
          validate_sender!(sender)
          host = options["MAILER_HOST"] || config["DEPLOY_HOST"] || prompt("Canonical Bonfire host")
          validate_mailer_host!(host)

          config.merge!(
            "EMAIL_NOTIFICATIONS_ENABLED" => "true",
            "EMAIL_PROVIDER" => provider,
            "EMAIL_FROM" => sender,
            "MAILER_HOST" => host,
            "MAILER_PROTOCOL" => "https"
          )

          if provider == "postmark"
            token = read_private_value(token_file, "Postmark server API token", existing: secrets["POSTMARK_SERVER_TOKEN"])
            secrets["POSTMARK_SERVER_TOKEN"] = token
            config["POSTMARK_MESSAGE_STREAM"] = options.fetch("POSTMARK_MESSAGE_STREAM", "outbound")
            validate_message_stream!(config.fetch("POSTMARK_MESSAGE_STREAM"))
            config.delete("SMTP_ADDRESS")
            config.delete("SMTP_PORT")
            @output.puts "Using Postmark's transactional #{config.fetch("POSTMARK_MESSAGE_STREAM").inspect} message stream."
          else
            config["SMTP_ADDRESS"] = options["SMTP_ADDRESS"] || prompt("SMTP server")
            config["SMTP_PORT"] = options.fetch("SMTP_PORT", "587")
            secrets["SMTP_USERNAME"] = options["SMTP_USERNAME"] || prompt("SMTP username", secrets["SMTP_USERNAME"])
            secrets["SMTP_PASSWORD"] = read_private_value(password_file, "SMTP password", existing: secrets["SMTP_PASSWORD"])
            config["SMTP_AUTHENTICATION"] ||= "plain"
            config["SMTP_STARTTLS"] ||= "true"
          end

          @config_file.write(DEFAULTS.merge(config).slice(*CONFIG_KEYS))
          @secrets_file.write(secrets)
          @output.puts "Saved mail configuration. Credentials remain in #{SECRETS_PATH} with permissions 0600."
          @output.puts "Verify the sender/domain in #{provider == 'postmark' ? 'Postmark' : 'your SMTP provider'}, then run `bin/bonfire mailserver status`."
          0
        end

        def mailserver_status(arguments)
          parser = OptionParser.new do |option_parser|
            option_parser.banner = "Usage: bin/bonfire mailserver status"
            option_parser.on("-h", "--help", "Show this help") do
              @output.puts option_parser
              return 0
            end
          end
          parser.parse!(arguments)
          raise Error, "The status command does not accept arguments" if arguments.any?
          ensure_mailserver_files!

          config = DEFAULTS.merge(@config_file.read)
          secrets = @secrets_file.read
          provider = config.fetch("EMAIL_PROVIDER", "postmark")
          checks = mailserver_checks(config, secrets, provider)
          @output.puts <<~STATUS

            Bonfire mailserver
              Enabled:  #{config["EMAIL_NOTIFICATIONS_ENABLED"] == "true" ? "yes" : "no"}
              Provider: #{provider}
              Sender:   #{config.fetch("EMAIL_FROM", "not configured")}
              Mail host: #{config.fetch("MAILER_HOST", "not configured")}
          STATUS
          @output.puts "  Message stream: #{config.fetch("POSTMARK_MESSAGE_STREAM", "outbound")}" if provider == "postmark"
          checks.each { |label, valid| @output.puts "  #{label}: #{valid ? 'configured' : 'missing'}" }
          ready = config["EMAIL_NOTIFICATIONS_ENABLED"] == "true" && checks.all?(&:last)
          @output.puts "  Ready to deploy: #{ready ? 'yes' : 'no'}"
          @output.puts "  Sender verification: confirm this in #{provider == 'postmark' ? 'Postmark' : 'your provider'} before sending."
          ready ? 0 : 1
        end

        def mailserver_test(arguments)
          parser = OptionParser.new do |option_parser|
            option_parser.banner = "Usage: bin/bonfire mailserver test"
            option_parser.on("-h", "--help", "Show this help") do
              @output.puts option_parser
              return 0
            end
          end
          parser.parse!(arguments)
          raise Error, "The test command does not accept arguments" if arguments.any?
          ensure_mailserver_files!
          raise Error, "Install required local tools: kamal" unless @runner.available?("kamal")

          config = DEFAULTS.merge(@config_file.read)
          secrets = @secrets_file.read
          provider = config.fetch("EMAIL_PROVIDER", "postmark")
          ready = config["EMAIL_NOTIFICATIONS_ENABLED"] == "true" &&
            mailserver_checks(config, secrets, provider).all?(&:last)
          raise Error, "Mail delivery is not ready. Run `bin/bonfire mailserver status` for details." unless ready

          validate_configuration!(config)
          @output.puts "Sending a test email through #{provider}..."
          if @runner.run("kamal", "app", "exec", "--reuse", "bin/rails bonfire:mailserver:test", env: config)
            @output.puts "The deployed application accepted the test delivery request."
            0
          else
            @error.puts "Test email delivery failed. Check the output above and your provider activity log."
            1
          end
        end

        def mailserver_checks(config, secrets, provider)
          common = [
            [ "Provider", %w[postmark smtp].include?(provider) ],
            [ "Sender", config["EMAIL_FROM"].to_s.length.positive? ],
            [ "Canonical host", config["MAILER_HOST"].to_s.length.positive? ]
          ]
          if provider == "postmark"
            common + [ [ "Postmark server token", secrets["POSTMARK_SERVER_TOKEN"].to_s.length.positive? ] ]
          else
            common + [
              [ "SMTP server", config["SMTP_ADDRESS"].to_s.length.positive? && config["SMTP_PORT"].to_s.length.positive? ],
              [ "SMTP credentials", secrets["SMTP_USERNAME"].to_s.length.positive? && secrets["SMTP_PASSWORD"].to_s.length.positive? ]
            ]
          end
        end

        def ensure_mailserver_files!
          raise Error, "No deployment configuration. Run `bin/bonfire setup --configure-only` first." unless @config_file.exist?
          ensure_secrets_file!
        end

        def read_private_value(path, label, existing: nil)
          if path
            value = File.read(File.expand_path(path)).strip
          elsif existing.to_s.length.positive?
            value = existing
            @output.puts "Keeping the existing #{label.downcase}."
          else
            value = secret_prompt(label)
          end
          raise Error, "#{label} cannot be empty" if value.empty?
          value
        rescue Errno::ENOENT, Errno::EACCES => error
          raise Error, "Could not read #{label.downcase}: #{error.message}"
        end

        def secret_prompt(label)
          @output.print "#{label}: "
          answer = if @input.respond_to?(:noecho)
            @input.noecho(&:gets).tap { @output.puts }
          else
            @input.gets
          end
          raise Error, "Input ended before setup was complete" unless answer
          answer.strip
        end

        def validate_sender!(sender)
          address = sender[/<([^>]+)>/, 1] || sender
          raise Error, "EMAIL_FROM must contain a valid email address" unless address.match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
          raise Error, "EMAIL_FROM cannot contain a newline" if sender.match?(/[\r\n]/)
        end

        def validate_mailer_host!(host)
          raise Error, "MAILER_HOST must be a hostname" unless host.match?(/\A[A-Za-z0-9.-]+\z/)
        end

        def validate_message_stream!(stream)
          raise Error, "Postmark message stream contains unsupported characters" unless stream.match?(/\A[A-Za-z0-9_-]+\z/)
        end

        def configured_values
          DEFAULTS.merge(@config_file.read).tap do |values|
            values["DEPLOY_SERVER"] ||= values["DEPLOY_HOST"]
          end
        end

        def deployment_server(config)
          config.fetch("DEPLOY_SERVER", config.fetch("DEPLOY_HOST"))
        end

        def ensure_secrets
          if @secrets_file.exist?
            File.chmod(0o600, @secrets_file.path)
            @output.puts "Keeping existing secrets in #{SECRETS_PATH}."
            return
          end

          stdout, stderr, success = @runner.capture("script/admin/generate-secrets")
          raise Error, "Could not generate secrets: #{stderr.strip}" unless success

          generated = stdout.lines(chomp: true).to_h do |line|
            key, value = line.split("=", 2)
            [ key, value ]
          end.slice(*SECRET_KEYS)
          unless SECRET_KEYS.all? { |key| generated[key].to_s.length > 0 }
            raise Error, "Secret generator did not return all required values"
          end

          @secrets_file.write(generated)
          @output.puts "Generated #{SECRETS_PATH} with permissions 0600. Back it up securely."
        end

        def ensure_secrets_file!
          raise Error, "Missing #{SECRETS_PATH}. Run `bin/bonfire setup` first." unless @secrets_file.exist?
        end

        def secrets_complete?
          secrets = @secrets_file.read
          SECRET_KEYS.all? { |key| secrets[key].to_s.length > 0 }
        rescue Error
          false
        end

        def print_configuration(config)
          @output.puts <<~REPORT

            Bonfire deployment
              Public host: #{config.fetch("DEPLOY_HOST", "not configured")}
              Server:      #{deployment_server(config)}
              SSH user:    #{config.fetch("DEPLOY_SSH_USER")}
              Service:     #{config.fetch("KAMAL_SERVICE")}
              Image:       #{config.fetch("KAMAL_IMAGE")}
              Registry:    #{config.fetch("KAMAL_REGISTRY")}
              Architecture: #{config.fetch("KAMAL_BUILDER_ARCH")}
              Storage:     #{config.fetch("DEPLOY_STORAGE_PATH")} (UID #{config.fetch("DEPLOY_STORAGE_UID")})
              HTTPS:       Kamal Proxy terminates TLS on ports 80/443
          REPORT
        end

        def print_secret_status
          secrets = @secrets_file.read
          @output.puts "  Secrets:"
          SECRET_KEYS.each do |key|
            @output.puts "    #{key}: #{secrets[key].to_s.empty? ? "missing" : "configured"}"
          end
          permissions = File.stat(@secrets_file.path).mode & 0o777
          @output.puts "    File permissions: #{permissions == 0o600 ? "0600" : format("%04o (expected 0600)", permissions)}"
        rescue Error => error
          @output.puts "  Secrets: invalid (#{error.message})"
        end

        def print_git_status
          branch, commit, dirty = git_state
          @output.puts "  Source:       #{branch} at #{commit}#{" (dirty)" if dirty}"
        end

        def git_state
          branch, = @runner.capture("git", "branch", "--show-current")
          commit, = @runner.capture("git", "rev-parse", "--short", "HEAD")
          changes, = @runner.capture("git", "status", "--porcelain")
          [ branch.strip.empty? ? "detached HEAD" : branch.strip, commit.strip, !changes.strip.empty? ]
        end

        def check_remote(config)
          addresses = Resolv.getaddresses(config.fetch("DEPLOY_HOST"))
          @output.puts "  DNS:          #{addresses.empty? ? "not resolved" : addresses.join(", ")}"
          remote = remote_probe(config)
          print_remote_probe(remote)

          return unless remote[:reachable] && @runner.available?("kamal") && @secrets_file.exist?

          @output.puts "\nKamal details"
          @runner.run("kamal", "details", env: config)
        rescue Resolv::ResolvError
          @output.puts "  DNS:          lookup failed"
        end

        def remote_probe(config)
          destination = "#{config.fetch("DEPLOY_SSH_USER")}@#{deployment_server(config)}"
          command = "printf 'BONFIRE_READY\\n'; uname -m; if command -v docker >/dev/null; then docker --version; else printf 'docker missing\\n'; fi"
          stdout, stderr, success = @runner.capture(
            "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", destination, command
          )
          { reachable: success && stdout.include?("BONFIRE_READY"), output: stdout, error: stderr }
        end

        def print_remote_probe(remote)
          if remote[:reachable]
            lines = remote[:output].lines.map(&:strip).reject { |line| line.empty? || line == "BONFIRE_READY" }
            @output.puts "  SSH:          connected"
            @output.puts "  Remote:       #{lines.join("; ")}"
          else
            detail = remote[:error].lines.last.to_s.strip
            @output.puts "  SSH:          unavailable#{": #{detail}" unless detail.empty?}"
          end
        end

        def detected_architecture(output)
          return "arm64" if output.lines.any? { |line| line.strip.match?(/\A(?:aarch64|arm64)\z/) }

          "amd64"
        end

        def validate_configuration!(values)
          host = values["DEPLOY_HOST"].to_s
          raise Error, "DEPLOY_HOST is required" if host.empty?
          raise Error, "DEPLOY_HOST must be a hostname or IP address" unless host.match?(/\A[A-Za-z0-9.-]+\z/)

          server = deployment_server(values).to_s
          raise Error, "DEPLOY_SERVER must be a hostname or IP address" unless server.match?(/\A[A-Za-z0-9.-]+\z/)

          user = values.fetch("DEPLOY_SSH_USER")
          raise Error, "Invalid SSH user" unless user.match?(/\A[A-Za-z0-9._-]+\z/)

          path = values.fetch("DEPLOY_STORAGE_PATH")
          raise Error, "Storage path must be an absolute safe path" unless path.match?(%r{\A/[A-Za-z0-9_./-]+\z})

          uid = values.fetch("DEPLOY_STORAGE_UID")
          raise Error, "Storage UID must be numeric" unless uid.match?(/\A\d+\z/)

          %w[KAMAL_SERVICE KAMAL_IMAGE KAMAL_REGISTRY KAMAL_BUILDER_ARCH].each do |key|
            raise Error, "#{key} contains unsupported characters" unless values.fetch(key).match?(/\A[A-Za-z0-9._:\/-]+\z/)
          end
        end

        def ensure_local_tools!
          missing = %w[git docker ssh kamal].reject { |tool| @runner.available?(tool) }
          raise Error, "Install required local tools: #{missing.join(", ")}" if missing.any?
        end

        def ensure_migration_tools!
          ensure_local_tools!
          missing = %w[curl].reject { |tool| @runner.available?(tool) }
          raise Error, "Install required local tools: #{missing.join(", ")}" if missing.any?
        end

        def ensure_clean_worktree!(allow_dirty:)
          _, _, dirty = git_state
          raise Error, "The Git worktree has uncommitted changes. Commit them or pass --allow-dirty." if dirty && !allow_dirty
        end

        def parse_destination(destination)
          match = destination.match(/\A([A-Za-z0-9._-]+)@([A-Za-z0-9.-]+)\z/)
          raise Error, "Target must use USER@HOST format" unless match

          [ match[1], match[2] ]
        end

        def print_migration_plan(source, target)
          @output.puts <<~PLAN

            Bonfire server migration
              Public host: #{source.fetch("DEPLOY_HOST")}
              Source:      #{source.fetch("DEPLOY_SSH_USER")}@#{deployment_server(source)}
              Target:      #{target.fetch("DEPLOY_SSH_USER")}@#{deployment_server(target)}
              Storage:     #{source.fetch("DEPLOY_STORAGE_PATH")}
              Source code: #{git_state.first(2).join(" at ")}

            The old application will be stopped before storage is copied. It will
            remain intact for rollback and will not be deleted automatically.
          PLAN
        end

        def preflight_migration!(source, target)
          [ [ "source", source ], [ "target", target ] ].each do |label, config|
            probe = remote_probe(config)
            print_remote_probe(probe)
            raise Error, "Cannot connect to the #{label} server over SSH" unless probe[:reachable]
          end

          target_path = target.fetch("DEPLOY_STORAGE_PATH")
          source_path = source.fetch("DEPLOY_STORAGE_PATH")
          source_stdout, source_stderr, source_success = @runner.capture(
            "ssh", "-o", "BatchMode=yes", ssh_destination(source),
            "du -sk -- #{Shellwords.escape(source_path)}"
          )
          raise Error, "Could not measure source storage: #{source_stderr.lines.last.to_s.strip}" unless source_success

          source_kb = source_stdout.split.first&.then { |value| Integer(value, exception: false) }
          destination = ssh_destination(target)
          command = "set -eu; test ! -e #{Shellwords.escape(target_path)} || test -d #{Shellwords.escape(target_path)}; " \
            "df -Pk #{Shellwords.escape(File.dirname(target_path))} 2>/dev/null || df -Pk /"
          stdout, stderr, success = @runner.capture("ssh", "-o", "BatchMode=yes", destination, command)
          raise Error, "Could not inspect target storage: #{stderr.lines.last.to_s.strip}" unless success

          available_kb = stdout.lines.reverse_each.lazy.map { |line| line.split }.find { |fields| fields.length >= 4 && fields[3].match?(/\A\d+\z/) }&.[](3)
          if source_kb && available_kb && available_kb.to_i < (source_kb * 1.1).ceil
            raise Error, "Target does not have enough free space for #{source_kb / 1024} MiB of storage"
          end
          @output.puts "  Source data:  #{source_kb ? "#{source_kb / 1024} MiB" : "size unavailable"}"
          @output.puts "  Target disk:  #{available_kb ? "#{available_kb.to_i / 1024} MiB available" : "available"}"
        end

        def dry_run_message
          @output.puts "Dry run complete. Neither server was changed."
          0
        end

        def migration_state(options, source, target)
          path = File.join(@root, MIGRATION_PATH)
          if options[:resume]
            raise Error, "No migration to resume at #{MIGRATION_PATH}" unless File.file?(path)
            state = JSON.parse(File.read(path))
            unless state.values_at("target_user", "target_server") == [ target.fetch("DEPLOY_SSH_USER"), deployment_server(target) ]
              raise Error, "The recorded migration has a different target"
            end
            state
          else
            raise Error, "A migration is already in progress; pass --resume or remove #{MIGRATION_PATH}" if File.file?(path)
            state = {
              "stage" => "planned",
              "source_user" => source.fetch("DEPLOY_SSH_USER"),
              "source_server" => deployment_server(source),
              "target_user" => target.fetch("DEPLOY_SSH_USER"),
              "target_server" => deployment_server(target),
              "public_host" => source.fetch("DEPLOY_HOST"),
              "started_at" => Time.now.utc.iso8601
            }
            write_migration_state(state)
            state
          end
        end

        def perform_migration(state, source, target, options)
          source_stopped = stage_at_least?(state, "source_stopped")
          target_started = stage_at_least?(state, "http_deployed")
          target_healthy = false

          unless stage_at_least?(state, "bootstrapped")
            return 1 unless run_step("Bootstrapping the new server", target, "kamal", "server", "bootstrap")
            advance_migration!(state, "bootstrapped")
          end

          unless source_stopped
            return 1 unless run_step("Stopping Bonfire on the old server", source, "kamal", "app", "stop")
            source_stopped = true
            advance_migration!(state, "source_stopped")
          end

          unless stage_at_least?(state, "storage_copied")
            transfer_storage!(source, target)
            advance_migration!(state, "storage_copied")
          end

          unless target_started
            http_environment = target.merge("DEPLOY_PROXY_SSL" => "false")
            unless run_step("Deploying Bonfire on the new server over HTTP", http_environment, "kamal", "setup")
              restart_source_after_failure(source, state)
              return 1
            end
            target_started = true
            advance_migration!(state, "http_deployed")
          end

          verify_http_target!(target)
          target_healthy = true
          wait_for_dns!(target, options)
          advance_migration!(state, "dns_ready")

          return 1 unless run_step("Enabling HTTPS on the new server", target, "kamal", "deploy")
          verify_https!(target.fetch("DEPLOY_HOST"))

          saved = @config_file.read.merge(
            "DEPLOY_SERVER" => deployment_server(target),
            "DEPLOY_SSH_USER" => target.fetch("DEPLOY_SSH_USER")
          )
          @config_file.write(DEFAULTS.merge(saved).slice(*CONFIG_KEYS))
          advance_migration!(state, "complete")
          FileUtils.rm_f(File.join(@root, MIGRATION_PATH))

          @output.puts <<~SUCCESS

            Migration completed: https://#{target.fetch("DEPLOY_HOST")}
            The old server is stopped but unchanged. Keep it until you are satisfied
            with the new installation, then retire it manually.
          SUCCESS
          0
        rescue Error
          if source_stopped && !target_healthy
            @runner.run("kamal", "app", "stop", env: target) if target_started
            restart_source_after_failure(source, state)
          end
          raise
        end

        MIGRATION_STAGES = %w[planned bootstrapped source_stopped storage_copied http_deployed dns_ready complete].freeze

        def stage_at_least?(state, stage)
          MIGRATION_STAGES.index(state.fetch("stage")) >= MIGRATION_STAGES.index(stage)
        end

        def advance_migration!(state, stage)
          state["stage"] = stage
          write_migration_state(state)
        end

        def write_migration_state(state)
          path = File.join(@root, MIGRATION_PATH)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, JSON.pretty_generate(state) + "\n", mode: "w", perm: 0o600)
          File.chmod(0o600, path)
        end

        def transfer_storage!(source, target)
          source_path = source.fetch("DEPLOY_STORAGE_PATH")
          target_path = target.fetch("DEPLOY_STORAGE_PATH")
          uid = target.fetch("DEPLOY_STORAGE_UID")
          source_command = [ "ssh", "-o", "BatchMode=yes", ssh_destination(source),
            "tar -C #{Shellwords.escape(File.dirname(source_path))} -czf - #{Shellwords.escape(File.basename(source_path))}" ]
          target_command = [ "ssh", "-o", "BatchMode=yes", ssh_destination(target),
            "set -eu; rm -rf -- #{Shellwords.escape(target_path)}; mkdir -p -- #{Shellwords.escape(target_path)}; " \
            "tar -C #{Shellwords.escape(target_path)} -xzf - --strip-components=1; " \
            "chown -R #{uid}:#{uid} -- #{Shellwords.escape(target_path)}; " \
            "test -r #{Shellwords.escape(File.join(target_path, "db", "production.sqlite3"))}" ]

          @output.puts "\nCopying persistent storage to the new server..."
          raise Error, "Storage transfer failed; the old server remains the source of truth" unless @runner.pipe(source_command, target_command)
          @output.puts "Persistent storage copied and ownership verified."
        end

        def verify_http_target!(target)
          url = "http://#{deployment_server(target)}/up"
          stdout, stderr, success = @runner.capture("curl", "--fail", "--silent", "--show-error", "--max-time", "15",
            "--header", "Host: #{target.fetch("DEPLOY_HOST")}", url)
          raise Error, "New server health check failed: #{stderr.strip}" unless success
          @output.puts "  HTTP health:  healthy on #{deployment_server(target)}"
        end

        def wait_for_dns!(target, options)
          public_host = target.fetch("DEPLOY_HOST")
          target_addresses = Resolv.getaddresses(deployment_server(target))
          target_addresses = [ deployment_server(target) ] if target_addresses.empty?

          unless options[:yes]
            @output.puts "\nUpdate #{public_host} to point to #{target_addresses.join(", ")} now."
            prompt("Press Enter after saving the DNS change")
          end

          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + options[:dns_timeout]
          loop do
            resolved = Resolv.getaddresses(public_host)
            if (resolved & target_addresses).any?
              @output.puts "  DNS:          #{public_host} resolves to the new server"
              return
            end
            raise Error, "DNS did not reach the new server within #{options[:dns_timeout]} seconds; rerun with --resume" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

            sleep 10
          end
        end

        def verify_https!(public_host)
          _, stderr, success = @runner.capture("curl", "--fail", "--silent", "--show-error", "--max-time", "20", "https://#{public_host}/up")
          raise Error, "HTTPS health check failed: #{stderr.strip}" unless success
          @output.puts "  HTTPS health: healthy"
        end

        def restart_source_after_failure(source, state)
          @error.puts "Migration failed before the new server was healthy; restarting the old application."
          @runner.run("kamal", "app", "start", env: source)
          advance_migration!(state, "bootstrapped")
        end

        def ssh_destination(config)
          "#{config.fetch("DEPLOY_SSH_USER")}@#{deployment_server(config)}"
        end

        def prompt(label, default = nil)
          @output.print "#{label}#{" [#{default}]" if default}: "
          answer = @input.gets
          raise Error, "Input ended before setup was complete" unless answer

          answer.strip.empty? ? default : answer.strip
        end

        def confirm(question, default:)
          suffix = default ? "[Y/n]" : "[y/N]"
          answer = prompt("#{question} #{suffix}")
          return default if answer.to_s.empty?

          answer.match?(/\Ay(?:es)?\z/i)
        end

        def run_step(label, environment, *command)
          @output.puts "\n#{label}..."
          success = @runner.run(*command, env: environment)
          @error.puts "#{label} failed." unless success
          success
        end

        def configured_only_message
          @output.puts "Configuration is ready. Run `bin/bonfire setup` to bootstrap and deploy."
          0
        end
    end
  end
end
