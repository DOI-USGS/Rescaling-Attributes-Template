#' to build a density dataframe for ggplot 
#' @param source_att wide format dataframe of source attributes
#' @param source_id_name unique ID for source geometry, e.g., "featureid"
#' @param source_label legend label of source data set in string format, e.g., "NHD"
#' @param rescaled_att wide format dataframe of rescaled attributes
#' @param target_id_name unique ID for target geometry, e.g., "huc12"
#' @param target_label egend label of target data set in string format, e.g., "WBD"
#' @param att attribute of interest in string format

make_density_df <- function(source_att, source_id_name, source_label, rescaled_att, target_id_name, target_label, att){
  cols <- c(source_id_name, att)
  df_source <- source_att|>
    select(all_of(cols)) |>
    mutate(
      source_id = as.character(featureid), 
      data_source = source_label, 
      id_name = "source_id"
    ) |>        
    rename(id = source_id) |>
    select(-any_of(source_id_name)) |>
    na.omit()
  
  cols <- c(target_id_name, att)
  df_target <- rescaled_att|>
    select(all_of(cols)) |>
    rename(target_id = as.name(target_id_name)) |>
    mutate(
      data_source = target_label, 
      id_name = "target_id"
    ) |>
    rename(id = target_id) |>
    na.omit()
  
  df <- bind_rows(df_source, df_target)
  return(df)
}



#' to calculate min, mean, max to put on the plot 
#' @param density_df long dataframe of all source and target attributes
#' @param att attribute of interest in string format

make_density_summary_df <- function(density_df, att){
  summary_df <- density_df |>
    group_by(data_source) |>
    summarize(min = min(.data[[att]]),
              mean = mean(.data[[att]]),
              max = max(.data[[att]]))
  return(summary_df)
}


#' to plot the density function by source and target attributes 
#' @param density_df long dataframe of all source and target attributes
#' @param density_summary dataframe of min, mean, max calculated from attributes by source and target 
#' @param att attribute of interest in string format
#' @param file_out string name of ggplot file with extension

plot_density <- function(density_df, density_summary, att, file_out){
  ggplot() +
    geom_density(data = density_df,
                 aes(x = .data[[att]],
                     fill = data_source,
                     col = data_source),
                 alpha = 0.2) +
    geom_vline(data = density_summary,
               mapping = aes(xintercept = mean,
                             color = data_source),
               linetype = "dashed",
               show.legend = TRUE) +
    scale_color_manual(values = c("#FF407D", "#40679E")) +
    scale_fill_manual(values = c("#FF407D", "#40679E")) +
    labs(fill = "Geometry", col = "Geometry") +
    theme_bw() +
    theme(legend.position = "bottom")
  
  ggsave(paste0("3_visualize/out/", file_out))
}



