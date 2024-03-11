# make a choropleth map with att values, coloring in the river segments with the value
#' @param att_output dataframe of attributes outputted by phase 2, process
#' @param data_table one of c("nhd_att", "nhgf_att") to plot either the raw NHDPlus data or the data aggregated to NHGF segments
#' @param xwalks list of dataframe that connects nhgf_segid (NHGF identifier) with comid_cat (NHDPlus identifier), defaults to NULL for when you want to plot the full original dataset
#' @param num_vars number of variable to plot (chooses the first n number of variables you define). Defaults to 5.
#' @param out_dir folder to save the map to

map_att <- function(att_output, data_table, xwalks = NULL, num_vars = 5, out_dir){
  for(a in seq_along(unique(att_output$aoi))){
    name <- unique(att_output$aoi)[[a]]
    if(!is.null(xwalks)){xwalk <- xwalks[[a]]}
    
    if(data_table == "nhd_att"){
      df_comids <- att_output |>
        filter(aoi == name) |>
        select(nhd_att) |>
        purrr::map_dfr(purrr::pluck, 1, 1) |> 
        rename(comid = nhd_att)

      # get flowlines, make the request in batches
      comids_batches <- split(df_comids$comid, ceiling(seq_along(df_comids$comid)/1000))
      suppressMessages(
        flowlines <- lapply(comids_batches, 
                            function(x) {
                              nhdplusTools::get_nhdplus(comid = x, realization = "flowline")
                            }
        )
      )
      # collapse into one large list, note that dplyr::bind_rows() does not work with sf objects
      flowlines <- do.call(rbind, flowlines)
      
      # get a basemap, note that mapview is retiring
      sf_bbox <- st_bbox(flowlines)
      ggmap_bbox <- setNames(sf_bbox, c("left", "bottom", "right", "top"))
      suppressMessages(
        basemap_terrain <- get_map(source = "stamen", 
                                   maptype = "toner-lite", 
                                   location = ggmap_bbox, 
                                   zoom = 8, 
                                   messaging = FALSE)
      )
  
    } else if (data_table == "nhgf_att"){
      # select the nhgf river segments
      df_nhgf_segid <- att_output |> 
        filter(aoi == name) |>
        select(nhgf_att) |>
        purrr::map_dfr(purrr::pluck, 1, 1) |>
        rename(nhgf_segid = nhgf_att)
      
      # use the xwalk to get all the comids that intersect the nhgf river segment
      df_comids <- df_nhgf_segid |>
        left_join(xwalk, by = join_by(nhgf_segid == nhgf_segid)) |>
        tidyr::separate_rows(comid_seg, sep = ";") |>
        mutate(comid_seg = as.integer(comid_seg)) # need this mutation for join later
      
      # get flowlines, make the request in batches
      comids_batches <- split(df_comids$comid_seg, ceiling(seq_along(df_comids$comid_seg)/1000))
      suppressMessages(
        flowlines <- lapply(comids_batches, 
                            function(x) {
                              nhdplusTools::get_nhdplus(comid = x, realization = "flowline")
                            }
        )
      )
      # collapse into one large list, note that dplyr::bind_rows() does not work with sf objects
      flowlines <- do.call(rbind, flowlines)
      
      # get a basemap, note that mapview is retiring
      sf_bbox <- st_bbox(flowlines)
      ggmap_bbox <- setNames(sf_bbox, c("left", "bottom", "right", "top"))
      suppressMessages(
        basemap_terrain <- get_map(source = "stamen", 
                                   maptype = "toner-lite", 
                                   location = ggmap_bbox, 
                                   zoom = 8, 
                                   messaging = FALSE)
      )
      
    } else {
      stop("Error: data_table can be one of nhd_att or nhgf_att!")
    }
    
    # pick some variables based on num_vars parameter
    all_vars <- unique(att_output$characteristic_id)
    max_number_of_vars <- min(c(length(all_vars), num_vars))
    att_output <- att_output |>
      filter(characteristic_id %in% all_vars[1:max_number_of_vars])
    some_vars <- unique(att_output$characteristic_id)
    
    # now that we have the flowlines, we need to join in the characteristic values
    for(i in seq_along(some_vars)){
      char_id <- some_vars[[i]] 
      
      if(data_table == "nhd_att"){
        df <- att_output |> 
          filter(aoi == name) |>
          filter(characteristic_id == char_id) |>
          select(nhd_att) |>
          purrr::map_dfr(purrr::pluck, 1) 

        spdf <- flowlines |>
          left_join(df, by = join_by(comid == comid))
        
        # plot choropleth --------------------------------------------------------
        suppressMessages(
          ggplot_panel1 <- ggmap(basemap_terrain) +
            geom_sf(data = spdf, inherit.aes = FALSE, aes(color = characteristic_value)) +
            scale_color_scico(palette = "berlin") +
            labs(color = char_id) +
            theme(legend.position = "bottom")
        )
        # plot no data
        suppressMessages(
          ggplot_panel2 <- ggmap(basemap_terrain) +
            geom_sf(data = spdf, inherit.aes = FALSE, aes(color = percent_nodata)) +
            scale_color_scico(palette = "roma") +
            labs(color = "% no data") +
            theme(legend.position = "bottom")
        )
        # ------------------------------------------------------------------------
        
      } else if (data_table == "nhgf_att"){
        df <- att_output |> 
          filter(aoi == name) |>
          filter(characteristic_id == char_id) |>
          select(nhgf_att) |>
          purrr::map_dfr(purrr::pluck, 1) |> 
          rename(nhgf_segid = id) 
        
        # use the xwalk to get all the comids that intersect the nhgf river segment
        df <- df |>
          left_join(xwalk, by = join_by(nhgf_segid == nhgf_segid)) |>
          select(nhgf_segid, comid_cat, starts_with("area_wtd")) |> 
          mutate(num_obs = ifelse(lengths(gregexpr(";", comid_cat)) == 1, 1, lengths(gregexpr(";", comid_cat)) +1)) |>
          tidyr::separate_rows(comid_cat, sep = ";") |>
          mutate(comid_cat = as.integer(comid_cat)) # need this mutation for join later
        
        # join in characteristic values 
        spdf <- flowlines |>
          left_join(df, by = join_by(comid == comid_cat))
        
        
        # plot choropleth --------------------------------------------------------
        suppressMessages(
          ggplot_panel1 <- ggmap(basemap_terrain) +
            geom_sf(data = spdf, inherit.aes = FALSE, aes(color = select(spdf, starts_with("area_wtd"))[[1]])) +
            scale_color_scico(palette = "berlin") +
            labs(color = char_id)+
            theme(legend.position = "bottom")
        )
        # plot the number of comids that informed the value of that NHGF segment
        suppressMessages(
          ggplot_panel2 <- ggmap(basemap_terrain) +
            geom_sf(data = spdf, inherit.aes = FALSE, aes(color = num_obs)) +
            scale_color_scico(palette = "roma") +
            labs(color = "No. of COMIDS") +
            theme(legend.position = "bottom")
        )
        # ------------------------------------------------------------------------
        
      } else {
        stop(warning("Error: data_table can be one of nhd_att or nhgf_att!"))
      }
      
      # save plot
      if(!dir.exists(out_dir)){dir.create(out_dir)}
      out_file <- paste0(out_dir, "/p3_map_", data_table, "_", name, "_", char_id, ".png")
      cow_plot <- plot_grid(ggplot_panel1, ggplot_panel2)
      save_plot(cow_plot, file = out_file, base_width = 16, base_height = 9, units = "in", dpi = 300)
    }
  }
  return(out_dir)
}

