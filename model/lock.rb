#
# concov - continuous coverage manager
#
#   * model/lock.rb: for database locking (dirty hack?)
#

module Concov
  module Coverage
    class Lock < Sequel::Model(:lock)
      def self.synchronize
        create(dummy: 1)
        yield
        delete
      end
    end
  end
end
