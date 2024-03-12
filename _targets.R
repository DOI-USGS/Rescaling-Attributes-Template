# ==============================================================================
# installations
# ==============================================================================
# install.packages("targets")
# remotes::install_github("doi-usgs/ncdfgeom)
# remotes::install_github("doi-usgs/nhdplusTools) 

## if there are problems with the functions in nhdplusTools try running this 
## it clears and re-downloads the metadata index of all the characteristics
# nhdplusTools::get_characteristics_metadata(cache = FALSE)


## authenticate ScienceBase if needed
# initialize_sciencebase_session(username = "blah@usgs.gov") 


## container considerations
## to run the pipeline from within the container, we need to set the nhdplusTools data dir so we can retrieve characteristics metadata
# nhdplusTools::nhdplusTools_data_dir("1_fetch/out")



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
    "ggmap", "cowplot", "scico", "viridis"
    
    # phase 4_qc
    ), 
  format = "rds"
)

# suppress package warnings
options(tidyverse.quiet = TRUE)
options(dplyr.summarise.inform = FALSE)

source('1_fetch_targets.R')
source('2_process_targets.R')
source('3_visualize_targets.R')
source('4_qc_targets.R')

# partial list of targets: use this if all you want is the data
list(p1_targets_list, p2_targets_list)

# # complete list of targets: use this if you also want some plots 
# # this could take a long time to build and plots will only work for the the data in this template pipeline
# list(p1_targets_list, p2_targets_list, p3_targets_list, p4_targets_list)


# ==============================================================================
# helper functions
# ==============================================================================
## you can put these in the console after the pipeline is built 
# print(tar_meta(fields="seconds"), n = 50)
# print(tar_meta(fields="seconds") |> arrange(-seconds), n = 100)

# tar_visnetwork()




