require "test_helper"
require "stringio"
require "tmpdir"
require "bonfire/deployment"

class Bonfire::DeploymentTest < ActiveSupport::TestCase
  class FakeRunner
    attr_reader :runs
    attr_accessor :git_dirty

    def initialize
      @runs = []
      @git_dirty = false
    end

    def available?(_command)
      true
    end

    def capture(*command, env: {})
      case command
      when [ "script/admin/generate-secrets" ]
        [ "SECRET_KEY_BASE=top-secret\nVAPID_PRIVATE_KEY=private-vapid\nVAPID_PUBLIC_KEY=public-vapid\n", "", true ]
      when [ "git", "branch", "--show-current" ] then [ "master\n", "", true ]
      when [ "git", "rev-parse", "--short", "HEAD" ] then [ "abc1234\n", "", true ]
      when [ "git", "status", "--porcelain" ] then [ git_dirty ? " M README.md\n" : "", "", true ]
      when ->(value) { value.first == "ssh" }
        [ "BONFIRE_READY\nx86_64\nDocker version 28.0.0\n", "", true ]
      else
        [ "", "", true ]
      end
    end

    def run(*command, env: {})
      runs << [ command, env ]
      true
    end
  end

  setup do
    @root = Dir.mktmpdir("bonfire-deployment-test")
    FileUtils.mkdir_p(File.join(@root, ".kamal"))
    @output = StringIO.new
    @error = StringIO.new
    @runner = FakeRunner.new
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test "configure-only setup writes private configuration and generated secrets" do
    result = cli.run(%w[setup --host chat.example.com --configure-only])

    assert_equal 0, result
    assert_includes File.read(File.join(@root, ".kamal/deploy.env")), "DEPLOY_HOST=chat.example.com"
    assert_includes File.read(File.join(@root, ".kamal/deploy.env")), "KAMAL_SERVICE=bonfire"
    assert_equal 0o600, File.stat(File.join(@root, ".kamal/secrets")).mode & 0o777
    assert_empty @runner.runs
  end

  test "setup preserves existing complete secrets" do
    secrets_path = File.join(@root, ".kamal/secrets")
    File.write(secrets_path, <<~SECRETS)
      SECRET_KEY_BASE=existing-secret
      VAPID_PRIVATE_KEY=existing-private
      VAPID_PUBLIC_KEY=existing-public
    SECRETS

    assert_equal 0, cli.run(%w[setup --host chat.example.com --configure-only])
    assert_includes File.read(secrets_path), "existing-secret"
    assert_equal 0o600, File.stat(secrets_path).mode & 0o777
    assert_includes @output.string, "Keeping existing secrets"
  end

  test "status reports secret presence without revealing values" do
    configure
    File.write(File.join(@root, ".kamal/secrets"), <<~SECRETS)
      SECRET_KEY_BASE=never-print-this
      VAPID_PRIVATE_KEY=private-never-print-this
      VAPID_PUBLIC_KEY=public-never-print-this
    SECRETS

    assert_equal 0, cli.run(%w[status --local])
    assert_includes @output.string, "SECRET_KEY_BASE: configured"
    refute_includes @output.string, "never-print-this"
  end

  test "deploy refuses a dirty worktree by default" do
    configure
    File.write(File.join(@root, ".kamal/secrets"), <<~SECRETS)
      SECRET_KEY_BASE=secret
      VAPID_PRIVATE_KEY=private
      VAPID_PUBLIC_KEY=public
    SECRETS
    @runner.git_dirty = true

    assert_equal 1, cli.run(%w[deploy --yes])
    assert_includes @error.string, "uncommitted changes"
    assert_empty @runner.runs
  end

  test "deploy invokes Kamal with configuration in the environment" do
    configure
    File.write(File.join(@root, ".kamal/secrets"), <<~SECRETS)
      SECRET_KEY_BASE=secret
      VAPID_PRIVATE_KEY=private
      VAPID_PUBLIC_KEY=public
    SECRETS

    assert_equal 0, cli.run(%w[deploy --yes])
    assert_equal 1, @runner.runs.size
    command, environment = @runner.runs.first
    assert_equal %w[kamal deploy], command
    assert_equal "chat.example.com", environment.fetch("DEPLOY_HOST")
  end

  test "environment files reject unknown settings" do
    path = File.join(@root, ".kamal/deploy.env")
    File.write(path, "DEPLOY_HOST=chat.example.com\nUNSAFE=value\n")

    assert_equal 1, cli.run(%w[status --local])
    assert_includes @error.string, "unsupported setting"
  end

  private
    def cli
      Bonfire::Deployment::CLI.new(
        root: @root, input: StringIO.new, output: @output, error: @error, runner: @runner
      )
    end

    def configure
      File.write(File.join(@root, ".kamal/deploy.env"), <<~CONFIG)
        DEPLOY_HOST=chat.example.com
        DEPLOY_SSH_USER=root
      CONFIG
    end
end
