
#' make a map of geometry borders
#' @param geometry sf geometry 
#' @param file_out string name of ggplot file with extension 
#' @param border_color geometry border colors, defaults to black 
#' @param geom_fill attribute in string format if you want to fill in the boundaries with color, defaults to NA

plot_geometry <- function(geometry, file_out, border_color = "black"){
  # for basemap
  my_states <- sf::st_as_sf(
    maps::map(
      "state", 
      plot = FALSE,
      fill = TRUE
    )
  )
  
  # zoom out a bit
  bbox <- st_bbox(geometry)
  xlimit <- c(bbox$xmin - 0.1*(bbox$xmax-bbox$xmin), bbox$xmax + 0.1*(bbox$xmax-bbox$xmin))
  ylimit <- c(bbox$ymin - 0.1*(bbox$ymax-bbox$ymin), bbox$ymax + 0.1*(bbox$ymax-bbox$ymin))
  
  # plot
  ggplot() +
    geom_sf(
      data = geometry, 
      col = border_color, 
      fill = NA
    ) +
    ggtitle("Area of Interest") +
    geom_sf(
      data = my_states, 
      col = "grey50", 
      fill = NA
    ) +
    geom_sf_text(
      data = my_states, 
      aes(label = ID), 
      colour = "grey50"
    ) +
    coord_sf(xlim = xlimit , ylim = ylimit) 
  
  ggsave(paste0("4_qc/out/", file_out))
}

# labs(fill = "sums to \none?",
#      title = "Sum of Weights On Target Geometry.",
#      subtitle = "weights built with ncdfgeom (normalize = TRUE)\nshould sum to one on target geometries!")

#' build the dataframe to be used for QCing 
#' @param weights_plus the augmented weights df with source and target and intersection areas 
#' @param target_id_name unique ID for target geometry, e.g., "huc12"

build_qc_df <- function(weights_plus, target_id_name){
  qc_df <- weights_plus |>
    na.omit() |>
    group_by(.data[[target_id_name]]) |>
    summarize(sum_intersection_areasqkm = sum(intersection_areasqkm),
              num_obs = n(),
              sum_intersection_areasqkm_over_target_areasqkm = sum_intersection_areasqkm/unique(target_areasqkm))
  return(qc_df)
}


