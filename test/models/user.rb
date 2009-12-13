require 'arid_cache'

class User < ActiveRecord::Base
  include AridCache
  has_many :companies, :foreign_key => :owner_id
  
  def method_missing(method, *args)
    if method == :is_high?
      true
    else
      super
    end
  end
end