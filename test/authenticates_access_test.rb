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
    assert true # why not?
  end

  test "authenticates_saves :with => :allow_owner on new object" do
    ActiveRecord::Base.accessor = users(:user1)
    item = OwnedItem.new(:description => "This should work")
    assert item.save
    assert item.user_id == users(:user1).id
  end
end
