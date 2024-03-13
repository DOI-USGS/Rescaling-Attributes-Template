# scripts with functions
source('3_visualize/src/density_plots.R')
source('3_visualize/src/spatial_maps.R')

# targets list
p3_targets_list <- list(
  # ============================================================================
  # choropleth plot 
  # ============================================================================
  # set the attribute variable you want to plot
  tar_target(
    p3_attribute_to_plot, 
    "CAT_BASIN_SLOPE"
  ),
  
  # (1) plot one source attribute
  # first, join the geometry and the attribute dataframe
  tar_target(
    p3_source, 
    sf::st_sf(
      dplyr::inner_join(
        p2_source, 
        p2_att_joined, 
        by = p1_source_id_name
      )
    )
  ), 
  
  # second, plot
  tar_target(
    p3_source_att,
    make_attribute_map(
      geom_and_att = p3_source,
      att = p3_attribute_to_plot,
      file_out_path = "3_visualize/out/p3_source_attribute.png"
    )
  ), 

  # (2) plot one target attribute
  # first, join the geometry and the attribute dataframe
  tar_target(
    p3_target,
    sf::st_sf(
      dplyr::inner_join(
        p2_target,
        p2_rescaled_wide,
        by = p1_target_id_name
      )
    )
  ),

  # second, plot
  tar_target(
    p3_target_att,
    make_attribute_map(
      geom_and_att = p3_target,
      att = p3_attribute_to_plot,
      file_out_path = "3_visualize/out/p3_target_attribute.png"
    )
  ), 

  # ============================================================================
  # density plot
  # ============================================================================
  # prepare dataframe for ggplot
  tar_target(
    p3_density_df,
    make_density_df(
      source_att = p2_att_wide,
      source_id_name = p1_source_id_name,
      source_label = "NHD",
      rescaled_att = p2_rescaled_wide,
      target_id_name = p1_target_id_name,
      target_label = "WBD",
      att = p3_attribute_to_plot
    )
  ), 

  # prepare summary dataframe for ggplot
  tar_target(
    p3_density_summary,
    make_density_summary_df(
      density_df = p3_density_df, 
      att = p3_attribute_to_plot
    )
  ), 

  # make the plot
  tar_target(
    p3_density_comp,
    plot_density(
      density_df = p3_density_df, 
      density_summary = p3_density_summary, 
      att = p3_attribute_to_plot, 
      file_out = "p3_density_comp.png"
    )
  )
)