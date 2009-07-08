#
# concov - continuous coverage manager
#
#   * lib/command.rb: abstract command-line interface
#

require "optparse"
require "lib/config"
require "lib/error"
require "model/coverage"

module Concov
  class Command
    EXECNAME = File.basename($0)
    @@commands = {}

    def self.inherited(cmd)
      s = cmd.to_s.sub(/^#{ Regexp.quote(self.to_s) }::/, "")
      s = s.gsub(/([a-z])([^a-z])/) { "#{ $1 }-#{ $2 }" }.downcase
      @@commands[s] = cmd
    end

    def self.main(*argv)
      help, cmd, argv = process_options(argv)

      cmd = @@commands[cmd].new
      op = OptionParser.new
      cmd.option(op)
      op.on_tail("-h", "--help", "show this message") { help = true }
      argv = op.parse(argv)
      (puts op.help; exit) if help
      arity = cmd.method(:run).arity
      unless arity < 0 || arity == argv.size
        Concov.error("wrong number of arguments; see help for usage")
      end
      cmd.run(*argv)
      true # success

    rescue ConcovError
      puts "error: " + $!.message
      false # failure
    end

    def self.process_options(argv)
      help = false
      conf = nil

      op = OptionParser.new
      op.program_name = EXECNAME
      op.version = VERSION
      op.release = "revision"
      op.banner = "usage: #{ EXECNAME } [options] COMMAND [arguments]"
      op.separator nil
      op.on("-c FILE", "--conf FILE", "set conf file") { |path| conf = path }
      op.on("-v", "--version", "show version") { puts op.ver; exit }
      op.on("-h", "--help", "show this message") { help = true }
      op.separator nil
      op.separator "Available subcommands:"
      @@commands.each_key {|cmd| op.separator("    " + cmd) }
      op.separator nil
      op.separator "concov is a tool for coverage management."

      argv = op.order(argv)

      Config.deploy(conf)

      cmd = argv.shift
      (cmd = argv.shift; help = true) if cmd == "help"

      (puts op.help; exit) if help && !cmd
      unless cmd
        Concov.error "subcommand required; see help for usage."
      end
      unless @@commands.include?(cmd)
        Concov.error("unknown command: '#{ cmd }'")
      end

      [help, cmd, argv]
    end
  end
end
