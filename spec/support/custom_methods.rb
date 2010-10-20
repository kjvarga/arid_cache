class String
  
  def json_to_hash
    HashWithIndifferentAccess.new JSON.parse(self)
  end
  
end