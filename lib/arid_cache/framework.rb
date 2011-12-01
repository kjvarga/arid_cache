module AridCache
  # A class with framework/application related methods like discovering
  # which version of Rails we are running under.
  class Framework
    # Return a boolean indicating whether the version of ActiveRecord matches
    # the constraints in the args.
    #
    # == Arguments
    # Optional comparator function as a symbol followed by a version number
    # as an integer or float.
    #
    # If the version is an integer only the major version is compared.
    # if the version is a float the major.minor version is compared.
    #
    # If called with no arguments returns a boolean indicating whether ActiveRecord
    # is defined.
    #
    # == Example
    # active_record?(3) => true if ActiveRecord major version is 3
    # active_record?(3.0) => true if ActiveRecord major.minor version is 3.0
    # active_record?(:>=, 3) => true if ActiveRecord major version is >= 3
    # active_record?(:>=, 3.1) => true if ActiveRecord major.minor version is >= 3.1
    def active_record?(*args)
      version, comparator = args.pop, (args.pop || :==)
      result =
        if version.nil?
          defined?(::ActiveRecord)
        elsif defined?(::ActiveRecord)
          ar_version = ::ActiveRecord::VERSION::STRING.to_f
          ar_version = ar_version.floor if version.is_a?(Integer)
          ar_version.send(comparator, version.to_f)
        else
          false
        end
      !!result
    end
    
    # Include framework hooks for Rails
    #
    # This method is called by <tt>init.rb</tt>, which is run by Rails on startup.
    #
    # Customize rendering.  Include custom headers and don't render the layout for AJAX.
    # Insert the Rack::Ajax middleware to rewrite and handle requests.
    # Add custom attributes to outgoing links.
    #
    # Hooks for Rails 3 are installed using Railties.
    def init
      ::ActiveRecord::Base.send(:include, AridCache::ActiveRecord) if active_record?
    end
  end
end
