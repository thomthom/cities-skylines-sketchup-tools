#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  PATH_IMAGES = File.join(PATH, "images").freeze


  require "tt_citites_skylines/exporter.rb"
  require "tt_citites_skylines/guide_grid.rb"


  unless file_loaded?(__FILE__)
    menu = UI.menu("Plugins").add_submenu(PLUGIN_NAME)
    toolbar = UI::Toolbar.new(PLUGIN_NAME)

    # Commands
    toolbaritems = ["Export Asset", "Guide Grid Config", "Increase Subdivision Level", "Decrease Subdivision Level", "One Floor Up", "One Floor Down" ]
    toolbaritemicons = ["export", "guide_grid_cfg", "guide_grid_subdiv_inc", "guide_grid_subdiv_dec", "guide_grid_level_inc", "guide_grid_level_dec"]
    toolbaritemmethods = ["export_asset", "guide_grid_config", "guide_grid_subdiv_level", "guide_grid_subdiv_level", "guide_grid_height_level", "guide_grid_height_level"]
    toolbaritemparams = [ nil,  nil, "Inc", "Dec", "Up", "Down"]
    
    toolbaritems.each_with_index {|val, index|
      cmd = UI::Command.new(val) {
        self.send(toolbaritemmethods[index],toolbaritemparams[index]) unless toolbaritemparams[index].nil?
        self.send(toolbaritemmethods[index]) if toolbaritemparams[index].nil?
      }
      cmd.tooltip = val
      cmd.small_icon = File.join(PATH_IMAGES, toolbaritemicons[index]+"-16.png")
      cmd.large_icon = File.join(PATH_IMAGES, toolbaritemicons[index]+"-24.png")
      menu.add_item(cmd)
      toolbar.add_item(cmd)
    }
    toolbar.restore
    file_loaded(__FILE__)
  end


  # TT::Plugins::CitiesSkylinesTools.reload
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    ruby_files = File.join(PATH, '*.{rb,rbs}')
    x = Dir.glob(ruby_files).each { |file|
      load file
    }
    x.length
  ensure
    $VERBOSE = original_verbose
  end

end # module TT::Plugins::CitiesSkylinesTools
