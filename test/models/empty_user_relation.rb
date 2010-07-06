require 'arid_cache'

class EmptyUserRelation < ActiveRecord::Base
  belongs_to :user
end