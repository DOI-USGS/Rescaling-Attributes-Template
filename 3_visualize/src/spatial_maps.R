#' to make a choropleth plot of attributes on a map 
#' @param geom_and_attribute joined spatial dataframe of geometries and attributes 
#' @param att attribute of interest in string format
#' @param file_out_path string path of ggplot file with extension

make_attribute_map <- function(geom_and_att, att, file_out_path){
  ggplot() + 
    geom_sf(
      data = geom_and_att, 
      aes(fill = .data[[att]], col = .data[[att]])) +
    scale_fill_viridis(option = "cividis") +
    scale_color_viridis(option = "cividis")
  
  ggsave(file_out_path)
}