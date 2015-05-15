#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "json"


module TT::Plugins::CitiesSkylinesTools

  class ErrorReporter

    # @param [Hash] config
    # @option config [String] :extension_id
    # @option config [SketchupExtension] :extension
    # @option config [String] :server
    # @option config [String] :support_url
    # @option config [String] :debug (false)
    # @option config [String] :test (false) Set to true to log errors as test
    #                                       data in the database.
    def initialize(config)
      @extension_id = get_required_config(config, :extension_id)
      @extension    = get_required_config(config, :extension)
      @server       = get_required_config(config, :server)
      @debug        = get_optional_config(config, :debug, false)
      @test         = get_optional_config(config, :test, false)
      @support_url  = config[:support_url]
      @window       = nil
      @events       = {}
    rescue Exception => exception
      # Here we actually raise the exception because this happen during the
      # setup phase and should not be done as part of an exception handling.
      raise handle_unexpected_exception(exception)
    end

    # @param [Exception] exception
    #
    # @return [Exception]
    def handle(exception)
      show_dialog(exception)
      raise exception
    end


    protected


    # @param [String] event
    #
    # @return [Boolean]
    def on(event, &block)
      if block
        @events[event] ||= []
        @events[event] << block
        true
      else
        false
      end
    rescue Exception => exception
      handle_unexpected_exception(exception)
    end


    private


    # @return [String]
    def preference_key
      "ExtensionErrorReport"
    end


    # @param [Hash] config
    # @param [Symbol] key
    #
    # @return [Mixed]
    def get_required_config(config, key)
      if config.key?(key)
        if config[key].nil?
          raise TypeError, "#{key} cannot be nil"
        else
          config[key]
        end
      else
        raise ArgumentError, "#{key} required"
      end
    end

    # @param [Hash] config
    # @param [Symbol] key
    # @param [Mixed] default
    #
    # @return [Mixed]
    def get_optional_config(config, key, default)
      if config.key?(key)
        config[key]
      else
        default
      end
    end

    # @param [Exception] exception_to_handle
    #
    # @return [Boolean]
    def show_dialog(exception_to_handle)
      # Only one dialog can be created at a time. Otherwise errors in mouse
      # events or observers cause hundreds of dialogs popping up.
      # If another error occur while the error dialog is open the error is
      # simply re-raised.
      return false if @window && @window.visible?
      @window = create_dialog(@extension_id, @extension)
      on("dialog_ready") { |dialog, data|
        setup_error_data(dialog, exception_to_handle)
        dialog = nil
      }
      # It's necessary to hold on to a reference to the UI::WebDialog.
      # Otherwise it'll close if the garbage collector kicks in while it's
      # open.
      if Sketchup.platform == :platform_osx
        @window.show_modal
      else
        @window.show
      end
      true
    rescue Exception => exception
      handle_unexpected_exception(exception)
    end

    # @param [UI::WebDialog] window
    # @param [Exception] exception
    #
    # @return [Nil]
    def setup_error_data(window, exception)
      error_data = {
        :config => {
          :server => @server,
          :support_url => @support_url,
          :debug => @debug
        },

        :test => @test,

        :extension => {
          :id => @extension_id,
          :extension_warehouse_id => @extension.id,
          :name => @extension.name,
          :version => @extension.version
        },

        :exception => {
          :inspect => exception.inspect,
          :type => exception.class.name,
          :message => exception.message,
          :backtrace => exception.backtrace
        },

        :environment => {
          :sketchup => {
            :version => Sketchup.version,
            :is_pro => Sketchup.is_pro? ? 1 : 0, # `true` is POSTed as 0...
            :product_family => sketchup_product_family,
            :is_64bit => sketchup_is_64bit? ? 1 : 0,
            :locale => Sketchup.get_locale,
            :platform => Sketchup.platform.to_s
          },
          :ruby => {
            :version => RUBY_VERSION,
            :platform => RUBY_PLATFORM,
            :patch_level => RUBY_PATCHLEVEL
          },
          :loaded_features => get_utf8_list($LOADED_FEATURES),
          :load_path => get_utf8_list($LOAD_PATH)
        }
      }
      call(window, "setup_error_data", error_data)
      nil
    end

    # @param [UI::WebDialog] window
    # @param [String] function
    #
    # @return [Nil]
    def call(window, function, *arguments)
      if window.nil? || !window.visible?
        raise RuntimeError, "Window must be visible before making calls to it"
      end
      json_arguments = arguments.map { |argument| argument.to_json }
      js_arguments = json_arguments.join(", ")
      js_command = "#{function}(#{js_arguments});"
      window.execute_script(js_command)
      true
    end

    # @param [String] extension_id
    # @param [SketchupExtension] extension
    #
    # @return [UI::WebDialog]
    def create_dialog(extension_id, extension)
      options = {
        :dialog_title     => "#{extension.name} Error Report",
        :preferences_key  => extension_id,
        :resizable        => false,
        :scrollable       => false,
        :left             => 400,
        :top              => 400,
        :width            => 450,
        :height           => 580
      }
      window = UI::WebDialog.new(options)

      # Hide the navigation buttons that appear on OSX.
      if window.respond_to?(:navigation_buttons_enabled=)
        window.navigation_buttons_enabled = false
      end

      # OSX has a bug where it ignores the resize flag and let the user resize
      # the window. Setting the min and max values for width and height works
      # around this issue.
      #
      # To make things worse, OSX sets the client size with the min/max
      # methods - causing the window to grow if you set the min size to the
      # desired target size. To account for this we set the min sizes to be
      # a little less that the desired width. The size should be larger than
      # the titlebar height.
      #
      # All this has to be done before we set the size in order to restore the
      # desired size because the min/max methods will transpose the external
      # size to content size.
      #
      # The result is that the height is adjustable a little bit, but at least
      # it's restrained to be close to the desired size. Lesser evil until
      # this is fixed in SketchUp.
      window.min_width = options[:width]
      window.max_width = options[:width]
      window.min_height = options[:height] - 30
      window.max_height = options[:height]
      window.set_size(options[:width], options[:height])

      # Hook up callback bridge.
      window.add_action_callback("callback") { |dialog, event_name|
        #puts "Callback: 'callback(#{event_name})'"
        json = dialog.get_element_value("SU_BRIDGE")
        if json && json.size > 0
          data = JSON.parse(json)
        else
          data = nil
        end
        trigger_event(event_name, data)
        # Prevent circular references the would prevent the object from being
        # collected by the GC.
        event_name = data = dialog = nil
      }

      on("open_url") { |dialog, data|
        UI.openURL(data["url"])
        dialog = data = nil
      }

      on("dialog_ready") { |dialog, data|
        section = preference_key
        user_data = {
          :user_name => Sketchup.read_default(section, "name",  ""),
          :user_email => Sketchup.read_default(section, "email", "")
        }
        call(dialog, "restore_form", user_data)
        dialog = data = nil
      }

      on("save_and_close") { |dialog, data|
        section = preference_key
        Sketchup.write_default(section, "name",  data["name"].to_s)
        Sketchup.write_default(section, "email", data["email"].to_s)
        dialog.close
        dialog = data = nil
      }

      # It appear that __dir__ doesn't work in RBS files.
      path = File.dirname(__FILE__)
      window.set_file(File.join(path, "error_reporter.html"))
      window
    end

    # @param [String] event
    # @param [JSON] data
    #
    # @return [Boolean]
    def trigger_event(event, data = nil)
      if @events.key?(event)
        @events[event].each { |callback|
          if data
            callback.call(@window, data)
          else
            callback.call(@window)
          end
        }
        true
      else
        false
      end
    rescue Exception => exception
      handle_unexpected_exception(exception)
    end

    # @return [Boolean]
    def sketchup_is_64bit?
      Sketchup.respond_to?(:is_64bit?) && Sketchup.is_64bit?
    end

    # For some reason +get_product_family+ was incorrectly placed on the
    # Sketchup::Model class - which means it will not be possible to access
    # if there are no models open under OSX.
    #
    # @return [Integer]
    def sketchup_product_family
      if Sketchup.active_model
        Sketchup.active_model.get_product_family
      else
        0 # Unknown
      end
    end

    # @param [Array<String>]
    #
    # @return [String]
    def get_utf8_list(enumerator)
      enumerator.dup.map { |path|
        string = path.dup
        begin
          string.encode("UTF-8")
        rescue
          # Under Windows there are multiple strings relating to files that
          # can have the incorrect encoding applied. They appear to generally
          # be UTF-8 data with the wrong encoding label. To account for this we
          # assume that any transcoding error to UTF-8 is a result of
          # mis-labelled UTF-8 strings and then fall back to forcing the
          # encoding.
          string.force_encoding("UTF-8")
        end
        string
      }
    end

    # Handling errors in the error handler - how meta!
    #
    # Because this would happen when we are setting up the dialog when handling
    # an existing exception we simply output these errors to the console so
    # the user sees that something happened. Hopefully the user will report the
    # problem back to the developer.
    #
    # @param [Exception] exception
    #
    # @return [Exception]
    def handle_unexpected_exception(exception)
      SKETCHUP_CONSOLE.show
      p exception
      puts exception.backtrace.join("\n")
      exception
    end

  end # class

end # module
