#
# concov - continuous coverage manager
#
#   * lib/command/init.rb: db initializer
#

module Concov
  class Command::Init < Command
    def option(op)
      op.banner = "usage: init"
      op.separator "initialize database."
    end

    def run
      if Coverage.initialized?
        Concov.error("already initialized")
      end
      Coverage.init
    end
  end
end
