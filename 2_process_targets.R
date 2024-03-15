# scripts with functions
source('2_process/src/process_data.R')

# targets list
p2_targets_list <- list(
  # ============================================================================
  # prep the spatial geometries
  # ============================================================================
  # pick your projection: albers equal area is generally good for CONUS
  tar_target(
    p2_proj, 
    5070                                                     
  ), 
  
  # do a spatial transformation 
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
  
  # subset to AOI
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
  # check if there are duplicate IDs 
  # ============================================================================
  # if there are duplicate IDs in source, proceed anyway
  tar_target(
    p2_source,
    check_no_dup_ids(
      sf = p2_source_intersected,
      id_name = p1_source_id_name
    )
  ),
  
  # if there are duplicate IDs in target, de-duplicate
  # sometimes, the WBD will have a geometry with a small dangling pixel that creates self-intersecting polygons and the dataframe will have a duplicated ID associated with each polygon.
  tar_target(
    p2_target,
    ensure_no_dup_ids(
      sf = p2_target_cleaned,
      id_name = p1_target_id_name
    )
  ),

  # ============================================================================
  # weights matrix
  # ============================================================================
  # build the matrix
  tar_target(
    p2_weights,
    ncdfgeom::calculate_area_intersection_weights(
      p2_source[, c(p1_source_id_name, p1_source_geom_name)],
      p2_target[, c(p1_target_id_name, p1_target_geom_name)],
      # normalize will ensure weights are calculate with intersection area divided by *target* geometry areas
      normalize = TRUE
    )
  ),

  # write it out for convenience, but, we won't be needing this target anymore
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
      source_id = p2_source[[p1_source_id_name]],
      source_areasqkm = as.numeric(
        units::set_units(sf::st_area(p2_source), "km^2")
      )
    )
  ),

  # calculate target areas
  tar_target(
    p2_areas_y,
    tibble(
      target_id = p2_target[[p1_target_id_name]],
      target_areasqkm = as.numeric(
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
    left_join(p2_weights, p2_areas_x, by = setNames("source_id", eval(p1_source_id_name))) |>
      left_join(p2_areas_y, by = setNames("target_id", eval(p1_target_id_name))) |>
      mutate(intersection_areasqkm = target_areasqkm * w)
  ),

  # ============================================================================
  # pull attributes and process
  # ============================================================================
  # read in your attributes table
  # you want your dataframe to look like this (column order does not matter):
  #       | p1_source_var_name | p1_source_id_name | p1_source_value_name | others ...     |
  #       |        .           |          .        |            .         |         .      |
  #       |        .           |          .        |            .         |         .      |
  #       |        .           |          .        |            .         |         .      |
  #
  # e.g., | characteristic_id  | feature_id        | characteristic_value | percent_nodata |
  #       |        .           |          .        |            .         |         .      |
  
  # in this example, we will pull attributes for NHDPlusV2 catchments using some handy functions and reformat it
  tar_target(
    p2_att_raw,
    nhdplusTools::get_catchment_characteristics(
      varname = p1_vars,
      ids = unique(p2_weights_plus[[p1_source_id_name]])
    ) |>
      rename_with(~eval(p1_source_id_name), comid),
    pattern = map(p1_vars)
  ),

  # format (_wider) for the join with weights
  tar_target(
    p2_att_wide,
    p2_att_raw |>
      select(-percent_nodata) |>
      pivot_wider(
        names_from = p1_source_var_name,
        values_from = p1_source_value_name
      )
  ),

  # join in with weights matrix
  tar_target(
    p2_att_joined,
    left_join(
      p2_att_wide,
      p2_weights_plus,
      by = p1_source_id_name,
      relationship = "one-to-many"
    )
  ),

  # format (_longer) for the multiplication by weights
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
  # rescale attributes
  # ============================================================================
  # let's rescale with a area weighted mean aggregation method
  tar_target(
    p2_rescaled, 
    rescale_weighted_mean(
      in_df = p2_att_long, 
      target_id_name = p1_target_id_name, 
      source_var_name = p1_source_var_name, 
      source_value_name = p1_source_value_name
    )
  ),

  # cast the results as wide format
  tar_target(
    p2_rescaled_wide,
    p2_rescaled |>
    pivot_wider(
      names_from = as.name(p1_source_var_name),
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
  ),
  # ============================================================================
  
  # targets search path; these are the libraries targets loads in and the order in which R searches to find functions 
  tar_target(
    p2_search, 
    search()
  )
)
