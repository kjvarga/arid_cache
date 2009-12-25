require 'arid_cache'

class User < ActiveRecord::Base
  has_many :companies, :foreign_key => :owner_id
  named_scope :companies, :joins => :companies
  named_scope :successful, :joins => :companies, :conditions => 'companies.employees > 50'
  
  def big_companies
    companies.find :all, :conditions => [ 'employees > 20' ]
  end

  def pet_names
    ['Fuzzy', 'Peachy']
  end
  
  def method_missing(method, *args)
    if method == :is_high?
      true
    else
      super
    end
  end
end