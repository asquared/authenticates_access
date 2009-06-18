# AuthenticatesAccess

module AuthenticatesAccess
  class AuthMethod < Struct.new(:type, :name, :options)
  end

  class AuthMethodList < Array
    def add_method(options)
      if options[:with_accessor_method]
        self << AuthMethod.new( :accessor, options[:with_accessor_method], options )
      elsif options[:with]
        self << AuthMethod.new( :model, options[:with], options )
      else
        fail "Either :with or :with_accessor_method must be specified"
      end
    end

    def check(targets)
      # start out assuming we have not passed any tests
      # if one passes this gets set to true
      passed = false

      self.each do |method|
        unless targets[method.type].nil?
          target = targets[method.type]
          if run_method(target, method.name.to_sym, method.options[:options])
            passed = true
          end
        end
      end
      passed
    end
    
    protected

    # Run a method on the object if it's available, otherwise return false.
    def run_method(object, method, options)
      if object.nil?
        false
      elsif object.respond_to?(method)
        if options
          object.send(method, options)
        else
          object.send(method)
        end
      else
        false
      end
    end

  end

  
  module ClassMethods
    # Set an accessor to be used
    def accessor=(accessor)
      @@accessor = accessor
    end

    # Return the accessor being used by the model classes
    def accessor
      @@accessor ||= nil
      @@accessor
    end

    # Include the instance methods used to implement authentication
    def authenticates_access
      include InstanceMethods
    end

    # Used to require an authentication test to be passed on the accessor
    # before the model may be saved or destroyed. If the test fails, an exception
    # will be thrown. Multiple calls build a chain of tests. If any test
    # passes, the accessor is considered authenticated. Attribute writes will
    # also be disallowed if the object may not be saved by the accessor
    # 
    # examples:
    #
    # authenticates_saves :with_accessor_method => :is_admin
    #   will only allow the object to be saved if the accessor's is_admin
    #   method returns true
    #
    # authenticates_saves :with => :allow_owner
    #   will only allow the object to be saved if its own allow_owner
    #   method returns true
    #
    def authenticates_saves(options={})
      unless @save_method_list
        authenticates_access
        before_save :auth_save_filter
        before_destroy :auth_save_filter
        @save_method_list = AuthMethodList.new
      end

      @save_method_list.add_method(options)      
    end
    
    # Used to specify that a given attribute should only be written to if the
    # accessor passes a test. The test may be a method of the accessor or
    # of the object itself, which should return a boolean value.. If the test 
    # fails, the attribute write will be ignored. Multiple calls build up
    # a chain of tests: if any test in the chain passes, the accessor is
    # considered authorized.
    #
    # Examples:
    #
    # authenticates_writes_to :is_admin, :with_accessor_method => :is_admin
    #   would only allow admins to grant or revoke the admin privileges of others
    #
    # authenticates_writes_to :title, :with => :allow_owner
    #   would only allow the owner of this object to edit its title
    #
    def authenticates_writes_to(attr, options={})
      authenticates_access
      @write_validation_map ||= {}
      @write_validation_map[attr.to_s] ||= AuthMethodList.new
      @write_validation_map[attr.to_s].add_method(options)
    end

    # You might use this one to only allow authenticated users to create objects
    def authenticates_creation(options={})
      unless @create_method_list
        authenticates_access
        before_create :auth_create_filter
        @create_method_list = AuthMethodList.new
        extend CreationControl
      end

      @create_method_list.add_method(options)
    end

    # Used to specify that a given attribute represents an accessor that is
    # an owner of this object. This creates an allow_owner method which
    # may be used to allow the object's owner to save the object, or edit
    # certain attributes, as well as an owner_id method which returns the
    # owner's ID. Currently, accessors are compared by their ID in the database,
    # so accessors should be of the same class to avoid security holes.
    # (i.e. if both User and Group are used as accessors, a User with ID 7 can
    # access objects owned by a Group with ID 7).
    # This may be fixed in the future.
    #
    # Example:
    # belongs_to :user
    # has_owner :user
    # authenticates_saves :with => :allow_owner
    #
    # or:
    #
    # has_owner
    # def owner_id
    #   id
    # end
    #
    def has_owner(attr=nil)
      unless attr.nil?
        id_accessor = "#{attr.to_s}_id"
        id_mutator = "#{attr.to_s}_id="
        if attr == :self
          # special case the self attribute but don't allow ownership change
          define_method(:owner_id) do
            id
          end
        else
          define_method(:owner) do
            self.send(attr)
          end
          define_method(:owner_id) do
            self.send(id_accessor)
          end
          define_method("owner_id=") do |new_value|
            self.send(id_mutator,new_value)
          end
        end
      end
      include Ownership 
    end

    # If declared, the accessor used to create this object automatically
    # becomes its owner.
    # 
    # Examples:
    #
    # class Comment < ActiveRecord::Base
    #   belongs_to :member
    #   has_owner :member
    #   autosets_owner_on_create
    #   authenticates_saves :with => :allow_owner
    # end
    #
    def autosets_owner_on_create
      has_owner # this will do nothing if the user has already set up has_owner :something
      # the hook runs before validation so we can validate_associated
      before_validation_on_create :autoset_owner
    end


    def authenticates_saves_method_list
      @save_method_list ||= nil
      @save_method_list
    end

    def write_validations(attr)
      @write_validation_map ||= nil
      if @write_validation_map
        @write_validation_map[attr]
      else
        nil
      end
    end
  end

  module InstanceMethods
    # Shorthand to get at the accessor of interest
    def accessor
      self.class.accessor
    end

    def bypass_auth
      @bypass_auth = true
      yield
      @bypass_auth = false
    end

    # Auto-set the owner id to the accessor id before save if the object is new
    def autoset_owner
      bypass_auth do
        self.owner_id = accessor.id
      end

      true # this is very important!
    end



    # before_save/before_destroy hook installed by authenticates_saves
    def auth_save_filter
      if not allowed_to_save
        # An interesting thought: could this throw an HTTP error?
        false
      else
        true
      end
    end
    
    # before_save/before_destroy hook installed by authenticates_saves
    def auth_create_filter
      if not self.class.allowed_to_create
        false
      else
        true
      end
    end

    # This method may be used to determine whether the current accessor has 
    # privileges to save the object. Returns true if so, false otherwise.
    def allowed_to_save
      method_list = self.class.authenticates_saves_method_list
      if method_list.nil?
        # No method list, so it's allowed
        true
      elsif method_list.check :accessor => accessor, :model => self
        # Method list passed, so allowed
        true
      else
        # Method list failed, so denied
        false
      end
    end

    # Overload of write_attribute to implement the filtration
    def write_attribute(name, value)
      # Simply check if the accessor is allowed to write the field
      # (if so, go to superclass and do it)
      @bypass_auth ||= false
      if allowed_to_write(name) || @bypass_auth
        super(name, value)
      end
    end
    
    # This method may be used to determine if the current accessor may write
    # to a given attribute. Returns true if so, false otherwise.
    def allowed_to_write(name)
      # no point allowing attribute writes if we can't save them?
      if allowed_to_save
        name = name.to_s
        validation_methods = self.class.write_validations(name)  
        if validation_methods.nil?
          # We haven't registered any filters on this attribute, so allow the write.
          true
        elsif validation_methods.check :accessor => accessor, :model => self
          # One of the authentication methods worked, so allow the write.
          true
        else
          # We had filters but none of them passed. Disallow write.
          false
        end
      else
        false
      end
    end
  end

  module Ownership
    # This method implements a simple test: whether the object is owned by 
    # the accessor. See has_owner in ClassMethods. Note that new records,
    # with no owner, will always pass this test. This allows the 
    # (not-yet-existent) owner (i.e. the creator) to write any attributes 
    # that they would have had access to anyway. Use authenticates_creation
    # to allow only certain accessors the right to create objects.
    def allow_owner(options={})
      if new_record?
        true
      elsif accessor.nil?
        false # maybe this is failing up the works?
      else
        # must define an owner_id method for this to work
        accessor.id == owner_id
      end
    end
  end

  module CreationControl
    def allowed_to_create
      method_list = @create_method_list
      if method_list.nil?
        # No method list, so it's allowed
        true
      elsif method_list.check :accessor => accessor
        # Method list passed, so allowed
        true
      else
        # Method list failed, so denied
        false
      end
    end
  end

end

