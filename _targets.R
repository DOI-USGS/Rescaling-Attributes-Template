# This code uses a pipelining package called targets. We assume you have some
# basic familiarity with it and proficiency in R. If you need help contact
# Ellie White (ewhite@usgs.gov)


# ==============================================================================
# Installations
# ==============================================================================
# You can install these packages by copy-pasting the code here in the R console. 
# Make sure the code in this section stays commented out. 
# When you are done installing packages you will simply run tar_make() in the 
# R console. 

# install.packages("targets")

# As of 03/14/2024, you must install the developer version on ncdfgeom. The CRAN
# version does not include the required normalize argument in one of its 
# functions. 
# remotes::install_github("doi-usgs/ncdfgeom")

# install.packages("doi-usgs/nhdplusTools") 

# If there are problems with the functions in nhdplusTools try running this. It
# clears and re-downloads the metadata index of all the characteristics.
# nhdplusTools::get_characteristics_metadata(cache = FALSE)


# Authenticate ScienceBase if needed for your datasets. The ones in our template
# won't need it.
# remotes::install_github("doi-usgs/sbtools)
# initialize_sciencebase_session(username = "blah@usgs.gov") 


# ==============================================================================
# Main target script for calling all subsequent targets
# ==============================================================================
library(targets)
library(tarchetypes)

# Ensure packages are synched with renv lockfile
if(!renv::status()$synchronized){
  renv::restore(rebuild = FALSE, clean = TRUE, prompt = FALSE)
}

# Target options
tar_option_set(
  packages = c(
    # phase 1_fetch
    "tidyverse", "nhdplusTools", "sf", "sbtools", "aws.s3", 
    
    # phase 2_process, "areal" is a dependency that needs to be downloaded 
    "ncdfgeom", "mapdata", "maps", "data.table", "stringr", "assertthat", "cli", 
    
    # phase 3_visualize
    "ggmap", "scico", "viridis"
    
    # phase 4_qc
    ), 
  format = "rds"
)

# Suppress package warnings
options(tidyverse.quiet = TRUE, dplyr.summarise.inform = FALSE)

source('1_fetch_targets.R')
source('2_process_targets.R')
source('3_visualize_targets.R')
source('4_qc_targets.R')

# Partial list of targets
# Use this if all you want is the data. You can either pick this *or* the list 
# below.
# list(p1_targets_list, p2_targets_list)

# Complete list of targets
# Use this if you also want some plots. This could take a long time to build.
list(p1_targets_list, p2_targets_list, p3_targets_list, p4_targets_list)


# ==============================================================================
# Helper functions
# ==============================================================================
# You can put these in the console after the pipeline is built to profile 
# print(tar_meta(fields="seconds") |> arrange(-seconds), n = 100)
# tar_visnetwork()
