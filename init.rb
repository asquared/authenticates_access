# Install our class and instance methods into ActiveRecord
RAILS_DEFAULT_LOGGER.error("Loading AuthenticatesAccess...")

ActiveRecord::Base.class_eval do
  extend AuthenticatesAccess::ClassMethods
end
