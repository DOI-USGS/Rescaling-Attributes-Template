# scripts with functions
source('1_fetch/src/load_data.R')

# targets list
p1_targets_list <- list(
  # ============================== USER INPUT ==================================
  # variables of interest 
  # ============================================================================
  tar_target(
    p1_vars,
    {
      vars_all <- nhdplusTools::get_characteristics_metadata()
      
      # WARNING!!! This method of intersecting polygons is only applicable to the "CAT_" attributes
      vars_cat <- vars_all[grep("CAT_", vars_all$ID), ]
      
      # example variables
      vars_nlcd <- vars_cat[grep("CAT_NLCD", vars_cat$ID), "ID"]
      vars_lc <- vars_cat[vars_cat$themeLabel == "Land Cover", "ID"]
      vars_slope <- c("CAT_BASIN_SLOPE", "CAT_STREAM_SLOPE")
      
      # this is 1,254 variables
      # c(vars_nlcd, vars_lc, vars_slope)
      
      # this is 8 variables
      c(vars_nlcd[1:3], vars_lc[1:3], vars_slope)
    }
  ),
  
  # ============================================================================
  # area of interest
  # ============================================================================
  # (1) source polygons: NHDPlusV2 catchments 
  tar_target(
    p1_source_dl, 
    {
      path <- "1_fetch/out"
      fileout <- file.path(path, "reference_catchments.gpkg")
      sbtools::item_file_download(
        "61295190d34e40dd9c06bcd7", 
        names = basename(fileout),
        destinations = fileout
      )
      fileout
    }, 
    format = "file"
  ),
  
  tar_target(
    p1_source, 
    sf::read_sf(p1_source_dl)
  ), 
  
  # (2) target polygons: latest WBD HUC12
  # URL: "https://prd-tnm.s3.amazonaws.com/index.html?prefix=StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip"
  tar_target(
    p1_target_dl,
    {
      ## check if bucket exists
      # bucket_exists(
      #   bucket = "s3://prd-tnm",
      #   region = "us-west-2"
      # )
      
      path <- "1_fetch/out"
      fileout <- file.path(path, "WBD_National_GDB.zip")
      
      save_object(
        object = "StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip", 
        bucket = "s3://prd-tnm/",
        region = "us-west-2",
        file = fileout
      )
      unzip(fileout, exdir = path)
      fileout
    },
    format = "file"
  ),
  
  # use sf::st_layers(p1_target_dl) in the console to find the layers
  tar_target(
    p1_target, 
    sf::read_sf(p1_target_dl, layer = "WBDHU12")
  ),
  
  # (3) Basin of interest if you don't want to do national analysis
  tar_target(
    p1_drb_dl,
    sbtools::item_file_download(
      "5ef366dc82ced62aaae3ee63",
      dest_dir = "1_fetch/out"
    ),
    format = "file"
  ),
  
  tar_target(
    p1_aoi,
    sf::st_read(p1_drb_dl[grep(".shp$", p1_drb_dl)])
  )

)