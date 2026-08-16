require "test_helper"
require "stringio"
require "tmpdir"
require "bonfire/deployment"

class Bonfire::DeploymentTest < ActiveSupport::TestCase
  class FakeRunner
    attr_reader :runs
    attr_accessor :git_dirty, :fail_commands

    def initialize
      @runs = []
      @git_dirty = false
      @fail_commands = []
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
      !fail_commands.include?(command)
    end

    def pipe(source_command, target_command)
      runs << [ [ "pipe", source_command, target_command ], {} ]
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
    assert_equal "chat.example.com", environment.fetch("DEPLOY_SERVER")
  end

  test "kamal forwards arguments with configuration without reading secrets" do
    configure
    File.write(File.join(@root, ".kamal/secrets"), <<~SECRETS)
      SECRET_KEY_BASE=never-print-this
      VAPID_PRIVATE_KEY=private-never-print-this
      VAPID_PUBLIC_KEY=public-never-print-this
    SECRETS

    assert_equal 0, cli.run(%w[kamal app logs --since 5m])

    command, environment = @runner.runs.sole
    assert_equal %w[kamal app logs --since 5m], command
    assert_equal "chat.example.com", environment.fetch("DEPLOY_HOST")
    refute_includes environment, "SECRET_KEY_BASE"
    refute_includes @output.string, "never-print-this"
    refute_includes @error.string, "never-print-this"
  end

  test "kamal leaves dynamic secret resolution to Kamal" do
    configure
    File.write(File.join(@root, ".kamal/secrets"), <<~SECRETS)
      SECRETS=$(secret-provider fetch)
      SECRET_KEY_BASE=$(secret-provider extract SECRET_KEY_BASE $SECRETS)
    SECRETS

    assert_equal 0, cli.run(%w[kamal details])
    assert_equal %w[kamal details], @runner.runs.sole.first
  end

  test "kamal refuses commands that can expose secrets or execute arbitrary code" do
    configure
    configure_secrets

    %w[config secrets console shell dbc].each do |command|
      assert_equal 1, cli.run([ "kamal", command ])
    end
    assert_equal 1, cli.run(%w[kamal app exec printenv])
    assert_equal 1, cli.run(%w[kamal accessory exec database printenv])

    assert_includes @error.string, "disabled by the LLM-safe wrapper"
    assert_empty @runner.runs
  end

  test "setup can configure a separate deployment server" do
    assert_equal 0, cli.run(%w[setup --host chat.example.com --server 203.0.113.10 --configure-only])

    configuration = File.read(File.join(@root, ".kamal/deploy.env"))
    assert_includes configuration, "DEPLOY_HOST=chat.example.com"
    assert_includes configuration, "DEPLOY_SERVER=203.0.113.10"
  end

  test "migration dry run checks both servers without changing them" do
    configure
    configure_secrets

    assert_equal 0, cli.run(%w[migrate root@203.0.113.10 --dry-run])
    assert_includes @output.string, "Source:      root@chat.example.com"
    assert_includes @output.string, "Target:      root@203.0.113.10"
    assert_includes @output.string, "Neither server was changed"
    assert_empty @runner.runs
    refute File.exist?(File.join(@root, ".kamal/migration.json"))
  end

  test "migration rejects the current server as its target" do
    configure
    configure_secrets

    assert_equal 1, cli.run(%w[migrate root@chat.example.com --dry-run])
    assert_includes @error.string, "current deployment server"
  end

  test "migration stops the source, copies storage, deploys the target, and saves it" do
    configure
    configure_secrets
    Resolv.stubs(:getaddresses).returns([ "203.0.113.10" ])

    assert_equal 0, cli.run(%w[migrate root@203.0.113.10 --yes])

    commands = @runner.runs.map(&:first)
    assert_includes commands, %w[kamal server bootstrap]
    assert_includes commands, %w[kamal app stop]
    assert_includes commands, %w[kamal setup]
    assert_includes commands, %w[kamal deploy]
    assert commands.any? { |command| command.first == "pipe" }

    configuration = File.read(File.join(@root, ".kamal/deploy.env"))
    assert_includes configuration, "DEPLOY_HOST=chat.example.com"
    assert_includes configuration, "DEPLOY_SERVER=203.0.113.10"
    refute File.exist?(File.join(@root, ".kamal/migration.json"))
  end

  test "migration restarts the source when the first target deployment fails" do
    configure
    configure_secrets
    @runner.fail_commands = [ %w[kamal setup] ]

    assert_equal 1, cli.run(%w[migrate root@203.0.113.10 --yes])

    starts = @runner.runs.select { |command, _| command == %w[kamal app start] }
    assert_equal 1, starts.size
    assert_equal "chat.example.com", starts.first.last.fetch("DEPLOY_SERVER")

    state = JSON.parse(File.read(File.join(@root, ".kamal/migration.json")))
    assert_equal "bootstrapped", state.fetch("stage")
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


    def configure_secrets
      File.write(File.join(@root, ".kamal/secrets"), <<~SECRETS)
        SECRET_KEY_BASE=secret
        VAPID_PRIVATE_KEY=private
        VAPID_PUBLIC_KEY=public
      SECRETS
    end

end
