class OwnedItem < ActiveRecord::Base
  belongs_to :user
  has_owner :user
  autosets_owner_on_create

  authenticates_saves :with => :allow_owner
end
