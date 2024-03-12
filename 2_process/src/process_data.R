#' to remove all geometry types that are not polygons or multipolygons. function will return the geometry if no other types exist.
#' @param x an sf geometry

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



#' to resolve cases where multiple features have the same featureid by combining the individual features into a single geometry
#' @param x an sf geometry
#' @param id the unique identifiers of the elements in a geometry. For example in NHDPlusV2 it is "featureid"

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
#' example of how to make a unique ID column, only relevant to NHDPlusV2
#' @param source sf geometry, e.g., NHDPlusV2
#' @param id name of the id column that should be unique, e.g., for NHDPlusV2, it is featureid

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


#' rescale attributes with area weighted mean aggregation method
#' @param in_df attribute dataframe for each intersection of source and target geometries in long format
#' @param target_id_name what you call you ID column in target geometries, e.g., "huc12"
#' @param source_var_name what you call your variables in the source attribute dataframe, e.g., "characteristic_id"
#' @param source_value_name what you call your value column in the source attribute dataframe, e.g., "characteristic_value"

rescale_weighted_mean <- function(
    in_df, target_id_name, source_var_name, source_value_name
  ) {
  in_df |> 
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
}



