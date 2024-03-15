# Scripts with functions
source('2_process/src/process_data.R')

# Targets list
p2_targets_list <- list(
  # ============================================================================
  # Prep the spatial geometries
  # ============================================================================
  # Pick your projection: albers equal area is generally good for CONUS
  tar_target(
    p2_proj, 
    5070                                                     
  ), 
  
  # Do a spatial transformation 
  tar_target(
    p2_source_transformed, 
    sf::st_transform(p1_source, p2_proj)       
  ),
  
  tar_target(
    p2_target_transformed, 
    sf::st_transform(p1_target, p2_proj) 
  ),
  
  tar_target(
    p2_aoi_transformed, 
    sf::st_transform(p1_aoi, p2_proj) 
  ), 
  
  # Subset to AOI
  tar_target(
    p2_source_intersected, 
    sf::st_intersection(p2_source_transformed, p2_aoi_transformed)
  ),
  
  tar_target(
    p2_target_intersected, 
    sf::st_intersection(p2_target_transformed, p2_aoi_transformed)
  ),
  
  # Clean geometry types
  # Sometimes, the WBD has geometries that are not polygons or multipolygons.
  # This pipeline will not know what to do with those.
  tar_target(
    p2_target_cleaned, 
    clean_geometry_type(p2_target_intersected)
  ),
  
  # ============================================================================
  # Check if there are duplicate IDs 
  # ============================================================================
  # If there are duplicate IDs in source, proceed anyway
  tar_target(
    p2_source,
    check_no_dup_ids(
      sf = p2_source_intersected,
      id_name = p1_source_id_name
    )
  ),
  
  # If there are duplicate IDs in target, de-duplicate
  # sometimes, the WBD will have a geometry with a small dangling pixel that 
  # creates self-intersecting polygons and the dataframe will have a duplicated 
  # ID associated with each polygon.
  tar_target(
    p2_target,
    ensure_no_dup_ids(
      sf = p2_target_cleaned,
      id_name = p1_target_id_name
    )
  ),

  # ============================================================================
  # Weights matrix
  # ============================================================================
  # Build the matrix
  tar_target(
    p2_weights,
    ncdfgeom::calculate_area_intersection_weights(
      p2_source[, c(p1_source_id_name, p1_source_geom_name)],
      p2_target[, c(p1_target_id_name, p1_target_geom_name)],
      # normalize will ensure weights are calculate with intersection area 
      # divided by *target* geometry areas
      normalize = TRUE
    )
  ),

  # Write it out for convenience, but, we won't be needing this target anymore.
  tar_target(
    p2_weights_write,
    write_csv(p2_weights, "2_process/out/source_target_weights.csv"),
    format = "file"
  ),

  # ============================================================================
  # Add area to weights
  # ============================================================================
  # Calculate source areas
  tar_target(
    p2_areas_x,
    tibble(
      source_id = p2_source[[p1_source_id_name]],
      source_areasqkm = as.numeric(
        units::set_units(sf::st_area(p2_source), "km^2")
      )
    )
  ),

  # Calculate target areas
  tar_target(
    p2_areas_y,
    tibble(
      target_id = p2_target[[p1_target_id_name]],
      target_areasqkm = as.numeric(
        units::set_units(sf::st_area(p2_target), "km^2")
      )
    )
  ),

  # Add them to weights matrix
  tar_target(
    p2_weights_plus,
    add_area_to_w_mtrx(
      weights = p2_weights,
      areas_x = p2_areas_x,
      areas_y = p2_areas_y,
      source_id_name = p1_source_id_name,
      target_id_name = p1_target_id_name
    )
  ),

  # ============================================================================
  # Pull attributes and process
  # ============================================================================
  # Read in your attributes table
  # You want your dataframe to look like this (column order does not matter):
  # | p1_source_var_name | p1_source_id_name | p1_source_value_name | others ...     |
  # |        .           |          .        |            .         |         .      |
  # |        .           |          .        |            .         |         .      |
  # |        .           |          .        |            .         |         .      |
  #
  # For example:
  # | characteristic_id  | feature_id        | characteristic_value | percent_nodata |
  # |        .           |          .        |            .         |         .      |
  
  # In this example, we will pull attributes for NHDPlusV2 catchments using some
  # handy functions and reformat it
  tar_target(
    p2_att_raw,
    nhdplusTools::get_catchment_characteristics(
      varname = p1_vars,
      ids = unique(p2_weights_plus[[p1_source_id_name]])
    ) |>
      rename_with(~eval(p1_source_id_name), comid),
    pattern = map(p1_vars)
  ),

  # Format (_wider) for the join with weights
  tar_target(
    p2_att_wide,
    p2_att_raw |>
      select(-percent_nodata) |>
      pivot_wider(
        names_from = p1_source_var_name,
        values_from = p1_source_value_name
      )
  ),

  # Join in with weights matrix
  tar_target(
    p2_att_joined,
    left_join(
      p2_att_wide,
      p2_weights_plus,
      by = p1_source_id_name,
      relationship = "one-to-many"
    )
  ),

  # Format (_longer) for the multiplication by weights
  tar_target(
    p2_att_long,
    p2_att_joined |>
      pivot_longer(
        cols = all_of(p1_vars),
        names_to = p1_source_var_name,
        values_to = p1_source_value_name
      ) |>
      na.omit()
  ),

  # ============================================================================
  # Rescale attributes
  # ============================================================================
  # Let's rescale with a area weighted mean aggregation method.
  tar_target(
    p2_rescaled, 
    rescale_weighted_mean(
      in_df = p2_att_long, 
      target_id_name = p1_target_id_name, 
      source_var_name = p1_source_var_name, 
      source_value_name = p1_source_value_name
    )
  ),

  # Cast the results as wide format.
  tar_target(
    p2_rescaled_wide,
    p2_rescaled |>
    pivot_wider(
      names_from = as.name(p1_source_var_name),
      values_from = rescaled_value
    )
  ),

  # ============================== OUTPUTS =====================================
  # Write out the rescaled values.
  tar_target(
    p2_rescaled_write,
    write_csv(p2_rescaled_wide, "2_process/out/rescaled_attributes.csv"),
    format = "file"
  ),
  # ============================================================================
  
  # Targets search path
  # These are the libraries targets loads in and the order in which R searches 
  # to find functions.
  tar_target(
    p2_search, 
    search()
  )
)
