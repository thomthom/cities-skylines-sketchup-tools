#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  ### CONSTANTS ### ------------------------------------------------------------

  unless defined?(DEBUG)
    # Sketchup.write_default("TT_CitiesSkylines", "DebugMode", true)
    DEBUG = Sketchup.read_default(PLUGIN_ID, "DebugMode", false)
  end

  # Minimum version of SketchUp required to run the extension.
  MINIMUM_SKETCHUP_VERSION = 14


  ### COMPATIBILITY CHECK ### --------------------------------------------------


  if Sketchup.version.to_i < MINIMUM_SKETCHUP_VERSION

    version_name = "20#{MINIMUM_SKETCHUP_VERSION}"
    message = "#{PLUGIN_NAME} require SketchUp #{version_name} or newer."
    messagebox_open = false # Needed to avoid opening multiple message boxes.
    # Defer with a timer in order to let SketchUp fully load before displaying
    # modal dialog boxes.
    UI.start_timer(0, false) {
      unless messagebox_open
        messagebox_open = true
        UI.messagebox(message)
        # Must defer the disabling of the extension as well otherwise the
        # setting won't be saved. I assume SketchUp save this setting after it
        # loads the extension.
        if @extension.respond_to?(:uncheck)
          @extension.uncheck
        end
      end
    }

  else # Sketchup.version

    ### ERROR HANDLER ### ------------------------------------------------------

    require "tt_cities_skylines/third-party/error-reporter/error_reporter.rb"

    # Sketchup.write_default("TT_CitiesSkylines", "ErrorServer", "sketchup.thomthom.local")
    # Sketchup.write_default("TT_CitiesSkylines", "ErrorServer", "sketchup.thomthom.net")
    server = Sketchup.read_default(PLUGIN_ID, "ErrorServer",
      "sketchup.thomthom.net")

    extension = Sketchup.extensions[PLUGIN_NAME]

    config = {
      :extension_id => PLUGIN_ID,
      :extension    => extension,
      :server       => "http://#{server}/api/v1/extension/report_error",
      :support_url  => "#{PLUGIN_URL}/support",
      :debug        => DEBUG
    }
    ERROR_REPORTER = ErrorReporter.new(config)

    ### COMPATIBILITY ### ------------------------------------------------------

    # Detect older versions which was had a typo in their filenames.
    # This assumes the extension is installed in the Plugins folder and not
    # loaded from some other location.
    begin
      legacy_root_rb = Sketchup.find_support_file("Plugins/tt_citites_skylines.rb")
      if legacy_root_rb
        puts "Removing old extension: #{legacy_root_rb}"
        File.delete(legacy_root_rb)
        # Prevent SketchUp from trying to load it.
        $LOADED_FEATURES << legacy_root_rb
      end
      legacy_folder = Sketchup.find_support_file("Plugins/tt_citites_skylines")
      if legacy_folder
        puts "Removing old extension: #{legacy_folder}"
        require 'fileutils'
        FileUtils.rm_rf(legacy_folder)
      end
    rescue Exception => error
      ERROR_REPORTER.handle(error)
    end

    ### LOAD EXTENSION ### -----------------------------------------------------

    begin
      require "tt_cities_skylines/core.rb"
    rescue Exception => error
      ERROR_REPORTER.handle(error)
    end

  end # if Sketchup.version

end # module TT::Plugins::CitiesSkylinesTools
