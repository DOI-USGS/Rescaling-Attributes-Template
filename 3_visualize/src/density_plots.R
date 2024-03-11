# make density plots for exploratory data analysis 
#' @param att_output dataframe of attributes outputted by phase 2, process
#' @param data_table one of c("nhd_att", "nhgf_att") to plot either the raw NHDPlus data or the data aggregated to nhgf segments
#' @param areas_of_interest character name of the areas of interest for .png name, example c("delaware_river_basin", "upper_colorado_river_basin") the names in p1_aoi
#' @param summary_statistic summary statistic applied to rescale each characteristic, can be one of c("sum", "area_wtd," "min," and "max") only applicable when data_table = "nhgf_segment_data_table"
#' @param num_vars number of variable to plot (chooses the first n number of variables you define). Defaults to 10.
#' @param out_dir folder to save the map to

make_densityplot <- function(att_output, data_table, areas_of_interest, summary_statistic = NULL, num_vars = 10, out_dir){
  # pick some variables based on num_vars parameter
  all_vars <- unique(att_output$characteristic_id)
  max_number_of_vars <- min(c(length(all_vars), num_vars))
  att_output <- att_output |>
    filter(characteristic_id %in% all_vars[1:max_number_of_vars])
  some_vars <- unique(att_output$characteristic_id)
  print(paste(c("plotting these characteristics: ", some_vars), collapse=" "))
  
  for(v in seq_along(some_vars)){
    var_of_interest <- some_vars[[v]]
    att_output_var_subset <- att_output |>
      filter(characteristic_id == var_of_interest)
    
    for(i in seq_along(areas_of_interest)){
      area_of_interest <- areas_of_interest[[i]]
      
      # make a long format table for ggplot
      att_long <- att_output_var_subset |>
        filter(aoi == area_of_interest) |>
        select(characteristic_id, aoi, {{data_table}}) |>
        unnest({{data_table}}, names_repair = "universal")
      
      # format summary table at aoi level for chart annotations of min, max, mean
      att_summary <- att_output_var_subset |>
        filter(aoi == area_of_interest) |>
        select(aoi_summary_stats) |>
        unnest(aoi_summary_stats)
      
      # pick the right x based on which data_table we are plotting
      x <- ifelse(data_table == "nhd_att", "characteristic_value", paste0(summary_statistic, "_characteristic_value")) 
      
      # make density plot
      ggplot(data = att_long) +
        geom_density(aes(x = !!sym(x)), fill = "grey", alpha = 0.5) +
        geom_vline(data = att_summary, mapping = aes(xintercept = min_characteristic_value, 
                   color = "min"), linetype = "dashed", show.legend = TRUE) +
        geom_vline(data = att_summary, mapping = aes(xintercept = mean_characteristic_value, 
                   color = "mean"), linetype = "dashed", show.legend = TRUE) +
        geom_vline(data = att_summary, mapping = aes(xintercept = max_characteristic_value, 
                   color = "max"), linetype = "dashed", show.legend = TRUE) +
        scale_color_manual(values = c('min' = '#eab676', 'mean' = '#468e6c', 'max' = '#70a0bf')) +
        guides(colour = guide_legend(reverse = TRUE)) + 
        labs(title = paste0("AOI: ", area_of_interest, ", Variable: ", var_of_interest), 
             x = "characteristic value", 
             color = "") +
        theme_bw() +
        theme(legend.position = "bottom")
      
      if(!dir.exists(out_dir)){dir.create(out_dir)}
      out_file <- paste0(out_dir, "/p3_density_", data_table, "_", var_of_interest, "_", area_of_interest, "_", summary_statistic, ".png")
      ggsave(out_file, height = 9, width = 16, units = "in", dpi = 300)
    }
  }
  return(out_dir)
}

