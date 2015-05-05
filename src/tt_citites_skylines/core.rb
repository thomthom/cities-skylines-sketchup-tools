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

    # Commands
    cmd = UI::Command.new("Export Asset") {
      self.export_asset
    }
    cmd.tooltip = "Export Asset"
    cmd.small_icon = File.join(PATH_IMAGES, "export-16.png")
    cmd.large_icon = File.join(PATH_IMAGES, "export-24.png")
    cmd_export_asset = cmd

    cmd = UI::Command.new("Guide Grid") {
      self.guide_grid_config(self.find_grid)
    }
    cmd.tooltip = "Guide Grid"
    cmd.small_icon = File.join(PATH_IMAGES, "guide_grid_cfg-16.png")
    cmd.large_icon = File.join(PATH_IMAGES, "guide_grid_cfg-24.png")
    cmd_create_guide_grid = cmd

    cmd = UI::Command.new("Increase Subdivision Level") {
      self.guide_grid_subdiv_level("Inc")
    }
    cmd.tooltip = "Increase Subdivision Level"
    cmd.small_icon = File.join(PATH_IMAGES, "guide_grid_subdiv_inc-16.png")
    cmd.large_icon = File.join(PATH_IMAGES, "guide_grid_subdiv_inc-24.png")
    cmd_guide_grid_subdiv_level_inc = cmd

    cmd = UI::Command.new("Decrease Subdivision Level") {
      self.guide_grid_subdiv_level("Dec")
    }
    cmd.tooltip = "Decrease Subdivision Level"
    cmd.small_icon = File.join(PATH_IMAGES, "guide_grid_subdiv_dec-16.png")
    cmd.large_icon = File.join(PATH_IMAGES, "guide_grid_subdiv_dec-24.png")
    cmd_guide_grid_subdiv_level_dec = cmd


    cmd = UI::Command.new("One Floor Up") {
      self.guide_grid_height_level("Up")
    }
    cmd.tooltip = "One Floor Up"
    cmd.small_icon = File.join(PATH_IMAGES, "guide_grid_level_inc-16.png")
    cmd.large_icon = File.join(PATH_IMAGES, "guide_grid_level_inc-24.png")
    cmd_guide_grid_height_level_up = cmd

    cmd = UI::Command.new("One Floor Down") {
      self.guide_grid_height_level("Down")
    }
    cmd.tooltip = "One Floor Down"
    cmd.small_icon = File.join(PATH_IMAGES, "guide_grid_level_dec-16.png")
    cmd.large_icon = File.join(PATH_IMAGES, "guide_grid_level_dec-24.png")
    cmd_guide_grid_height_level_down = cmd


   # Menus
    menu = UI.menu("Plugins").add_submenu(PLUGIN_NAME)
    menu.add_item(cmd_create_guide_grid)
    menu.add_item(cmd_guide_grid_subdiv_level_inc)
    menu.add_item(cmd_guide_grid_subdiv_level_dec)
    menu.add_item(cmd_guide_grid_height_level_up)
    menu.add_item(cmd_guide_grid_height_level_down)
    menu.add_separator
    menu.add_item(cmd_export_asset)

    # Toolbar
    toolbar = UI::Toolbar.new(PLUGIN_NAME)
    toolbar.add_item(cmd_create_guide_grid)
    toolbar.add_item(cmd_guide_grid_subdiv_level_inc)
    toolbar.add_item(cmd_guide_grid_subdiv_level_dec)
    toolbar.add_item(cmd_guide_grid_height_level_up)
    toolbar.add_item(cmd_guide_grid_height_level_down)
    toolbar.add_item(cmd_export_asset)
    toolbar.restore

    file_loaded(__FILE__)
  end


  # TT::Plugins::CitiesSkylinesTools.reload
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    ruby_files = File.join(PATH, '**/*.{rb,rbs}')
    x = Dir.glob(ruby_files).each { |file|
      load file
    }
    x.length
  ensure
    $VERBOSE = original_verbose
  end

end # module TT::Plugins::CitiesSkylinesTools
