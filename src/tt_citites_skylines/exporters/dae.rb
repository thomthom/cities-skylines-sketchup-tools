#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  def self.export_asset_dae
    # Find the destination for the asset.
    default_path = self.find_asset_path
    filename = self.get_model_dae_name
    if Sketchup.platform == :platform_win
      dae_filter = "COLLADA File (*.dae)|*.dae||"
    else
      # There appear to be a bug in the OSX version, at least with 10.10 where
      # the dialog fails to open if the third argument is set.
      dae_filter = nil
    end
    target = UI.savepanel("Export DAE Asset", default_path, dae_filter)
    return false if target.nil?
    # Validate the model before exporting.
    triangle_count = self.validate_model_for_export
    # Export the intermediate DAE file.
    self.set_dae_exporter_settings
    source = self.select_entities_for_export {
      self.export_dae(target)
    }
    # Try to patch the file so it can be loaded by the game.
    #begin
    #  self.patch_dae_file(source, target)
    #ensure
    #  File.delete(source)
    #end
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

  def self.get_model_dae_name
    model = Sketchup.active_model
    raise ExportError, "No model open for export" if model.nil?
    model.title.empty? ? "Untitled.dae" : "#{model.title}.dae"
  end

  def self.set_dae_exporter_settings
    # Since the model.export method only have export arguments for COLLADA files
    # and not for any of the other exporters this has to be manually configured
    # for each system.
    settings = {
     "ExportAuthorAttribution"          => "NO",
      "ExportDoublePrecision"           => "NO",
      "ExportTextureMaps"               => "YES",
      "ExportDoubleSidedFaces"          => "NO",
      "ExportTriangulatedFaces"         => "YES",
      "ExportEdges"                     => "NO",
      "ExportVertexNormals"             => "Yes",
      "ExportCameraLookat"              => "NO",
      "ExportPreserveHierarchies"       => "NO",
      "ExportHiddenGeometry"            => "NO",
      "ExportSelectionSetOnly"          => "YES"
    }
    if Sketchup.platform == :platform_win
      self.win32_write_settings("Dae Exporter", settings)
    else
      self.osx_write_settings("Dae Exporter", settings)
    end
    nil
  end

  def self.export_dae(target = nil)
    model = Sketchup.active_model
    zeroPoint = Geom::Point3d.new
    v1 = Geom::Vector3d.new 0,1,0
    # Rotate and Scale
    t_scale = Geom::Transformation.scaling(zeroPoint, 2.54) # 3D
    v2 = Geom::Vector3d.new 0,0,-1
    angle = v1.angle_between(v2)
    ts = 1.0 / t_scale.to_a[15]
    ta = t_scale.to_a.collect { |d| d * ts }
    t_scale = Geom::Transformation.new(ta)
    v3 = v1 * v2
    t_rotation = Geom::Transformation.rotation(zeroPoint, v3, angle)
    t = t_rotation * t_scale
    model.active_entities.transform_entities(t, model.selection)
    # Export
    model.export(target)
    # Reset
    t_scale = Geom::Transformation.scaling(zeroPoint, 1/2.54) # 3D
    v2 = Geom::Vector3d.new 0,0,1
    angle = v1.angle_between(v2)
    ts = 1.0 / t_scale.to_a[15]
    ta = t_scale.to_a.collect { |d| d * ts }
    t_scale = Geom::Transformation.new(ta)
    v3 = v1 * v2
    t_rotation = Geom::Transformation.rotation(zeroPoint, v3, angle)
    t = t_rotation * t_scale
    model.active_entities.transform_entities(t, model.selection)
  end

end # module TT::Plugins::CitiesSkylinesTools
