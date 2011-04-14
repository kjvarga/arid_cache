require 'arid_cache'

class User < ActiveRecord::Base
  has_many :companies, :foreign_key => :owner_id
  has_many :empty_user_relations  # This must always return an empty list
  send(Rails.rails3? ? :scope : :named_scope, :companies, :joins => :companies)
  send(Rails.rails3? ? :scope : :named_scope, :successful, :joins => :companies, :conditions => 'companies.employees > 50', :group => 'users.id')

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

  def respond_to?(method, include_private=false)
    if method == :respond_not_overridden
      true
    else
      super
    end
  end
end
