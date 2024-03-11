# targets list
p4_targets_list <- list(
  # ============================================================================
  # plot source map
  # ============================================================================
  tar_target(
    p4_map_source, 
    {
      my_states <- sf::st_as_sf(
        maps::map(
          "state", 
          plot = FALSE,
          fill = TRUE
        )
      )
      
      bbox <- st_bbox(p2_source)
      xlimit <- c(bbox$xmin - 0.1*(bbox$xmax-bbox$xmin), bbox$xmax + 0.1*(bbox$xmax-bbox$xmin))
      ylimit <- c(bbox$ymin - 0.1*(bbox$ymax-bbox$ymin), bbox$ymax + 0.1*(bbox$ymax-bbox$ymin))
      
      ggplot() +
        geom_sf(
          data = p2_source, 
          col = "#FF407D", 
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
      ggsave("4_qc/out/p4_map_source.png")
    }, 
    format = "file"
  ), 
  
  # ============================================================================
  # plot target map
  # ============================================================================
  tar_target(
    p4_map_target, 
    {
      my_states <- sf::st_as_sf(
        maps::map(
          "state", 
          plot = FALSE,
          fill = TRUE
        )
      )
      
      bbox <- st_bbox(p2_target)
      xlimit <- c(bbox$xmin - 0.1*(bbox$xmax-bbox$xmin), bbox$xmax + 0.1*(bbox$xmax-bbox$xmin))
      ylimit <- c(bbox$ymin - 0.1*(bbox$ymax-bbox$ymin), bbox$ymax + 0.1*(bbox$ymax-bbox$ymin))
      
      ggplot() +
        geom_sf(
          data = p2_target, 
          col = "#40679E", 
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
      ggsave("4_qc/out/p4_map_target.png")
    }, 
    format = "file"
  ), 
  
  # ============================================================================
  # do weights sum to one?
  # ============================================================================
  # aggregate weights on target, this is applicable to gdptools weights and ncdfgeom when normalize = TRUE
  tar_target(
    p4_weights_qc, 
    p2_weights_plus |>
      na.omit() |>
      group_by(huc12) |>
      summarize(sum_intersection_areasqkm = sum(intersection_areasqkm),
                num_obs = n(),
                sum_intersection_areasqkm_over_target_areasqkm = sum_intersection_areasqkm/unique(huc12_areasqkm))
  ), 
  
  # make the spatial dataframe
  tar_target(
    p4_target,
    sf::st_sf(
      dplyr::inner_join(
        p2_target, 
        p4_weights_qc, 
        by = join_by(huc12)
      )
    )
  ), 
  
  # visualize
  tar_target(
    p4_weights_map, 
    {
      my_states <- sf::st_as_sf(
        maps::map(
          "state", 
          plot = FALSE,
          fill = TRUE
        )
      )
      
      bbox <- st_bbox(p2_target)
      xlimit <- c(bbox$xmin - 0.1*(bbox$xmax-bbox$xmin), bbox$xmax + 0.1*(bbox$xmax-bbox$xmin))
      ylimit <- c(bbox$ymin - 0.1*(bbox$ymax-bbox$ymin), bbox$ymax + 0.1*(bbox$ymax-bbox$ymin))
      
      ggplot() + 
        geom_sf(
          data = p4_target, 
          aes(fill = sum_intersection_areasqkm_over_target_areasqkm),
          col = "#40679E" 
        ) +
        scale_fill_scico(palette = 'vik') +
        labs(fill = "sums to \none?", 
             title = "Sum of Weights On Target Geometry.", 
             subtitle = "weights built with ncdfgeom (normalize = TRUE)\nshould sum to one on target geometries!") +
        geom_sf(
          data = my_states, 
          col = "grey50", 
          fill = NA
        ) +
        geom_sf_text(
          data = my_states, 
          aes(label = ID), 
          colour = "grey50", 
          size = 2
        ) +
        coord_sf(xlim = xlimit , ylim = ylimit)
      ggsave("4_qc/out/p4_weights_map.png")
    }, 
    format = "file"
  ),
  
  tar_target(
    p4_weights_sum_boxplot, 
    {
      ggplot(p4_target) + 
        geom_boxplot(aes(y = sum_intersection_areasqkm_over_target_areasqkm))
      ggsave("4_qc/out/p4_weights_boxplot.png")
    }, 
    format = "file"
  ), 
  
  # ============================================================================
  # flag target IDs where the weights do not add to one
  # ============================================================================
  # make a flag column in the qc dataframe
  tar_target(
    p4_sourceid_flagged,
    p4_weights_qc |>
      mutate(
        flag = cut(
          sum_intersection_areasqkm_over_target_areasqkm,
          breaks = c(-Inf, 0, 0.9, 1.001, Inf),
          labels = c("ugly neg", "bad", "good", "ugly pos"),
          right = FALSE, 
          dig.lab = 3
        )
      )
  ),
  
  # join in with weights file
  tar_target(
    p4_weights_flagged, 
    left_join(
      p2_weights_plus, 
      p4_sourceid_flagged |>
        select(c(huc12, flag)), 
      by = join_by(huc12)
    )
  ),

  # output another weights table with flags
  tar_target(
    p4_weights_flagged_write,
    {
      file_out <- "4_qc/out/weights_flagged.csv"
      write_csv(p4_weights_flagged, file_out)
      file_out
    },
    format = "file"
  )
)