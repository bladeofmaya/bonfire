require "fileutils"
require "open3"
require "optparse"
require "resolv"
require "shellwords"

module Bonfire
  module Deployment
    CONFIG_PATH = ".kamal/deploy.env"
    SECRETS_PATH = ".kamal/secrets"

    CONFIG_KEYS = %w[
      DEPLOY_HOST
      DEPLOY_SSH_USER
      DEPLOY_STORAGE_PATH
      DEPLOY_STORAGE_UID
      KAMAL_SERVICE
      KAMAL_IMAGE
      KAMAL_REGISTRY
      KAMAL_BUILDER_ARCH
    ].freeze

    SECRET_KEYS = %w[SECRET_KEY_BASE VAPID_PRIVATE_KEY VAPID_PUBLIC_KEY].freeze
    OPTIONAL_SECRET_KEYS = %w[RAILS_MASTER_KEY].freeze

    DEFAULTS = {
      "DEPLOY_SSH_USER" => "root",
      "DEPLOY_STORAGE_PATH" => "/var/lib/kamal/bonfire/storage",
      "DEPLOY_STORAGE_UID" => "1000",
      "KAMAL_SERVICE" => "bonfire",
      "KAMAL_IMAGE" => "bonfire",
      "KAMAL_REGISTRY" => "localhost:5555",
      "KAMAL_BUILDER_ARCH" => "amd64"
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

          unless options[:yes] || confirm("Bootstrap and deploy to #{values.fetch("DEPLOY_HOST")}?", default: false)
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
          raise Error, "Missing #{SECRETS_PATH}. Run `bin/bonfire setup` first." unless secrets_complete?

          config = configured_values
          validate_configuration!(config)
          ensure_local_tools!
          branch, commit, dirty = git_state
          if dirty && !options[:allow_dirty]
            raise Error, "The Git worktree has uncommitted changes. Commit them or pass --allow-dirty."
          end

          print_configuration(config)
          @output.puts "Source:     #{branch} at #{commit}#{" (dirty)" if dirty}"
          unless options[:yes] || confirm("Deploy this source to #{config.fetch("DEPLOY_HOST")}?", default: false)
            @output.puts "Deployment cancelled."
            return 0
          end

          command = [ "kamal", "deploy" ]
          command << "--verbose" if options[:verbose]
          return 1 unless run_step("Deploying Bonfire", config, *command)

          @output.puts "Deployment completed: https://#{config.fetch("DEPLOY_HOST")}"
          0
        end

        def configured_values
          DEFAULTS.merge(@config_file.read)
        end

        def ensure_secrets
          if secrets_complete?
            File.chmod(0o600, @secrets_file.path)
            @output.puts "Keeping existing secrets in #{SECRETS_PATH}."
            return
          end

          if @secrets_file.exist?
            raise Error, "#{SECRETS_PATH} exists but is incomplete; it was not overwritten."
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

        def secrets_complete?
          secrets = @secrets_file.read
          SECRET_KEYS.all? { |key| secrets[key].to_s.length > 0 }
        rescue Error
          false
        end

        def print_configuration(config)
          @output.puts <<~REPORT

            Bonfire deployment
              Server:      #{config.fetch("DEPLOY_HOST", "not configured")}
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

          return unless remote[:reachable] && @runner.available?("kamal") && secrets_complete?

          @output.puts "\nKamal details"
          @runner.run("kamal", "details", env: config)
        rescue Resolv::ResolvError
          @output.puts "  DNS:          lookup failed"
        end

        def remote_probe(config)
          destination = "#{config.fetch("DEPLOY_SSH_USER")}@#{config.fetch("DEPLOY_HOST")}"
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
