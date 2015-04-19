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

  HEIGHT_GRID = "HeightGrid".freeze
  FLOORS = "Floors".freeze
  FLOOR_HEIGHT = "FloorHeight".freeze
  
  
  def self.create_guide_grid(grid_x = nil, grid_y = nil, grid_subdivs = nil, height_grid = nil, floors = nil, floor_height = nil, group = nil)
    
    # Prompt user for grid size/
    prompts = ["Grid Width:", "Grid Depth:" , "Subdivisions:", "Height Grid:", "Floors:", "Floor Height:"]
    default_cell_x = Sketchup.read_default(PLUGIN_ID, GRID_CELLS_X, 4)
    default_cell_y = Sketchup.read_default(PLUGIN_ID, GRID_CELLS_Y, 4)
    default_cell_subdivs = Sketchup.read_default(PLUGIN_ID, GRID_CELLS_SUBDIVS, 1)
    default_height_grid = Sketchup.read_default(PLUGIN_ID, HEIGHT_GRID, "Yes")
    default_floors = Sketchup.read_default(PLUGIN_ID, FLOORS, 5)
    default_floor_height = Sketchup.read_default(PLUGIN_ID, FLOOR_HEIGHT, 2.9)

    defaults = [default_cell_x, default_cell_y, default_cell_subdivs, default_height_grid, default_floors, default_floor_height]
    list = ["1|2|3|4|5|6|7|8", "1|2|3|4|5|6|7|8" , "0|1|2|3", "No|Yes", "", ""]
    input = UI.inputbox(prompts, defaults, list, "Grid Dimensions")
    return false if input === false
    
    # Set Vars
    cells_x = input[0]
    cells_y = input[1]
    cells_subdivs = input[2]
    height_grid = input[3]
    floors = input[4]
    floor_height = input[5]
    
    grid_lines_x = cells_x + 1
    grid_lines_y = cells_y + 1
    
    # Rewrite Sketchup Defaults
    Sketchup.write_default(PLUGIN_ID, GRID_CELLS_X, cells_x)
    Sketchup.write_default(PLUGIN_ID, GRID_CELLS_Y, cells_y)
    Sketchup.write_default(PLUGIN_ID, GRID_CELLS_SUBDIVS, cells_subdivs)
    Sketchup.write_default(PLUGIN_ID, HEIGHT_GRID, height_grid)
    Sketchup.write_default(PLUGIN_ID, FLOORS, floors)
    Sketchup.write_default(PLUGIN_ID, FLOOR_HEIGHT, floor_height)
    
    model = Sketchup.active_model
    model.start_operation("Guide Grid")
    group ||= model.entities.add_group
    group.entities.clear! if group.entities.size > 0
    # Tag this group so we can find it later.
    group.set_attribute(PLUGIN_ID, OBJECT_TYPE, TYPE_GUIDE_GRID)
    group.set_attribute(PLUGIN_ID, GRID_CELLS_X, cells_x)
    group.set_attribute(PLUGIN_ID, GRID_CELLS_Y, cells_y)
    group.set_attribute(PLUGIN_ID, GRID_CELLS_SUBDIVS, cells_subdivs)
    group.set_attribute(PLUGIN_ID, HEIGHT_GRID, height_grid)
    group.set_attribute(PLUGIN_ID, FLOORS, floors)
    group.set_attribute(PLUGIN_ID, FLOOR_HEIGHT, floor_height)
    floors = 1 unless height_grid == "Yes"
    floors = floors + 1 if height_grid == "Yes"
    # Add guide points.

    floors.times { |i|
      grid_lines_x.times { |x|
        grid_lines_y.times { |y|
          group.entities.add_cpoint([x * SECTOR_SIZE, y * SECTOR_SIZE, i * floor_height.m ])
        }
      }
      # Add guide lines.
      grid_lines_x.times { |x|
        grid_lines_y.times { |y|
          point1 = Geom::Point3d.new(x * SECTOR_SIZE, y * SECTOR_SIZE, i * floor_height.m )
          point2 = point1.offset(X_AXIS, SECTOR_SIZE)
          point3 = point1.offset(Y_AXIS, SECTOR_SIZE)
          group.entities.add_cline(point1, point2) unless x == cells_x
          group.entities.add_cline(point1, point3) unless y == cells_y
        }
      }
    }
    
    # Add SubDivisions
    cells_subdivs_x = cells_x
    cells_subdivs_y = cells_y
    cells_subdivs_step = SECTOR_SIZE
    cells_subdivs.times { |i|
      cells_subdivs_step = cells_subdivs_step/2
      cells_subdivs_x = cells_subdivs_x * 2
      cells_subdivs_y = cells_subdivs_y * 2
    }
    cells_subdivs_x = cells_subdivs_x + 1
    cells_subdivs_y = cells_subdivs_y + 1
    cells_subdivs_x.times { |x|
      cells_subdivs_y.times { |y|
        group.entities.add_cpoint([x * cells_subdivs_step, y * cells_subdivs_step, 0 ])
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

  def self.grid_context_menu(context_menu)
    model = Sketchup.active_model
    return false unless model.selection.size == 1
    entity = model.selection[0]
    object_type = entity.get_attribute(PLUGIN_ID, OBJECT_TYPE)
    return false unless object_type.is_a?(String)
    return false unless object_type == TYPE_GUIDE_GRID
    grid_x = entity.get_attribute(PLUGIN_ID, GRID_CELLS_X)
    grid_y = entity.get_attribute(PLUGIN_ID, GRID_CELLS_Y)
    grid_subdivs = entity.get_attribute(PLUGIN_ID, GRID_CELLS_SUBDIVS)
    height_grid = entity.get_attribute(PLUGIN_ID, HEIGHT_GRID)
    floors = entity.get_attribute(PLUGIN_ID, FLOORS)
    floor_height = entity.get_attribute(PLUGIN_ID, FLOOR_HEIGHT)
    return false if grid_x.nil? || grid_y.nil? || grid_subdivs.nil?
    context_menu.add_item("Edit Grid") {
      self.create_guide_grid(grid_x, grid_y, grid_subdivs, height_grid, floors, floor_height, entity)
    }
    true
  end


  unless file_loaded?(__FILE__)
    UI.add_context_menu_handler { |context_menu|
      self.grid_context_menu(context_menu)
    }
    file_loaded(__FILE__)
  end

end # module TT::Plugins::CitiesSkylinesTools
