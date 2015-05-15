#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  class PatchError < ExportError; end


  # Binary FBX file signature.
  BINARY_SIGNATURE = "Kaydara FBX Binary  ".freeze

  # @note This should probably be wrapper up in a class interface.
  #
  # @param [String] target Destination FBX filename.
  def self.export_fbx_asset(target)
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
    nil
  end


  def self.get_model_fbx_name
    self.get_model_name("fbx")
  end


  def self.set_fbx_exporter_settings
    # Since the model.export method only have export arguments for COLLADA files
    # and not for any of the other exporters this has to be manually configured
    # for each system.
    settings = {
      "ExportDoubleSidedFaces"           => false,
      "ExportSelectionSetOnly"           => true,
      "ExportSeparateDisconnectedFaces"  => false,
      "ExportTextureMaps"                => false,
      "ExportTriangulatedFaces"          => true,
      "ExportUnits"                      => 6,
      "SwapYZ"                           => true
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
