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

    tr_scale = Geom::Transformation.scaling(ORIGIN, 2.54)
    tr_axes = Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS, Y_AXIS)
    tr = tr_axes * tr_scale

    model = Sketchup.active_model
    model.start_operation("COLLADA Export", true)
    model.active_entities.transform_entities(tr, model.entities.to_a)
    model.export(target, options)
    model.abort_operation
  end

end # module TT::Plugins::CitiesSkylinesTools
