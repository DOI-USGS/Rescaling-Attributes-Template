#' Remove all geometry types that are not polygons or multipolygons. Function will return the geometry if no other types exist.
#' @param x an sf geometry
#'
clean_geometry_type <- function(x){
  bad_types <- which(st_geometry_type(x) != "POLYGON" & st_geometry_type(x) != "MULTIPOLYGON")
  
  if(length(bad_types) != 0) {
    warning("There are geometry types in target geometry that are not polygon or multipolygon. You will need to fix those before proceeding. For now, I am going to delete those geometries!")
    x_cleaned <- x[-bad_types, ]
  } else {
    x_cleaned <- x
  }
  return(x_cleaned)
}



#' Resolve cases where multiple features have the same featureid by combining the individual features into a single geometry
#' @param x an sf geometry
#' @param id the unique identifiers of the elements in a geometry. For example in NHDPlusV2 it is "featureid"
#'
dedup <- function(x, id) {
  dup <- x[x[[id]] %in% x[[id]][duplicated(x[[id]])], ]
  dup <- dplyr::group_by(dup, dplyr::across(all_of(id))) |>
    dplyr::summarise(do_union = FALSE) # do not change the order of points when combining/unionizing
  
  if(nrow(dup) > 0) {
    x[!x[[id]] %in% dup[[id]], ] |>
      dplyr::select(dplyr::all_of(id)) |>
      dplyr::bind_rows(dup)
  } else {
    dplyr::select(x, dplyr::all_of(id))
  }
}


# TODO: need to test if this still works! 
#' Example of how to make a unique ID column
#' @param source sf geometry, e.g., NHDPlusV2
#' @param id name of the id column that should be unique, e.g., for NHDPlusV2, it is featureid
#'
make_unique_id <- function(source, id){
  uniqueid <- source |>
    st_drop_geometry() |>
    group_by(pick(eval(id))) |>
    mutate(rowid = data.table::rowid(pick(eval(id)))) |>
    mutate(
      id_num = ifelse(
        rowid > 1, 
        paste(id, rowid, sep = "_"), 
        as.character(id)
      )
    )
  source <- source |>
    mutate(id_num = uniqueid$id_num)

  return(source)
}


#' To rescale attributes with area weighted mean aggregation method
#' @param in_df attribute dataframe for each intersection of source and target geometries in long format
#' @param target_id_name unique ID for target geometry, e.g., "huc12"
#' @param source_var_name variable column name in the source attribute dataframe, e.g., "characteristic_id"
#' @param source_value_name value column name in the source attribute dataframe, e.g., "characteristic_value"
#'
rescale_weighted_mean <- function(in_df, target_id_name, source_var_name, 
                                  source_value_name) {
  rescaled_df <- in_df |> 
    group_by(.data[[target_id_name]], .data[[source_var_name]]) |> 
    summarise(
      rescaled_value = weighted.mean(
        x = .data[[source_value_name]],
        w = intersection_areasqkm,
        na.rm = TRUE,
        .groups = "drop"
      )
    ) |> 
    arrange(source_var_name)
  
  return(rescaled_df)
}


#' Check that source geometry doesn't contain duplicate IDs but proceeds
#' @param sf sf object with (MULTI)POLYGON geometry type
#' @param id_name chr; name of id column name in `sf`
#'
#' @return `sf`; produces a warning if duplicate ids exist
#' 
check_no_dup_ids <- function(sf, id_name) {
  is_unique <- nrow(sf) == length(unique(sf[[id_name]]))
  
  if(! is_unique) {
    cli::cli_warn(c(
      "!" = "There are duplicate IDs in the geometry.",
      "!" = paste(
        "The pipeline will run, but be aware that at these duplicated",
        "geometries attributes are unreliable because implicit assumptions are",
        "made when aggregating values."
      ),
      "i" = "You should handle these cases: either deduplicate or make a unique ID."
    ))
  }
  
  return(sf)
}


#' Ensure that source geometry doesn't contain duplicate IDs
#' @param sf sf object with (MULTI)POLYGON geometry type
#' @param id_name chr; name of id column name in `sf`
#'
#' @return if no duplicates `sf`; otherwise deduplicated `sf`
#' 
ensure_no_dup_ids <- function(sf, id_name) {
  is_unique <- nrow(sf) == length(unique(sf[[id_name]]))
  
  if(is_unique) {
    return(sf)
  } else {
    cli::cli_warn(c(
      "!" = "There are duplicate IDs in target geometry.",
      "!" = "I will deduplicate these for you, but make sure that is what you want!"
    ))
    
    return(dedup(sf, id_name))
  }
}

#' Add area columns to weights data frame
#' @param weights data frame; must have columns: w, `source_id_name`, and `target_id_name`
#' @param source_areas data.frame; must have columns: source_id and `source_id_name`
#' @param target_areas data.frame; must have columns: source_id and `target_id_name`
#' @param source_id_name chr; name of source id column
#' @param target_id_name chr; name of target id column
#'
#' @return data frame that joins `weights`, `areas_source`, and `areas_target`
#' 
add_area_to_w_mtrx <- function(weights, source_areas, target_areas, 
                               source_id_name, target_id_name) {
  # Ensure necessary column names are present.
  assertthat::assert_that(
    assertthat::has_name(weights, c("w", source_id_name, target_id_name))
  )
  assertthat::assert_that(assertthat::has_name(source_areas, c("source_id")))
  assertthat::assert_that(
    assertthat::has_name(target_areas, c("target_id", "target_areasqkm"))
  )
  
  weights |> 
    dplyr::left_join(source_areas, by = join_by(!!source_id_name == source_id)) |>
    dplyr::left_join(target_areas, by = join_by(!!target_id_name == target_id)) |>
    dplyr::mutate(intersection_areasqkm = target_areasqkm * w)
}

#' Write csv tables and return the path 
#' @param data table you want to write out 
#' @param path full path including extension
#' 
write_csv_targets <- function(data, path, ...) {
  write_csv(data, path)
  return(path)
}
