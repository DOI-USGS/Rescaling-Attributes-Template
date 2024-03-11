# scripts with functions
# source('3_visualize/src/density_plots.R')
# source('3_visualize/src/spatial_maps.R')

# targets list
p3_targets_list <- list(
  # ============================================================================
  # choropleth plot 
  # ============================================================================
  # plot one source attribute
  tar_target(
    p3_source, 
    sf::st_sf(
      dplyr::inner_join(
        p2_source, 
        p2_att_joined, 
        by = join_by(featureid == comid)
      )
    )
  ), 
  
  tar_target(
    p3_source_att, 
    {
      ggplot() + 
        geom_sf(
          data = p3_source, 
          aes(fill = CAT_BASIN_SLOPE, col = CAT_BASIN_SLOPE)) +
        scale_fill_viridis(option = "cividis") +
        scale_color_viridis(option = "cividis")
      ggsave("3_visualize/out/p3_source_attribute.png")
    }
  ), 
  
  # plot one target attribute
  tar_target(
    p3_target, 
    sf::st_sf(
      dplyr::inner_join(
        p2_target, 
        p2_rescaled_wide, 
        by = join_by(huc12)
      )
    )
  ), 
  
  tar_target(
    p3_target_att, 
    {
      ggplot() + 
        geom_sf(
          data = p3_target, 
          aes(fill = CAT_BASIN_SLOPE, col = CAT_BASIN_SLOPE)) +
        scale_fill_viridis(option = "cividis") +
        scale_color_viridis(option = "cividis")
      ggsave("3_visualize/out/p3_target_attribute.png")
    }
  ), 
  
  # ============================================================================
  # density plot
  # ============================================================================
  # prepare dataframe for ggplot
  tar_target(
    p3_density_df, 
    {
      df_source <- p2_att_wide|>
        select(c(comid, CAT_BASIN_SLOPE)) |>
        mutate(
          comid = as.character(comid), 
          data_source = "NHD", 
          id_name = "comid"
        ) |>
        rename(id = comid) |>
        na.omit()
      
      df_target <- p2_rescaled_wide|>
        select(c(huc12, CAT_BASIN_SLOPE)) |>
        mutate(data_source = "WBD", id_name = "huc12") |>
        rename(id = huc12) |>
        na.omit()
      
      bind_rows(df_source, df_target)
    }
  ), 
  
  # prepare summary dataframe for ggplot
  tar_target(
    p3_density_summary, 
    p3_density_df |>
      group_by(data_source) |>
      summarize(min = min(CAT_BASIN_SLOPE), 
                mean = mean(CAT_BASIN_SLOPE),
                max = max(CAT_BASIN_SLOPE))
  ), 
  
  # make the plot
  tar_target(
    p3_density_comp, 
    {
      ggplot() +
        geom_density(data = p3_density_df, 
                     aes(x = CAT_BASIN_SLOPE, 
                         fill = data_source, 
                         col = data_source), 
                     alpha = 0.2) +
        geom_vline(data = p3_density_summary, 
                   mapping = aes(xintercept = mean, 
                                 color = data_source), 
                   linetype = "dashed", 
                   show.legend = TRUE) + 
        scale_color_manual(values = c("#FF407D", "#40679E")) +
        scale_fill_manual(values = c("#FF407D", "#40679E")) +
        labs(fill = "Geometry", col = "Geometry") +
        theme_bw() +
        theme(legend.position = "bottom")
      ggsave("3_visualize/out/p3_density_comp.png")
    }
  )
)