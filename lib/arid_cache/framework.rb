module AridCache
  # A class with framework/application related methods like discovering
  # which version of Rails we are running under.
  class Framework
    def active_record?(major=nil)
      defined?(::ActiveRecord) && (major.nil? || (major && ::ActiveRecord::VERSION::MAJOR == major))
    end

    # Return true if the version of AR is >= 3.1
    def active_record31?
      defined?(::ActiveRecord) && ::ActiveRecord::VERSION::STRING.to_f >= 3.1
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
