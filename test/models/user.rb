require 'arid_cache'

class User < ActiveRecord::Base
  has_many :companies, :foreign_key => :owner_id
  named_scope :companies, :joins => :companies
  
  def method_missing(method, *args)
    if method == :is_high?
      true
    else
      super
    end
  end
end