#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  def self.write_settings(section, settings)
    # SketchUp 2018 store preferences in JSON files. It also expose options
    # for all importers/exporters.
    return false if Sketchup.version.to_i >= 18
    if Sketchup.platform == :platform_win
      self.win32_write_settings("Fbx Exporter", settings)
    else
      self.osx_write_settings("Fbx Exporter", settings)
    end
    true
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
