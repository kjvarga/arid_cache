module AridCache
  module Proxies
    class IdProxy  
      # Return a Proc which takes an array.  If the array contains ActiveRecords a list of
      # ids is returned.  If the array contains ids, the corresponding records are returned.
      # All the records must be of class +klass+
      def self.for(klass)
        return Proc.new do |records|
          return records if records.empty?
          records.first.is_a?(::ActiveRecord::Base) ? records.collect(&:id) : AridCache.find_all_by_id(klass, records)
        end      
      end
    end
  end
end