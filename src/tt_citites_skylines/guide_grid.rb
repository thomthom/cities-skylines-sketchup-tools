#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::CitiesSkylinesTools

  SECTOR_SIZE = 8.m
  GRID_CELLS = 5
  GRID_LINES = GRID_CELLS + 1

  OBJECT_TYPE = "ObjectType".freeze
  TYPE_GUIDE_GRID = "GuideGrid".freeze

  def self.create_guide_grid
    model = Sketchup.active_model
    model.start_operation("Guide Grid")
    group = model.entities.add_group
    # Tag this group so we can find it later.
    group.set_attribute(PLUGIN_ID, OBJECT_TYPE, TYPE_GUIDE_GRID)
    # Add guide points.
    GRID_LINES.times { |x|
      GRID_LINES.times { |y|
        group.entities.add_cpoint([x * SECTOR_SIZE, y * SECTOR_SIZE, 0])
      }
    }
    # Add guide lines.
    GRID_LINES.times { |x|
      GRID_LINES.times { |y|
        point1 = Geom::Point3d.new(x * SECTOR_SIZE, y * SECTOR_SIZE, 0)
        point2 = point1.offset(X_AXIS, SECTOR_SIZE)
        point3 = point1.offset(Y_AXIS, SECTOR_SIZE)
        group.entities.add_cline(point1, point2) unless x == GRID_CELLS
        group.entities.add_cline(point1, point3) unless y == GRID_CELLS
      }
    }
    # Center at origin.
    half_size = (SECTOR_SIZE * GRID_CELLS) / 2.0
    tr = Geom::Transformation.new([-half_size, -half_size, 0])
    group.transform!(tr)
    # Prevent it from easily being moved.
    group.locked = true
    model.commit_operation
    # Ensure the grid is visible.
    model.rendering_options["HideConstructionGeometry"] = false
  rescue Exception => error
    model.abort_operation
    ERROR_REPORTER.handle(error)
  end

end # module TT::Plugins::CitiesSkylinesTools
