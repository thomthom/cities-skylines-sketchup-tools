#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "sketchup.rb"
require "extensions.rb"

#-------------------------------------------------------------------------------

module TT
 module Plugins
  module CitiesSkylinesTools

  ### CONSTANTS ### ------------------------------------------------------------

  # Resource paths
  file = __FILE__.dup
  file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
  SUPPORT_FOLDER_NAME = File.basename(file, ".*").freeze
  PATH_ROOT           = File.dirname(file).freeze
  PATH                = File.join(PATH_ROOT, SUPPORT_FOLDER_NAME).freeze

  # Plugin information
  PLUGIN          = self
  PLUGIN_ID       = "TT_CitiesSkylines".freeze
  PLUGIN_NAME     = "Cities Skylines Tools".freeze
  PLUGIN_VERSION  = "0.1.0".freeze
  PLUGIN_URL      = "http://software.thomthom.net/cities".freeze


  ### EXTENSION ### ------------------------------------------------------------

  unless file_loaded?(__FILE__)
    loader = File.join(PATH, "bootstrap.rb")
    ex = SketchupExtension.new(PLUGIN_NAME, loader)
    ex.description = "Tools for creating Cities Skylines assets with SketchUp."
    ex.version     = PLUGIN_VERSION
    ex.copyright   = "Thomas Thomassen © 2015"
    ex.creator     = "Thomas Thomassen (thomas@thomthom.net)"
    @extension = ex
    Sketchup.register_extension(@extension, true)
  end

  end # module CitiesSkylinesTools
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
