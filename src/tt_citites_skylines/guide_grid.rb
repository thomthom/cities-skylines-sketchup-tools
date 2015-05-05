#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  SECTOR_SIZE = 8.m

  OBJECT_TYPE = "ObjectType".freeze
  TYPE_GUIDE_GRID = "GuideGrid".freeze

  GRID_CELLS_X = "GridCellsX".freeze
  GRID_CELLS_Y = "GridCellsY".freeze
  GRID_CELLS_SUBDIVS = "GridCellsSubDivs".freeze

  SUBDIVS_MIN = 0
  SUBDIVS_MAX = 4

  INCREASE =  1
  DECREASE = -1

  HEIGHT_GRID = "HeightGrid".freeze

  FLOORS = "Floors".freeze
  FIRST_FLOOR_HEIGHT = "FirstFloorHeight".freeze
  FLOOR_HEIGHT = "FloorHeight".freeze

  FLOORS_MIN = 0
  FLOORS_MAX = 999


  def self.create_guide_grid(group = nil, options = nil)
    puts "create_guide_grid"
    model = Sketchup.active_model

    # Get default values if no spesific options are given.
    options = self.grid_options(entity) if options.nil?
    p options

    cells_x             = options[:grid_x]
    cells_y             = options[:grid_y]
    cells_subdivs       = options[:grid_subdivs]
    height_grid         = options[:height_grid]
    floors              = options[:floors]
    first_floor_height  = options[:first_floor_height]
    floor_height        = options[:floor_height]

    model.start_operation("Guide Grid")

    # Create a new group if we're not editing an existing one.
    puts "Grid: #{group.inspect}"
    group ||= model.entities.add_group
    group.entities.clear! if group.entities.size > 0

    # Tag this group so we can find it later.
    group.set_attribute(PLUGIN_ID, OBJECT_TYPE, TYPE_GUIDE_GRID)
    group.set_attribute(PLUGIN_ID, GRID_CELLS_X, cells_x)
    group.set_attribute(PLUGIN_ID, GRID_CELLS_Y, cells_y)
    group.set_attribute(PLUGIN_ID, GRID_CELLS_SUBDIVS, cells_subdivs)
    group.set_attribute(PLUGIN_ID, HEIGHT_GRID, height_grid)
    group.set_attribute(PLUGIN_ID, FLOORS, floors)
    group.set_attribute(PLUGIN_ID, FIRST_FLOOR_HEIGHT, first_floor_height)
    group.set_attribute(PLUGIN_ID, FLOOR_HEIGHT, floor_height)

    grid_lines_x = cells_x + 1
    grid_lines_y = cells_y + 1

    if height_grid
      floor_planes = [floors + 1, 2].max
    else
      floor_planes = 1
    end

    # Add guide points.
    floor_planes.times { |f|
      grid_lines_x.times { |x|
        grid_lines_y.times { |y|
          z = (f > 0) ? (f - 1) * floor_height + first_floor_height : 0
          group.entities.add_cpoint([x * SECTOR_SIZE, y * SECTOR_SIZE, z])
        }
      }
      # Add guide lines.
      grid_lines_x.times { |x|
        grid_lines_y.times { |y|
          z = (f > 0) ? (f - 1) * floor_height + first_floor_height : 0
          point1 = Geom::Point3d.new(x * SECTOR_SIZE, y * SECTOR_SIZE, z)
          point2 = point1.offset(X_AXIS, SECTOR_SIZE)
          point3 = point1.offset(Y_AXIS, SECTOR_SIZE)
          group.entities.add_cline(point1, point2) unless x == cells_x
          group.entities.add_cline(point1, point3) unless y == cells_y
        }
      }
    }

    # Add Base SubDivisions
    cells_subdivs_x = cells_x
    cells_subdivs_y = cells_y
    cells_subdivs_step = SECTOR_SIZE
    # Get StepSize
    cells_subdivs.times { |i|
      cells_subdivs_step = cells_subdivs_step/2
      cells_subdivs_x = cells_subdivs_x * 2
      cells_subdivs_y = cells_subdivs_y * 2
    }
    cells_subdivs_x = cells_subdivs_x + 1
    cells_subdivs_y = cells_subdivs_y + 1
    # Create Points
    cells_subdivs_x.times { |x|
      cells_subdivs_y.times { |y|
        cx = x * cells_subdivs_step
        cy = y * cells_subdivs_step
        if height_grid == false || floor_planes < 0
          cz = 0
        else
          cz = (floor_planes - 2) * floor_height + first_floor_height
        end
        group.entities.add_cpoint([cx, cy, cz])
      }
    }

    # Center at origin.
    half_size_x = (SECTOR_SIZE * cells_x) / 2.0
    half_size_y = (SECTOR_SIZE * cells_y) / 2.0
    tr = Geom::Transformation.new([-half_size_x, -half_size_y, 0])
    group.transformation = tr
    # Prevent it from easily being moved.
    group.locked = true
    model.commit_operation
    # Ensure the grid is visible.
    model.rendering_options["HideConstructionGeometry"] = false
    true
  rescue Exception => error
    model.abort_operation
    ERROR_REPORTER.handle(error)
  end

  def self.find_grid
    return nil if Sketchup.active_model.nil?
    Sketchup.active_model.entities.find { |entity|
      object_type = entity.get_attribute(PLUGIN_ID, OBJECT_TYPE)
      object_type.is_a?(String) && object_type == TYPE_GUIDE_GRID
    }
  end

  def self.get_option(entity, key, default)
    # Reads the option value from the given entity, or fall back to defaults.
    value = nil
    if entity
      value = entity.get_attribute(PLUGIN_ID, key)
    end
    if value.nil?
      begin
        value = Sketchup.read_default(PLUGIN_ID, key, default)
      rescue SyntaxError
        # Hm... doesn't seem to be able to rescue this one...
        puts "Failed to read saved default for: #{key}"
        value = default
      end
      # Seems that SketchUp output SyntaxError without actually throwing
      # it - then returning nil. Account for that here.
      value = default if value.nil?
    end
    # Length's aren't saved properly in Sketchup.write_default. Make sure
    # the returned values is a Length is the default is one.
    if default.is_a?(Length)
      value = value.to_l
    end
    # If default value is a boolean, ensure the returned value also is a true
    # boolean.
    if default.is_a?(TrueClass) || default.is_a?(FalseClass)
      value = value ? true : false
    end
    value
  end

  def self.grid_options(entity)
    options = {
      :grid_x             => self.get_option(entity, GRID_CELLS_X, 4),
      :grid_y             => self.get_option(entity, GRID_CELLS_Y, 4),
      :grid_subdivs       => self.get_option(entity, GRID_CELLS_SUBDIVS, 3),
      :height_grid        => self.get_option(entity, HEIGHT_GRID, false),
      :floors             => self.get_option(entity, FLOORS, 5),
      :floor_height       => self.get_option(entity, FLOOR_HEIGHT, 5.m),
      :first_floor_height => self.get_option(entity, FIRST_FLOOR_HEIGHT, 4.5.m)
    }
    options
  end

  def self.save_option(key, value)
    Sketchup.write_default(PLUGIN_ID, key, value)
  end

  def self.save_last_used_options(options)
    self.save_option(GRID_CELLS_X,        options[:grid_x])
    self.save_option(GRID_CELLS_Y,        options[:grid_y])
    self.save_option(GRID_CELLS_SUBDIVS,  options[:grid_subdivs])
    self.save_option(HEIGHT_GRID,         options[:height_grid])
    self.save_option(FLOORS,              options[:floors])
    self.save_option(FIRST_FLOOR_HEIGHT,  options[:first_floor_height].to_f)
    self.save_option(FLOOR_HEIGHT,        options[:floor_height].to_f)
  end

  def self.grid_context_menu(context_menu)
    grid = self.find_grid
    return false if grid.nil?
    context_menu.add_item("Edit Grid") {
      self.guide_grid_config(grid)
    }
    true
  end

  def self.bool_to_string(bool)
    bool ? "Yes" : "No"
  end

  def self.string_to_bool(string)
    string == "No" ? false : true
  end

  # Grid Configuration Window
  #
  # @param [Sketchup::Group, Sketchup::ComponentInstance] entity
  def self.guide_grid_config(entity)
    options = self.grid_options(entity)
    defaults = [
      options[:grid_x],
      options[:grid_y],
      options[:grid_subdivs],
      self.bool_to_string(options[:height_grid]),
      options[:floors],
      options[:first_floor_height],
      options[:floor_height]
    ]
    prompts = [
      "Grid Width:",
      "Grid Depth:" ,
      "Subdivisions:",
      "Height Grid:",
      "Floors:",
      "First Height:",
      "Other Height:"
    ]
    list = [
      "1|2|3|4|5|6|7|8",
      "1|2|3|4|5|6|7|8" ,
      "0|1|2|3",
      "No|Yes",
      "",
      "",
      ""
    ]
    input = UI.inputbox(prompts, defaults, list, "Guide Grid Config")
    return false unless input

    new_options = {
      :grid_x             => input[0],
      :grid_y             => input[1],
      :grid_subdivs       => input[2],
      :height_grid        => self.string_to_bool(input[3]),
      :floors             => input[4],
      :first_floor_height => input[5],
      :floor_height       => input[6]
    }

    self.save_last_used_options(new_options)
    self.create_guide_grid(entity, new_options)
    true
  end

  def self.guide_grid_subdiv_level(adjustment)
    grid = self.find_grid
    options = self.grid_options(grid)

    subdivs = options[:grid_subdivs] + adjustment
    subdivs = [subdivs, SUBDIVS_MIN].max
    subdivs = [subdivs, SUBDIVS_MAX].min
    options[:grid_subdivs] = subdivs

    self.save_last_used_options(options)
    self.create_guide_grid(grid, options)
  end

  def self.guide_grid_height_level(adjustment)
    grid = self.find_grid
    options = self.grid_options(grid)

    floors = options[:floors] + adjustment
    floors = [floors, FLOORS_MIN].max
    floors = [floors, FLOORS_MAX].min
    options[:floors] = floors

    self.save_last_used_options(options)
    self.create_guide_grid(grid, options)
  end

  unless file_loaded?(__FILE__)
    UI.add_context_menu_handler { |context_menu|
      self.grid_context_menu(context_menu)
    }
    file_loaded(__FILE__)
  end

end # module TT::Plugins::CitiesSkylinesTools
