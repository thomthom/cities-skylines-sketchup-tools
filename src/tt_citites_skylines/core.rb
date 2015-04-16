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

    cmd = UI::Command.new("Create Guide Grid") {
      self.create_guide_grid
    }
    cmd.tooltip = "Create Guide Grid"
    cmd.small_icon = File.join(PATH_IMAGES, "guide_grid-16.png")
    cmd.large_icon = File.join(PATH_IMAGES, "guide_grid-24.png")
    cmd_create_guide_grid = cmd

    # Menus

    menu = UI.menu("Plugins").add_submenu(PLUGIN_NAME)
    menu.add_item(cmd_create_guide_grid)
    menu.add_separator
    menu.add_item(cmd_export_asset)

    # Toolbar

    toolbar = UI::Toolbar.new(PLUGIN_NAME)
    toolbar.add_item(cmd_create_guide_grid)
    toolbar.add_item(cmd_export_asset)
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
