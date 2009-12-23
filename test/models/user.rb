require 'arid_cache'

class User < ActiveRecord::Base
  has_many :companies, :foreign_key => :owner_id
  named_scope :companies, :joins => :companies
  named_scope :successful, :joins => :companies, :conditions => 'companies.employees > 50'
  
  def big_companies
    companies.find :all, :conditions => [ 'employees > 20' ]
  end
  #class << self
    #cache_big_companies(:order => 'name DESC')
  #end
  
  
  def method_missing(method, *args)
    if method == :is_high?
      true
    else
      super
    end
  end
end