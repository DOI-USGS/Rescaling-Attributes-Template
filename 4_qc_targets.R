# scripts with functions
source('4_qc/src/check.R')

# targets list
p4_targets_list <- list(
  # ============================================================================
  # plot maps
  # ============================================================================
  # (1) source
  tar_target(
    p4_map_source, 
    plot_geometry(
      geometry = p2_source,
      file_out = "p4_map_source.png", 
      border_color = "#FF407D"
    ), 
    format = "file"
  ), 
  
  # (2) target
  tar_target(
    p4_map_target, 
    plot_geometry(
      geometry = p2_source,
      file_out = "p4_map_target.png", 
      border_color = "#40679E"
    ), 
    format = "file"
  ), 
  
  # ============================================================================
  # do weights sum to one?
  # ============================================================================
  # aggregate weights on target, this is applicable to gdptools weights and ncdfgeom when normalize = TRUE
  tar_target(
    p4_weights_qc,
    build_qc_df(
      weights_plus = p2_weights_plus, 
      target_id_name = p1_target_id_name
    )
  ), 

  # make the spatial dataframe
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

  # visualize
  tar_target(
    p4_weights_map,
    make_attribute_map(
      geom_and_att = p4_target,
      att = "sum_intersection_areasqkm_over_target_areasqkm",
      file_out_path = "4_qc/out/p4_weights_map.png"
    ),
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
        select(all_of(c(p1_target_id_name, "flag"))),
      by = p1_target_id_name
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