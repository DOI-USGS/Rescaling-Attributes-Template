# scripts with functions
source('1_fetch/src/load_data.R')

# targets list
p1_targets_list <- list(
  # ============================== USER INPUT ==================================
  # variables of interest 
  # ============================================================================
  # define the variables you care about in a vector
  # in this example, we will pull variables processed for NHDPlusV2 catchments; 
  # they are in this data release: https://www.sciencebase.gov/catalog/item/5669a79ee4b08895842a1d47
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
  # (1) source polygons: define the polygons where you have attributes processed to
  # in this example, we have data at NHDPlusV2 catchments 
  # download the polygons and put them in "1_fetch/out"
  tar_target(
    p1_source_dl, 
    sbtools::item_file_download(
      "61295190d34e40dd9c06bcd7", 
      names = "reference_catchments.gpkg",
      destinations = "1_fetch/out/reference_catchments.gpkg"
    ), 
    format = "file"
  ),
  
  tar_target(
    p1_source, 
    sf::read_sf(p1_source_dl)
  ), 
  
  # (2) target polygons: define the polygons you want attributes processed to
  # in this example, we will rescale data to the latest WBD HUC12
  # URL: "https://prd-tnm.s3.amazonaws.com/index.html?prefix=StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip"
  # download the polygons from the cloud and put them in "1_fetch/out"
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
  
  # read in the polygons
  # use sf::st_layers(p1_target_dl) in the console to find the layers
  tar_target(
    p1_target, 
    sf::read_sf(p1_target_dl, layer = "WBDHU12")
  ),
  
  # (3) Basin of interest: if you don't want to do national analysis, bring in your area of interest
  # in this example, we will rescale data only for the Delaware River Basin
  # download the basin boundary and put it in "1_fetch/out"
  tar_target(
    p1_drb_dl,
    sbtools::item_file_download(
      "5ef366dc82ced62aaae3ee63",
      dest_dir = "1_fetch/out"
    ),
    format = "file"
  ),
  
  # read in the Area of Interest (AOI) 
  tar_target(
    p1_aoi,
    sf::st_read(p1_drb_dl[grep(".shp$", p1_drb_dl)])
  ),
  
  # ============================================================================
  # what are your columns called?
  # ============================================================================
  # what is the unique id for each source and target geometry?
  tar_target(
    p1_source_id_name, 
    "featureid"
  ), 
  
  tar_target(
    p1_target_id_name, 
    "huc12"
  ), 
  
  # what is the geometry column called in your spatial dataframes?
  tar_target(
    p1_source_geom_name, 
    "geom"
  ), 
  
  tar_target(
    p1_target_geom_name, 
    "shape"
  ), 
  
  # what are the variables and their associated values called in your attributes dataframe?
  # you want your dataframe to look like this (column order does not matter):
  #       | p1_source_var_name | p1_source_id_name | p1_source_value_name | others ...     |
  #       |        .           |          .        |            .         |         .      |
  #       |        .           |          .        |            .         |         .      |
  #       |        .           |          .        |            .         |         .      |
  #
  # e.g., | characteristic_id  | feature_id        | characteristic_value | percent_nodata |
  #       |        .           |          .        |            .         |         .      |
  tar_target(
    p1_source_var_name, 
    "characteristic_id"
  ),
  
  tar_target(
    p1_source_value_name, 
    "characteristic_value"
  )
)
