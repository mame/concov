#
# concov - continuous coverage manager
#
#   * model/changes.rb: database of coverage changes (backend: sequel)
#

module Concov
  module Coverage
    class Changes < Sequel::Model(:changes)
      ##
      ##  generator methods
      ##

      # make change instance from hash-like object
      def self.extract(h)
        hash = {}

        # copy all fields except id
        (columns - [:id]).each {|id| hash[id] = h[id].to_i }

        # if there is no change, return nil
        if [:changed, :modified, :created, :deleted].all? {|id| hash[id] == 0 }
          return
        end

        # return change instance
        new(hash)
      end

      # make change instance directly
      def self.make(h)
        changed, modified, created, deleted = case h[:type]
        when :changed  then [1, 0, 0, 0]
        when :modified then [0, 1, 0, 0]
        when :created  then [0, 0, 1, 0]
        when :deleted  then [0, 0, 0, 1]
        end
        code_inc, code_dec, cov_inc, cov_dec =
          [:code_inc, :code_dec, :cov_inc, :cov_dec].map {|id| h[id] || 0 }

        new(
          changed:   changed,
          modified:  modified,
          created:   created,
          deleted:   deleted,
          code_inc:  code_inc,
          code_dec:  code_dec,
          cov_inc:   cov_inc,
          cov_dec:   cov_dec,
        )
      end
    end
  end
end
