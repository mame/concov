#
# concov - continuous coverage manager
#
#   * lib/error.rb: error utilities
#

module Concov
  # reporting error
  class ConcovError < StandardError
  end

  def error(msg)
    raise ConcovError.new(msg)
  end
  module_function :error
end
