#
# concov - continuous coverage manager
#
#   * lib/command/info.rb: meta information viewer
#

module Concov
  class Command::Info < Command
    def option(op)
      op.banner = "usage: show [first-date|last-date|last-registered-date]"
      op.separator "outputs meta information of database"
    end

    def run(type)
      case type
      when "initialized?"
        puts(Coverage.initialized? ? "true" : "false")

      when "first-date"
        date = Coverage.first_date
        puts date.to_path if date

      when "last-date"
        date = Coverage.last_date
        puts date.to_path if date

      when "last-registered-date"
        date = Coverage.last_registered_date
        puts date.to_path if date

      else
        Concov.error("unknown information: #{ type }")
      end
    end
  end
end

