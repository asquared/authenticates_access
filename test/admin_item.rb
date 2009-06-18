class AdminItem < ActiveRecord::Base
  authenticates_saves :with_accessor_method => :is_admin
end
