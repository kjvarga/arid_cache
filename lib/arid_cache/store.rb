module AridCache
  class Store < Hash  
    def delete!
      delete_if { true }
    end
  end
end