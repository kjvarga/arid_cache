

module AridCache
  class CacheHash < Hash
    def initialize(records)
      @records = records
      self[:ids] = records.collect(&:id)
    end
    
    # If we have the records we don't need *proc*, otherwise we do.
    def paginate(opts, proc=nil)
      raise ArgumentError.new("Proc is required if no records present") if proc.nil? && @records.nil?
      
      if @records.nil?
        ids = opts.include?(:page) ? ids.paginate(opts) : ids
        records = proc.call(ids)
        ids.is_a?(WillPaginate::Collection) ? ids.replace(records) : records
      else
        opts.include?(:page) ? @records.paginate(opts) : @records
      end
    end
    
    def ids; self[:ids]; end
  end
end