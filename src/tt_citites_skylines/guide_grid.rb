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

  def self.create_guide_grid
    # Promtp user for grid size/
    prompts = ["Grid Width:", "Grid Depth:"]
    default_cell_x = Sketchup.read_default(PLUGIN_ID, "GridCellsX", 4)
    default_cell_y = Sketchup.read_default(PLUGIN_ID, "GridCellsY", 4)
    defaults = [default_cell_x, default_cell_y]
    list = ["1|2|3|4|5|6|7|8", "1|2|3|4|5|6|7|8"]
    input = UI.inputbox(prompts, defaults, list, "Grid Dimensions")
    return false if input === false

    cells_x = input[0]
    cells_y = input[1]
    grid_lines_x = cells_x + 1
    grid_lines_y = cells_y + 1
    Sketchup.write_default(PLUGIN_ID, "GridCellsX", cells_x)
    Sketchup.write_default(PLUGIN_ID, "GridCellsY", cells_y)

    model = Sketchup.active_model
    model.start_operation("Guide Grid")
    group = model.entities.add_group
    # Tag this group so we can find it later.
    group.set_attribute(PLUGIN_ID, OBJECT_TYPE, TYPE_GUIDE_GRID)
    # Add guide points.
    grid_lines_x.times { |x|
      grid_lines_y.times { |y|
        group.entities.add_cpoint([x * SECTOR_SIZE, y * SECTOR_SIZE, 0])
      }
    }
    # Add guide lines.
    grid_lines_x.times { |x|
      grid_lines_y.times { |y|
        point1 = Geom::Point3d.new(x * SECTOR_SIZE, y * SECTOR_SIZE, 0)
        point2 = point1.offset(X_AXIS, SECTOR_SIZE)
        point3 = point1.offset(Y_AXIS, SECTOR_SIZE)
        group.entities.add_cline(point1, point2) unless x == cells_x
        group.entities.add_cline(point1, point3) unless y == cells_y
      }
    }
    # Center at origin.
    half_size_x = (SECTOR_SIZE * cells_x) / 2.0
    half_size_y = (SECTOR_SIZE * cells_y) / 2.0

    tr = Geom::Transformation.new([-half_size_x, -half_size_y, 0])
    group.transform!(tr)
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

end # module TT::Plugins::CitiesSkylinesTools
