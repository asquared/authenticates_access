require 'test_helper'

class AuthenticatesAccessTest < ActiveSupport::TestCase
  test "authenticates_saves :with => :allow_owner positive" do
    ActiveRecord::Base.accessor = users(:user1)
    item = owned_items(:item3)
    item.description = "I changed the text"
    assert item.save
  end

  test "authenticates_saves :with => :allow_owner negative" do
    ActiveRecord::Base.accessor = users(:user1)
    item = owned_items(:item4)
    item.description = "I changed the text"
    flunk if item.save 
  end

  test "authenticates_saves :with => :allow_owner on new object" do
    ActiveRecord::Base.accessor = users(:user1)
    item = OwnedItem.new(:description => "This should work")
    assert item.save
    assert item.user_id == users(:user1).id
  end

  test "authenticates_creates negative" do
    ActiveRecord::Base.accessor = users(:user1)
    user = User.new(
      :is_admin => true, 
      :name => "cracker", 
      :bio => "I like breaking into things"
    )
    flunk if user.save
  end

  test "authenticates_creates positive" do
    ActiveRecord::Base.accessor = users(:admin)
    user = User.new(
      :is_admin => false, 
      :name => "some legit user", 
      :bio => "This should work"
    )
    assert user.save
  end

  test "authenticates_writes_to negative" do
    ActiveRecord::Base.accessor = users(:user1)
    user2 = users(:user2)
    user2.is_admin = true
    flunk if user2.is_admin
  end

  test "authenticates_writes_to positive" do
    ActiveRecord::Base.accessor = users(:admin)
    user2 = users(:user2)
    user2.is_admin = true
    assert user2.is_admin
  end

  test "allowed_to_create positive" do
    ActiveRecord::Base.accessor = users(:admin)
    assert User.allowed_to_create
  end

  test "allowed_to_create negative" do
    ActiveRecord::Base.accessor = users(:user1)
    flunk if User.allowed_to_create
  end

  test "allowed_to_write positive" do
    ActiveRecord::Base.accessor = users(:admin)
    assert users(:user1).allowed_to_write(:is_admin)
    assert users(:user1).allowed_to_write(:bio)

    ActiveRecord::Base.accessor = users(:user1)
    assert users(:user1).allowed_to_write(:bio)

    flunk if users(:user2).allowed_to_write(:bio)
  end

  test "allowed_to_write negative" do
    ActiveRecord::Base.accessor = users(:user1)
    flunk if users(:user1).allowed_to_write(:is_admin)
  end

  test "allowed_to_save as user1" do
    ActiveRecord::Base.accessor = users(:user1)
    assert owned_items(:item3).allowed_to_save
    flunk if owned_items(:item4).allowed_to_save
  end
    
end
