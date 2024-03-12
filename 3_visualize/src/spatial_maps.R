#' choropleth plot of attributes on a map 
#' @param geom_and_attribute joine spatial dataframe of geometries and attributes 
#' @param att attribute of interest in string format
#' @param file_out string name of ggplot file with extension

make_attribute_map <- function(geom_and_att, att, file_out){
  ggplot() + 
    geom_sf(
      data = geom_and_att, 
      aes(fill = .data[[att]], col = .data[[att]])) +
    scale_fill_viridis(option = "cividis") +
    scale_color_viridis(option = "cividis")
  
  ggsave(paste0("3_visualize/out/", file_out))
}