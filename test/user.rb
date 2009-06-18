class User < ActiveRecord::Base
  # users own themselves, so to speak
  has_owner :self

  # only admins can write to the is_admin and can_create fields
  authenticates_writes_to :is_admin, :with_accessor_method => :is_admin
  authenticates_writes_to :can_create, :with_accessor_method => :is_admin
  # users can save their own profiles
  authenticates_saves :with => :allow_owner
  # admins can save anyone's profile
  authenticates_saves :with_accessor_method => :is_admin
  # admins can create users
  authenticates_creation :with_accessor_method => :is_admin
end
