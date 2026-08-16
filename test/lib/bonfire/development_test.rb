require "test_helper"
require "stringio"
require "tmpdir"
require "bonfire/development"

class Bonfire::DevelopmentTest < ActiveSupport::TestCase
  class FakeRunner
    attr_reader :captures, :runs, :replacements
    attr_accessor :available, :docker_success

    def initialize
      @captures = []
      @runs = []
      @replacements = []
      @available = true
      @docker_success = true
    end

    def available?(_command)
      available
    end

    def capture(*command, env: {})
      captures << [ command, env ]
      [ "", docker_success ? "" : "Docker unavailable", docker_success ]
    end

    def run(*command, env: {})
      runs << [ command, env ]
      true
    end

    def replace(*command, env: {})
      replacements << [ command, env ]
      true
    end
  end

  setup do
    @root = Dir.mktmpdir("bonfire-development-test")
    @output = StringIO.new
    @error = StringIO.new
    @runner = FakeRunner.new
    create_local_state
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test "start launches Foreman with the development Procfile" do
    assert_equal 0, cli.run([])

    command, = @runner.replacements.first
    assert_equal %w[foreman start -f Procfile.dev], command
    assert_includes @runner.runs.map(&:first), %w[bin/rails db:prepare]
    assert_includes @output.string, "http://bonfire.localhost:3021"
  end

  test "start safely loads generated RTMP Homebrew settings" do
    environment_path = File.join(@root, "bonfire-streaming.env")
    File.write(environment_path, <<~ENVIRONMENT)
      RTMP_HOMEBREW_PRIVATE_KEY='private\\nkey'
      RTMP_HOMEBREW_KEY_ID=development-key
      RTMP_HOMEBREW_ISSUER=http://bonfire.localhost:3021
      RTMP_HOMEBREW_AUDIENCE=rtmp-homebrew
      RTMP_HOMEBREW_ALLOWED_PLAYER_ORIGINS=https://stream.localhost:8443
      UNRELATED_SECRET=ignored
    ENVIRONMENT

    with_environment("BONFIRE_STREAMING_ENV_FILE" => environment_path,
      "RTMP_HOMEBREW_AUDIENCE" => "explicit-audience") do
      assert_equal 0, cli.run([])
    end

    _, foreman_environment = @runner.replacements.first
    assert_equal "private\\nkey", foreman_environment.fetch("RTMP_HOMEBREW_PRIVATE_KEY")
    assert_equal "explicit-audience", foreman_environment.fetch("RTMP_HOMEBREW_AUDIENCE")
    assert_equal "https://stream.localhost:8443", foreman_environment.fetch("RTMP_HOMEBREW_ALLOWED_PLAYER_ORIGINS")
    assert_not_includes foreman_environment, "UNRELATED_SECRET"
    assert_includes @output.string, environment_path
    assert_not_includes @output.string, "private\\nkey"

    _, preparation_environment = @runner.runs.find { |command, _| command == %w[bin/rails db:prepare] }
    assert_equal "development-key", preparation_environment.fetch("RTMP_HOMEBREW_KEY_ID")
  end

  test "reset removes local state and prepares a fresh database" do
    assert_equal 0, cli.run(%w[reset --yes --no-start])

    refute_path_exists File.join(@root, "storage/db/development.sqlite3")
    refute_path_exists File.join(@root, "storage/db/development.sqlite3-wal")
    refute_path_exists File.join(@root, "storage/files/upload")
    refute_path_exists File.join(@root, "log/development.log")
    refute_path_exists File.join(@root, "tmp/cache/item")
    assert_path_exists File.join(@root, "storage/db/production.sqlite3")
    assert_path_exists File.join(@root, ".kamal/secrets")

    assert_includes @runner.runs.map(&:first), %w[docker compose -f compose.dev.yml down --volumes --remove-orphans]
    assert_includes @runner.runs.map(&:first), %w[bin/rails db:prepare]
    assert_empty @runner.replacements
  end

  test "reset requires confirmation by default" do
    result = cli(input: StringIO.new("no\n")).run(%w[reset])

    assert_equal 0, result
    assert_path_exists File.join(@root, "storage/db/development.sqlite3")
    assert_empty @runner.runs
  end

  test "reset refuses a production Rails environment" do
    previous = ENV["RAILS_ENV"]
    ENV["RAILS_ENV"] = "production"

    assert_equal 1, cli.run(%w[reset --yes])
    assert_includes @error.string, "production environment"
    assert_path_exists File.join(@root, "storage/db/development.sqlite3")
  ensure
    ENV["RAILS_ENV"] = previous
  end

  test "start reports when Docker is unavailable" do
    @runner.docker_success = false

    assert_equal 1, cli.run([])
    assert_includes @error.string, "Docker is not running"
    assert_empty @runner.replacements
  end

  private
    def cli(input: StringIO.new)
      Bonfire::Development::CLI.new(
        root: @root, input: input, output: @output, error: @error, runner: @runner
      )
    end

    def create_local_state
      files = {
        "storage/db/development.sqlite3" => "development",
        "storage/db/development.sqlite3-wal" => "wal",
        "storage/db/production.sqlite3" => "production",
        "storage/files/upload" => "upload",
        "log/.keep" => "",
        "log/development.log" => "log",
        "tmp/.keep" => "",
        "tmp/cache/item" => "cache",
        ".kamal/secrets" => "SECRET_KEY_BASE=private"
      }

      files.each do |relative_path, contents|
        absolute_path = File.join(@root, relative_path)
        FileUtils.mkdir_p(File.dirname(absolute_path))
        File.write(absolute_path, contents)
      end
    end

    def with_environment(values)
      previous = values.to_h { |key, _| [ key, ENV[key] ] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
end
