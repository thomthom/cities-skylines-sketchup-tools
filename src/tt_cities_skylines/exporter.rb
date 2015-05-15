#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  class ValidationError < StandardError; end
  class ExportError < StandardError; end


  require "tt_cities_skylines/exporters/fbx.rb"
  require "tt_cities_skylines/exporters/dae.rb"


  def self.export_asset
    # Validate the model before exporting.
    triangle_count = self.validate_model_for_export
    # Find the destination for the asset.
    default_path = self.find_asset_path
    if Sketchup.platform == :platform_win
      file_filter = "FBX File (*.fbx)|*.fbx|COLLADA File (*.dae)|*.dae||"
    else
      # There appear to be a bug in the OSX version, at least with 10.10 where
      # the dialog fails to open if the third argument is set.
      file_filter = nil
    end
    # TODO: Probably be good to remember the last used filetype.
    target = UI.savepanel("Export Asset", default_path, file_filter)
    return false if target.nil?
    # Export the asset.
    extension = File.extname(target.downcase)
    case extension
    when ".fbx"
      if Sketchup.is_pro?
        self.export_fbx_asset(target)
      else
        raise ExportError, "FBX export is a SketchUp Pro feature"
      end
    when ".dae"
      self.export_asset_dae(target)
    else
      raise ExportError, "Unsupported file extension (#{extension})"
    end
    puts "Exported #{triangle_count} triangles to #{target}"
    true
  rescue ValidationError => error
    # Known possible failures is presented via messageboxes.
    message = "Cannot export asset.\n\n#{error.message}"
    UI.messagebox(message)
    false
  rescue ExportError => error
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


  def self.get_model_name(extension)
    model = Sketchup.active_model
    raise ExportError, "No model open for export" if model.nil?
    model.title.empty? ? "Untitled.#{extension}" : "#{model.title}.#{extension}"
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
    raise ValidationError, "All instances must be exploded" unless instances.empty?
    # Check there are faces to export.
    faces = model.entities.grep(Sketchup::Face)
    raise ValidationError, "No faces found to export" if faces.empty?
    # Check the faces only use one material.
    materials = faces.map { |face| face.material }
    materials.uniq!
    raise ValidationError, "Only one material can be used" if materials.size > 1
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
    access = Win32::Registry::KEY_ALL_ACCESS
    Win32::Registry::HKEY_CURRENT_USER.create(key_fbx_exporter, access) do |reg|
      settings.each { |key, value|
        dword = case value
        when Integer
          value
        when TrueClass, FalseClass
          value ? 1 : 0
        else
          raise "#{value.class} not supported"
        end
        reg.write(key, Win32::Registry::REG_DWORD, dword)
      }
    end
    nil
  end


  def self.osx_write_setting(section, key, value)
    version = "20#{Sketchup.version.to_i}"
    value_with_type = case value
    when Integer
      "-int #{value}"
    when TrueClass, FalseClass
      "-bool #{value}"
    else
      raise "#{value.class} not supported"
    end
    `defaults write com.sketchup.SketchUp.#{version} "#{section}" -dict-add "#{key}" #{value_with_type}`
  end


  def self.osx_write_settings(section, settings)
    raise TypeError, "Settings must be a Hash" unless settings.is_a?(Hash)
    settings.each { |key, value|
      self.osx_write_setting(section, key, value)
    }
    nil
  end

end # module TT::Plugins::CitiesSkylinesTools
