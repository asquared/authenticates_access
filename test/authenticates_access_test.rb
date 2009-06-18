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
    if item.save 
      flunk
    end
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
    if user.save
      flunk
    end
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
end
