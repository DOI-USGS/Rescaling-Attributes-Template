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

#' example of how to make a unique ID column, only relevant to NHDPlusV2
#' @param source sf geometry that is the NHDPlusV2

make_unique_id <- function(source){
  uniqueid <- source |>
    st_drop_geometry() |>
    group_by(featureid) |>
    mutate(rowid = data.table::rowid(featureid)) |>
    mutate(
      featureid_num = ifelse(
        rowid > 1, 
        paste(featureid, rowid, sep = "_"), 
        as.character(featureid)
      )
    )
  source <- source |>
    mutate(featureid_num = uniqueid$featureid_num)

  return(source)
}



