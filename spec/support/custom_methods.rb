module CustomMethods
  def with_order_in_memory(*values)
    original = AridCache.order_in_memory?
    values.each do |value|
      AridCache.order_in_memory = value
      yield
    end
    AridCache.order_in_memory = original
  end
end

class String
  def json_to_hash
    HashWithIndifferentAccess.new JSON.parse(self)
  end
end
