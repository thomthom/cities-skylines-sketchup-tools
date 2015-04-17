#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  class ExportError < StandardError; end
  class PatchError < ExportError; end


  # Binary FBX file signature.
  BINARY_SIGNATURE = "Kaydara FBX Binary  ".freeze


  def self.export_asset
    # Find the destination for the asset.
    target_path = self.find_asset_path
    filename = self.get_model_fbx_name
    target = File.join(target_path, filename)
    # Validate the model before exporting.
    self.validate_model_for_export
    # Make sure to prompt to overwrite existing files.
    if File.exist?(target)
      message = "#{filename} already exist. Would you like to overwrite?"
      result = UI.messagebox(message, MB_YESNO)
      return false if result == IDNO
      # TODO: Add Cancel - where No then allows user to provide new filename.
    end
    # Export the intermediate FBX file.
    self.set_fbx_exporter_settings
    source = self.select_entities_for_export {
      self.export_temp_fbx
    }
    # Try to patch the file so it can be loaded by the game.
    begin
      self.patch_fbx_file(source, target)
    ensure
      File.delete(source)
    end
    true
  rescue ExportError => error
    # Known possible failures is presented via messageboxes.
    message = "Failed to export asset.\n\n#{error.message}"
    UI.messagebox(message)
    false
  rescue Exception => error
    # Everything else is passed on to the Error Reporter.
    ERROR_REPORTER.handle(error)
  end


  def self.find_asset_path
    local_app_data = ENV["LOCALAPPDATA"]
    raise "Unable to find Local AppData" if local_app_data.nil?
    # Get the asset folder for the game.
    local_app_data = File.expand_path(local_app_data)
    game_app_data = File.join(local_app_data, "Colossal Order", "Cities_Skylines")
    asset_path = File.join(game_app_data, "Addons", "Import")
    # Make sure the destination exist.
    unless File.exist?(asset_path)
      raise ExportError, "Asset folder not found: #{asset_path}"
    end
    # Everything ok.
    asset_path
  end


  def self.get_model_fbx_name
    model = Sketchup.active_model
    raise ExportError, "No model open for export" if model.nil?
    model.title.empty? ? "Untitled.fbx" : "#{model.title}.fbx"
  end


  def self.validate_model_for_export
    model = Sketchup.active_model
    # Check for instances - ignoring the guide grids.
    instances = model.entities.select { |entity|
      (
        entity.is_a?(Sketchup::Group) ||
        entity.is_a?(Sketchup::ComponentInstance) ||
        entity.is_a?(Sketchup::Image)
      ) && entity.get_attribute(PLUGIN_ID, OBJECT_TYPE).nil?
    }
    raise ExportError, "All instances must be exploded" unless instances.empty?
    # Check there are faces to export.
    faces = model.entities.grep(Sketchup::Face)
    raise ExportError, "No faces found to export" if faces.empty?
    # Check the faces only use one material.
    materials = faces.map { |face| face.material }
    materials.uniq!
    raise ExportError, "Only one material can be used" if materials.size > 1
    nil
  end


  def self.select_entities_for_export
    model = Sketchup.active_model
    original_selection = model.selection.to_a
    faces = model.entities.grep(Sketchup::Face)
    begin
      model.selection.clear
      model.selection.add(faces)
      yield
    ensure
      model.selection.clear
      model.selection.add(original_selection)
    end
  end


  def self.set_fbx_exporter_settings
    # Since the model.export method only have export arguments for COLLADA files
    # and not for any of the other exporters this has to be manually configured
    # for each system.
    if Sketchup.platform == :platform_win
      require "win32/registry"
      key_sketchup = "Software\\SketchUp\\SketchUp 20#{Sketchup.version.to_i}"
      key_fbx_exporter = "#{key_sketchup}\\Fbx Exporter"
      type = Win32::Registry::REG_DWORD
      access = Win32::Registry::KEY_ALL_ACCESS
      Win32::Registry::HKEY_CURRENT_USER.open(key_fbx_exporter, access) do |reg|
        #reg.each_value { |name, type, data| puts "#{name} : #{data}" }
        reg.write("ExportDoubleSidedFaces",           type, 0)
        reg.write("ExportSelectionSetOnly",           type, 1)
        reg.write("ExportSeparateDisconnectedFaces",  type, 0)
        reg.write("ExportTextureMaps",                type, 0)
        reg.write("ExportTriangulatedFaces",          type, 1)
        reg.write("ExportUnits",                      type, 6)
        reg.write("SwapYZ",                           type, 1)
      end
    else
      # TODO
    end
    nil
  end


  def self.export_temp_fbx
    rand_number = Time.now.to_i
    temp_fbx_file = "tt_citites_#{rand_number}.fbx"
    model = Sketchup.active_model
    model.export(temp_fbx_file)
    temp_fbx_file
  end


  def self.patch_fbx_file(source, target)
    # Get the asset folder for the game.
    local_app_data = ENV["LOCALAPPDATA"]
    raise "Unable to find Local AppData" if local_app_data.nil?

    local_app_data = File.expand_path(local_app_data)
    game_app_data = File.join(local_app_data, "Colossal Order", "Cities_Skylines")
    asset_path = File.join(game_app_data, "Addons", "Import")

    unless File.exist?(asset_path)
      raise "Asset folder not found"
    end

    # Read the FBX data. Make sure to read as ASCII to avoid errors in case it's
    # a binary file.
    fbx_data = File.read(source, encoding: "ASCII-8BIT")
    if fbx_data.start_with?(BINARY_SIGNATURE)
      raise PatchError, "Unexpected FBX in binary format"
    end

    # Extract the Connections sections. This isn't strictly needed, but it just
    # narrows the search scope for our other searches.
    connections_filter = /Connections:\s*{(.+?)}\s*;/m
    result = fbx_data.match(connections_filter)
    raise PatchError, "Unable to locate Connections data" if result.nil?
    relations_data = result[0]

    # Extract the root node ID. This is needed to assign it to the Geometry
    # later on. The node name in the comment is also collected so we can clean
    # that up as well. That's not necessary to make it work, but makes the model
    # easier to read upon manual inspection.
    root_node_filter = /;Model::\w+, Model::RootNode\s*C:\s+"OO",(\d+),0/m
    result = relations_data.match(root_node_filter)
    raise PatchError, "Unable to find RootNode ID" if result.nil?
    root_node_id = result[1]

    # Remove the unwanted extra node. It's only removed from the connections,
    # not from the entire file completely. This leaves it orphan, but reduce
    # changes made to the model. Want to keep things simple when monkey-patching
    # like this.
    redundant_node = /;Model::Mesh1, Model::Model\s*C:\s+"OO",\d+,\d+$\s*;/
    fbx_data.gsub!(redundant_node, ";")

    # Rewire the parent for the geometry to be the RootNode.
    geometry_node = /(;Geometry::, Model::)(\w+)(\s*C:\s+"OO",\d+,)(\d+)/
    fbx_data.gsub!(geometry_node, "\\1Model\\3#{root_node_id}")

    # Write the patched model to disk.
    File.write(target, fbx_data, encoding: "ASCII-8BIT")
    puts "Patched file written to: #{target}"

    nil
  end

end # module TT::Plugins::CitiesSkylinesTools
