module AridCache
  class CacheProxy
    module Utilities
      extend self

      # Generate an ORDER BY clause that preserves the ordering of the ids in *ids*.
      #
      # The method we use depends on the database adapter because only MySQL
      # supports the ORDER BY FIELD() function.  For other databases we use
      # a CASE statement.
      def order_by(ids, klass=nil)
        column = if klass.respond_to?(:table_name)
          ::ActiveRecord::Base.connection.quote_table_name(klass.table_name) + '.id'
        else
          "id"
        end

        if ids.empty?
          nil
        elsif ::ActiveRecord::Base.is_mysql_adapter?
          "FIELD(#{column},#{ids.join(',')})"
        else
          order = ''
          ids.each_index { |i| order << "WHEN #{column}=#{ids[i]} THEN #{i+1} " }
          "CASE " + order + " END"
        end
      end

      # Return the object's class or the object if it is a class.
      def object_class(object)
        object.is_a?(Class) ? object : object.class
      end
    end
  end
end