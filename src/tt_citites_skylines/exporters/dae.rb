#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  # @note This should probably be wrapper up in a class interface.
  #
  # @param [String] target Destination FBX filename.
  def self.export_asset_dae(target)
    self.select_entities_for_export {
      self.export_dae(target)
    }
    nil
  end

  def self.get_model_dae_name
    self.get_model_name("dae")
  end

  def self.export_dae(target = nil)
    options = {
      :author_attribution   => false,
      :texture_maps         => true,
      :doublesided_faces    => false,
      :triangulated_faces   => true,
      :edges                => false,
      :preserve_instancing  => false,
      :selectionset_only    => true
    }

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
    model.export(target, options)
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
