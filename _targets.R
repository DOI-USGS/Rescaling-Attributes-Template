# This code uses a pipelining package called targets. we assume you have some
# basic familiarity with it and proficiency in R. If you need help contact
# Ellie White (ewhite@usgs.gov)

# ==============================================================================
# Installations
# ==============================================================================
# install.packages("targets")
# remotes::install_github("doi-usgs/ncdfgeom)
# remotes::install_github("doi-usgs/nhdplusTools) 

# If there are problems with the functions in nhdplusTools try running this. It
# clears and re-downloads the metadata index of all the characteristics.
# nhdplusTools::get_characteristics_metadata(cache = FALSE)


# Authenticate ScienceBase if needed for your datasets. The ones in our template
# won't need it.
# remotes::install_github("doi-usgs/sbtools)
# initialize_sciencebase_session(username = "blah@usgs.gov") 


# ==============================================================================
# main target script for calling all subsequent targets
# ==============================================================================
library(targets)
library(tarchetypes)

# target options
tar_option_set(
  packages = c(
    # phase 1_fetch
    "tidyverse", "nhdplusTools", "sf", "sbtools", "aws.s3", 
    
    # phase 2_process, "areal" is a dependency that needs to be downloaded 
    "ncdfgeom", "mapdata", "maps", "data.table", "stringr",
    
    # phase 3_visualize
    "ggmap", "scico", "viridis"
    
    # phase 4_qc
    ), 
  format = "rds"
)

# suppress package warnings
options(tidyverse.quiet = TRUE, dplyr.summarise.inform = FALSE)

source('1_fetch_targets.R')
source('2_process_targets.R')
source('3_visualize_targets.R')
source('4_qc_targets.R')

# Partial list of targets: use this if all you want is the data. You can either
# pick this *or* the list below.
# list(p1_targets_list, p2_targets_list)

# # complete list of targets: use this if you also want some plots. This could take a long time to build.
list(p1_targets_list, p2_targets_list, p3_targets_list, p4_targets_list)


# ==============================================================================
# helper functions
# ==============================================================================
# # you can put these in the console after the pipeline is built to profile 
# print(tar_meta(fields="seconds") |> arrange(-seconds), n = 100)
# tar_visnetwork()




