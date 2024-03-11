# scripts with functions
source('2_process/src/process_data.R')

# targets list
p2_targets_list <- list(
  # ============================================================================
  # prep the spatial geometries
  # ============================================================================
  # do a spatial transformation 
  tar_target(
    p2_source_transformed, 
    p1_source |>
      sf::st_transform(5070) # albers equal area
  ),
  
  tar_target(
    p2_target_transformed, 
    p1_target |>
      sf::st_transform(5070) # albers equal area
  ),
  
  tar_target(
    p2_aoi_transformed, 
    p1_aoi |>
      sf::st_transform(5070) # albers equal area
  ), 
  
  # subset to AOI
  tar_target(
    p2_source_intersected, 
    sf::st_intersection(p2_source_transformed, p2_aoi_transformed)
  ),
  
  tar_target(
    p2_target_intersected, 
    sf::st_intersection(p2_target_transformed, p2_aoi_transformed)
  ),
  
  # clean geometry types
  # sometimes, the WBD has geometries that are not polygons or multipolygons, this pipeline will not know what to do with those
  tar_target(
    p2_target_cleaned, 
    clean_geometry_type(p2_target_intersected)
  ),
  
  # ============================================================================
  # check if there are duplicate IDs 
  # ============================================================================
  # if there are duplicate IDs in source, proceed anyway
  tar_target(
    p2_source,
    {
      is_unique <- nrow(p2_source_intersected) == length(unique(p2_source_intersected$featureid))
      if(!is_unique){
        warning("There are duplicate IDs in source geometry. First, you  need to handle these cases: either deduplicate or make a unique ID. The pipeline will run, but be ware that at these duplicated geometries attributes are unreliable because implicit assumptions are made when aggregating values.")
      }
      p2_source_intersected
    }
  ), 
  
  # if there are duplicate IDs in target, deduplicate
  # sometimes, the WBD will have a geometry with a small dangling pixel that creates self-intersecting polygons and the dataframe will have a duplicated ID associated with each polygon. 
  tar_target(
    p2_target,
    {
      is_unique <- nrow(p2_target_cleaned) == length(unique(p2_target_cleaned$huc12))
      if(!is_unique){
        warning("There are duplicate IDs in target geometry. I will deduplicate these for you, but make sure that is what you want!")
        p2_target_ready <- dedup(p2_target_cleaned, "huc12")
      } else {
        p2_target_ready <- p2_target_cleaned 
      }
      p2_target_ready
    }
  ), 
  
  # ============================================================================
  # weights matrix
  # ============================================================================
  # build the matrix
  tar_target(
    p2_weights, 
    ncdfgeom::calculate_area_intersection_weights(
      p2_source[, c("featureid", "geom")],  
      p2_target[, c("huc12", "shape")], 
      # normalize will ensure weights are calculate with intersection area divided by *target* geometry areas
      normalize = TRUE 
    )
  ), 
  
  # write it out for convenience, but we won't be needing this target anymore
  tar_target(
    p2_weights_write, 
    {
      fileout <- "2_process/out/source_target_weights.csv"
      write_csv(p2_weights, fileout)
      fileout
    }, 
    format = "file"
  ), 
  
  # ============================================================================
  # add area to weights 
  # ============================================================================
  # calculate source areas
  tar_target(
    p2_areas_x, 
    tibble(
      featureid = p2_source$featureid,
      featureid_areasqkm = as.numeric(
        units::set_units(
          sf::st_area(p2_source), 
          "km^2"
        )
      )
    )
  ), 
  
  # calculate target areas
  tar_target(
    p2_areas_y, 
    tibble(
      huc12 = p2_target$huc12,
      huc12_areasqkm = as.numeric(
        units::set_units(
          sf::st_area(p2_target), 
          "km^2"
        )
      )
    )
  ), 
  
  # add them to weights matrix
  tar_target(
    p2_weights_plus,
    left_join(p2_weights, p2_areas_x, by = join_by(featureid)) |>
      left_join(p2_areas_y, by = join_by(huc12)) |>
      mutate(intersection_areasqkm = huc12_areasqkm * w)
  ), 

  # ============================================================================
  # pull attributes and process
  # ============================================================================
  # read in your attributes table
  # in this example, we will pull attributes for NHDPlusV2 catchments using some handy functions and reformat it
  tar_target(
    p2_att_raw, 
    nhdplusTools::get_catchment_characteristics(
      varname = p1_vars,
      ids = unique(p2_weights_plus$featureid)), 
    pattern = map(p1_vars)
  ), 

  # format (_wider) for the join with weights
  tar_target(
    p2_att_wide, 
    p2_att_raw |>
      select(-percent_nodata) |>
      pivot_wider(
        names_from = characteristic_id,
        values_from = characteristic_value
      )
  ), 

  # join in with weights matrix
  tar_target(
    p2_att_joined, 
    left_join(
      p2_att_wide, 
      p2_weights_plus, 
      by = join_by(comid == featureid), 
      relationship = "one-to-many" 
    )
  ),

  # format (_longer) for the multiplication by weights
  tar_target(
    p2_att_long, 
    p2_att_joined |>
      pivot_longer(
        cols = all_of(p1_vars),
        names_to = "characteristic_id",
        values_to = "characteristic_value"
      ) |>
      na.omit()
  ), 
  
  # ============================================================================
  # rescale attributes 
  # ============================================================================
  # let's rescale with a area weighted mean
  tar_target(
    p2_rescaled, 
    p2_att_long |>
      group_by(huc12, characteristic_id) |>
      summarize(
        rescaled_value = weighted.mean(
          x = characteristic_value, 
          w = intersection_areasqkm, 
          na.rm = TRUE), 
        .groups = 'drop'
      ) |>
      arrange(characteristic_id)
  ), 
  
  # reformat the results as wide format
  tar_target(
    p2_rescaled_wide, 
    p2_rescaled |>
    pivot_wider(
      names_from = characteristic_id, 
      values_from = rescaled_value
    )
  ), 
  
  # ============================== OUTPUTS =====================================
  tar_target(
    p2_rescaled_write,
    {
      file_out <- "2_process/out/rescaled_attributes.csv"
      write_csv(p2_rescaled_wide, file_out)
      file_out
    }, 
    format = "file"
  )
  # ============================================================================
)
