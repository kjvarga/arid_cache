require 'arid_cache'

class Company < ActiveRecord::Base

  send(Rails.rails3? ? :scope : :named_scope, :owned, :conditions => ['owner_id is not null'])
  belongs_to :owner, :class_name => 'User'
end