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
    default_path = self.find_asset_path
    filename = self.get_model_fbx_name
    if Sketchup.platform == :platform_win
      fbx_filter = "FBX File (*.fbx)|*.fbx||"
    else
      # There appear to be a bug in the OSX version, at least with 10.10 where
      # the dialog fails to open if the third argument is set.
      fbx_filter = nil
    end
    target = UI.savepanel("Export FBX Asset", default_path, fbx_filter)
    return false if target.nil?
    # Validate the model before exporting.
    triangle_count = self.validate_model_for_export
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
    puts "Exported #{triangle_count} triangles to #{target}"
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


  def self.win32_find_asset_path
    local_app_data = ENV["LOCALAPPDATA"]
    return nil if local_app_data.nil?
    local_app_data = File.expand_path(local_app_data)
    game_app_data = File.join(local_app_data, "Colossal Order", "Cities_Skylines")
    asset_path = File.join(game_app_data, "Addons", "Import")
    asset_path
  end


  def self.osx_find_asset_path
    home = ENV["HOME"]
    return nil if home.nil?
    app_support = File.join(home, "Library", "Application Support")
    game_data = File.join(app_support, "Colossal Order", "Cities_Skylines")
    asset_path = File.join(game_data, "Addons", "Import")
    asset_path
  end


  def self.find_asset_path
    if Sketchup.platform == :platform_win
      self.win32_find_asset_path
    else
      self.osx_find_asset_path
    end
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
    # Collect triangle count.
    triangles = 0
    faces.each { |face| triangles += face.mesh.count_polygons }
    triangles
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


  def self.win32_write_settings(section, settings)
    require "win32/registry"
    key_sketchup = "Software\\SketchUp\\SketchUp 20#{Sketchup.version.to_i}"
    key_fbx_exporter = "#{key_sketchup}\\#{section}"
    type = Win32::Registry::REG_DWORD
    access = Win32::Registry::KEY_ALL_ACCESS
    Win32::Registry::HKEY_CURRENT_USER.open(key_fbx_exporter, access) do |reg|
      settings.each { |key, value|
        reg.write(key, type, value)
      }
    end
    nil
  end


  def self.osx_write_setting(section, key, value)
    version = "20#{Sketchup.version.to_i}"
    `defaults write com.sketchup.SketchUp.#{version} "#{section}" -dict-add "#{key}" #{value}`
  end


  def self.osx_write_settings(section, settings)
    raise TypeError, "Settings must be a Hash" unless settings.is_a?(Hash)
    settings.each { |key, value|
      reg.write(section, type, value)
    }
    nil
  end


  def self.set_fbx_exporter_settings
    # Since the model.export method only have export arguments for COLLADA files
    # and not for any of the other exporters this has to be manually configured
    # for each system.
    settings = {
     "ExportDoubleSidedFaces"            => 0,
      "ExportSelectionSetOnly"           => 1,
      "ExportSeparateDisconnectedFaces"  => 0,
      "ExportTextureMaps"                => 0,
      "ExportTriangulatedFaces"          => 1,
      "ExportUnits"                      => 6,
      "SwapYZ"                           => 1
    }
    if Sketchup.platform == :platform_win
      self.win32_write_settings("Fbx Exporter", settings)
    else
      self.osx_write_settings("Fbx Exporter", settings)
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


  def self.verify_object_type_count(fbx_data, type, count)
    objects_filter = /ObjectType:\s+"Model"\s+{\s+Count:\s+(\d+)/
    result = fbx_data.match(objects_filter)
    raise PatchError, "Unable to locate Model count" if result.nil?
    objects = result[1].to_i
    if objects > 2
      raise PatchError, "Unexpected number of #{type} objects "\
          "(#{objects} instead of #{count})"
    end
    nil
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

    # Validate some of the assumptions being made.
    self.verify_object_type_count(fbx_data, "Model", 2)
    self.verify_object_type_count(fbx_data, "Geometry", 1)
    self.verify_object_type_count(fbx_data, "Material", 1)

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

    nil
  end

end # module TT::Plugins::CitiesSkylinesTools
