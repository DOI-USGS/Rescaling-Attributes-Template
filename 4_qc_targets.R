# Scripts with functions
source('4_qc/src/check.R')

# Targets list
p4_targets_list <- list(
  # ============================================================================
  # Plot maps to see your spatial aggregation units
  # ============================================================================
  # (1) Source
  tar_target(
    p4_map_source, 
    plot_geometry(
      geometry = p2_source,
      file_out_path = "4_qc/out/p4_map_source.png", 
      border_color = "#FF407D"
    ), 
    format = "file"
  ), 
  
  # (2) Target
  tar_target(
    p4_map_target, 
    plot_geometry(
      geometry = p2_source,
      file_out = "4_qc/out/p4_map_target.png", 
      border_color = "#40679E"
    ), 
    format = "file"
  ), 
  
  # ============================================================================
  # Do weights sum to one?
  # ============================================================================
  # Aggregate weights on target, this is applicable to gdptools weights and 
  # ncdfgeom when normalize = TRUE.
  tar_target(
    p4_weights_qc,
    build_qc_df(
      weights_plus = p2_weights_plus, 
      target_id_name = p1_target_id_name
    )
  ), 

  # Make the spatial dataframe.
  tar_target(
    p4_target,
    sf::st_sf(
      dplyr::inner_join(
        p2_target,
        p4_weights_qc,
        by = p1_target_id_name
      )
    )
  ),

  # Visualize
  # You want to see weights summing to one everywhere on the map.
  tar_target(
    p4_weights_map,
    make_attribute_map(
      geom_and_att = p4_target,
      att = "sum_int_over_target",
      file_out_path = "4_qc/out/p4_weights_map.png"
    ),
    format = "file"
  ), 
  
  # You want to see the boxplot of points as close to one as possible.
  tar_target(
    p4_weights_sum_boxplot,
    {
      out_boxplot <- ggplot(p4_target) +
        geom_boxplot(aes(y = sum_int_over_target)) 
      ggsave(plot = out_boxplot, "4_qc/out/p4_weights_boxplot.png")
    },
    format = "file"
  ),

  # ============================================================================
  # Flag target IDs where the weights do not add to one
  # ============================================================================
  # Make a flag column in the qc dataframe.
  tar_target(
    p4_sourceid_flagged,
    p4_weights_qc |>
      mutate(
        flag = cut(
          sum_int_over_target,
          breaks = c(-Inf, 0, 0.9, 1.001, Inf),
          labels = c("ugly neg", "bad", "good", "ugly pos"),
          right = FALSE,
          dig.lab = 3
        )
      )
  ),

  # Join in with weights file.
  tar_target(
    p4_weights_flagged,
    left_join(
      p2_weights_plus,
      p4_sourceid_flagged |>
        select(all_of(c(p1_target_id_name, "flag"))),
      by = p1_target_id_name
    )
  ), 

  # Output another weights table with flags.
  tar_target(
    p4_weights_flagged_write,
    write_csv_targets(p4_weights_flagged, "4_qc/out/weights_flagged.csv"),
    format = "file"
  )
)