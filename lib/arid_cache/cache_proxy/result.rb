module AridCache
  module CacheProxy
    # A class representing a result that is to be processed in some way before
    # being returned to the user.
    #
    # Provides methods to introspect the result.  The contents could be a base type,
    # or an enumerable of sorts...any type really.  We are only concerned with enumerables,
    # and especially those containing active records.
    class Result

      def initialize(result)
        @result = result
      end

      # Return true if the result is an enumerable and it is empty.
      def is_empty?
        is_enumerable? && @result.empty?
      end

      # Return true if the result is an enumerable.
      def is_enumerable?
        @result.is_a?(Enumerable)
      end

      # Return true if the result is an enumerable and the first item is
      # an active record.
      def is_activerecord?
        is_enumerable? && @result.first.is_a?(::ActiveRecord::Base)
      end
    end
  end
end