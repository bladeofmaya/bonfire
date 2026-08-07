require "fileutils"
require "open3"
require "optparse"

module Bonfire
  module Development
    class Error < StandardError; end

    class Runner
      def initialize(root)
        @root = root
      end

      def available?(command)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
          File.executable?(File.join(directory, command))
        end
      end

      def run(*command, env: {})
        system(env, *command, chdir: @root)
      end

      def capture(*command, env: {})
        stdout, stderr, status = Open3.capture3(env, *command, chdir: @root)
        [ stdout, stderr, status.success? ]
      end

      def replace(*command, env: {})
        exec(env, *command, chdir: @root)
      end
    end

    class CLI
      APP_URL = "http://bonfire.localhost:3021"
      COMPOSE_FILE = "compose.dev.yml"
      PROCFILE = "Procfile.dev"

      def initialize(root: File.expand_path("../..", __dir__), input: $stdin, output: $stdout, error: $stderr, runner: nil)
        @root = root
        @input = input
        @output = output
        @error = error
        @runner = runner || Runner.new(root)
      end

      def run(arguments)
        command = arguments.shift || "start"

        case command
        when "start" then start(arguments)
        when "reset" then reset(arguments)
        when "help", "--help", "-h" then help
        else
          @error.puts "Unknown command: #{command}"
          @error.puts "Run bin/dev help for usage."
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
            Usage: bin/dev [COMMAND] [options]

            Commands:
              start   Start Rails and the Redis development container (default)
              reset   Reset all local application data, then start development
              help    Show this help

            Examples:
              bin/dev
              bin/dev reset
              bin/dev reset --yes --no-start

            Local URL: #{APP_URL}
          HELP
          0
        end

        def start(arguments, prepare: true)
          parser = OptionParser.new do |options|
            options.banner = "Usage: bin/dev [start]"
            options.on("-h", "--help", "Show this help") do
              @output.puts options
              return 0
            end
          end
          parser.parse!(arguments)

          ensure_development_environment!
          ensure_tools!
          ensure_docker!
          prepare_database if prepare

          @output.puts "Starting Bonfire development..."
          @output.puts "Open #{APP_URL}"
          @runner.replace("foreman", "start", "-f", PROCFILE)
          0
        end

        def reset(arguments)
          options = { yes: false, start: true }
          parser = OptionParser.new do |option_parser|
            option_parser.banner = "Usage: bin/dev reset [options]"
            option_parser.on("--yes", "Skip the destructive reset confirmation") { options[:yes] = true }
            option_parser.on("--no-start", "Reset without starting development processes") { options[:start] = false }
            option_parser.on("-h", "--help", "Show this help") do
              @output.puts option_parser
              return 0
            end
          end
          parser.parse!(arguments)

          ensure_development_environment!
          unless options[:yes] || confirm_reset
            @output.puts "Reset cancelled."
            return 0
          end

          ensure_tools!(foreman: options[:start])
          ensure_docker!
          stop_redis
          clear_development_data
          prepare_database
          @output.puts "Local Bonfire data has been reset."

          options[:start] ? start([], prepare: false) : 0
        end

        def ensure_development_environment!
          if ENV["RAILS_ENV"] == "production" || ENV["RACK_ENV"] == "production"
            raise Error, "Refusing to run with a production environment"
          end
        end

        def ensure_tools!(foreman: true)
          required = %w[docker]
          required << "foreman" if foreman
          missing = required.reject { |tool| @runner.available?(tool) }
          raise Error, "Install required development tools: #{missing.join(", ")}" if missing.any?
        end

        def ensure_docker!
          _, stderr, success = @runner.capture("docker", "info")
          detail = stderr.lines.last.to_s.strip
          raise Error, "Docker is not running#{": #{detail}" unless detail.empty?}" unless success

          _, stderr, success = @runner.capture("docker", "compose", "version")
          detail = stderr.lines.last.to_s.strip
          raise Error, "Docker Compose is unavailable#{": #{detail}" unless detail.empty?}" unless success
        end

        def confirm_reset
          @output.puts "This deletes the local development database, uploaded files, Redis container, logs, and temporary state."
          @output.print "Reset local Bonfire data? [y/N]: "
          answer = @input.gets
          answer && answer.strip.match?(/\Ay(?:es)?\z/i)
        end

        def stop_redis
          @output.puts "Stopping the development Redis container..."
          success = @runner.run("docker", "compose", "-f", COMPOSE_FILE, "down", "--volumes", "--remove-orphans")
          raise Error, "Could not stop the development Redis container" unless success
        end

        def clear_development_data
          database_pattern = File.join(@root, "storage/db/development.sqlite3*")
          FileUtils.rm_f(Dir.glob(database_pattern))
          clear_directory(File.join(@root, "storage/files"))
          clear_directory(File.join(@root, "log"), preserve: %w[.keep])
          clear_directory(File.join(@root, "tmp"), preserve: %w[.keep storage pids])
          clear_directory(File.join(@root, "tmp/storage"), preserve: %w[.keep])
          clear_directory(File.join(@root, "tmp/pids"), preserve: %w[.keep])
        end

        def clear_directory(directory, preserve: [])
          return unless Dir.exist?(directory)

          Dir.children(directory).each do |entry|
            FileUtils.rm_rf(File.join(directory, entry)) unless preserve.include?(entry)
          end
        end

        def prepare_database
          @output.puts "Preparing the development database..."
          success = @runner.run("bin/rails", "db:prepare", env: { "RAILS_ENV" => "development" })
          raise Error, "Could not prepare the development database" unless success
        end
    end
  end
end
