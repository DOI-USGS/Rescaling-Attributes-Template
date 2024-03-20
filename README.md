![USGS](USGS_ID_black.png)
# National Geospatial Attributes

<img src="figures/doc_motivation.jpg" width="400" alt="Map of a HUC12 catchment where the outlet is the Delaware River Basin above Ranconcas Creek. The smaller NHDPlus catchments are nestled within the catchment except for one small catchment that crosses the HUC12 boundary at the outlet. There are two prominent labels: (1) `We have data here`, which points to the smaller NHDPlus catchments, and (2) `We want data here`, which points to the HUC12 boundary. The map also depicts rivers/streams and uses the World Topo Map as a base map.">

This repo contains a template {targets} pipeline for rescaling attributes to your intended spatial polygons. 

## Motivation 
In WMA, our models and projects work with their own special geospatial boundaries. Often, we find ourselves wanting to use the data processed to a certain polygon, but first, we need that data tied to our polygons. The hard way of doing that is to recreate the initial study, and use our polygons to aggregate data. But an easier way, to get a close estimate of the values we need, is to find the amount of overlap between the two polygons, and rescale those attributes with a simple weighted mean or other aggregation methods that make sense for the data in question.​

This kind of rescaling has happened a few times that I have tried to document them in the table below: 
| Project      | Source Attributes     | Source Polygons | Target Polygons                | Repo Link | Data Release |
| :----------- | :-------------------- | :-------------- | :----------------------------- | :-------- | :----------- |
| HyTest       | NHM-PRMS              |                 |                                |           |              |
| Natl. IWAAs  | Water Use             | WBD ??? HUC12s  | WBD 10-2020 HUC 12 (mainstems) | ?         |              |
| PUMP         | Geospatial Attributes | NHDPlus V2.1    | NHGF V1.1                      |           |              |
| NHGF         | Geospatial Attributes | NHDPlus V2.1    | WBD 10-2020 HUC 12 (mainstems) |           |              |
| RIMBE-WM     | Geospatial Attributes | NHDPlus V2.1    | WBD 10-2020 HUC 12 (mainstems) |           |              |
| RIMBE-SED    | SEDAC                 | County          | WBD 10-2020 HUC 12 (mainstems) |           |              |

Realizing that this is a problem that will keep coming up, and attempting to reduce duplicated workflows, we have decided to make a template pipeline that can take in any source and/or target polygon. 

## Process
The pipeline takes in a set of variables of interest (a subset of the "CAT_[attribute]" in `nhdplusTools::get_characteristics_metadata()`). As of Feb. 2024, the pipeline has only been stress-tested with ~1,254 variables of interest as opposed to the full 14,139 available in the dataset. 

The source and target polygons in the template are the NHDPlusV2 (CONUS plus crude transboundary catchments) and WBD 10-2020 HUC12s (CONUS). The Area of Interest (AOI) is defined as the delaware river basin. We defined this AOI, as opposed to using the national polygons, so as to reduce the computational burden. But the same logic can be applied to national analysis. 

In phase 2, weights are built using `ncdfgeom::calculate_area_intersection_weights()`. The attributes are pulled with `nhdplusTools::get_catchment_characteristics()` and rescaled with basic dplyr functions such as `mutate()`, `group_by()`, and `summarize()`. The formula's below show what we are doing in the process phase. 

![](figures/formulas_gdptools.png)

Phase 3 contains a density plots and choropleth maps built for a one variable of interest to ensure the pipeline is running as intended. Phase 4 contains one map emphasizing areas where the weights should add to one. Caution should be taken in areas where they do not. In addition, we output a flagged version of the weights table where target polygons are flagged if their weights did not add to one. 

![](figures/doc_process.png)


## Outputs
The pipeline produces two main outputs: a weights table and a rescaled attributes table both in `.csv` format under `2_process/out/`.
**Attributes**

![](figures/doc_outputs_att.png)

**Weights**

![](figures/doc_outputs_weights.png)

## How to run the pipeline
#### Package management with [renv](https://rstudio.github.io/renv)
This project uses [renv](https://rstudio.github.io/renv) to manage packages used by the pipeline. Renv works behind the scenes to ensure that the same package versions used by pipeline are used across contributors. When opening the project, renv should, behind the scenes, initiate itself and prompt the user for any additional actions needed. If this is the first time using renv, it may take a little while as specific package versions are downloaded and installed. See [Collaboration in renv](https://rstudio.github.io/renv/articles/renv.html#collaboration) for more information.

## Profiling
The most expensive target to build is intersecting the source polygons with the area of interest taking ~6 min. 

![](figures/tar_meta.PNG)


## SessionInfo()
```
R version 4.3.0 (2023-04-21 ucrt)
Platform: x86_64-w64-mingw32/x64 (64-bit)
Running under: Windows 10 x64 (build 19045)

Matrix products: default


locale:
[1] LC_COLLATE=English_United States.utf8  LC_CTYPE=English_United States.utf8    LC_MONETARY=English_United States.utf8
[4] LC_NUMERIC=C                           LC_TIME=English_United States.utf8    

time zone: America/Chicago
tzcode source: internal

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

other attached packages:
 [1] lubridate_1.9.2 forcats_1.0.0   stringr_1.5.1   dplyr_1.1.2     purrr_1.0.2     readr_2.1.4     tidyr_1.3.1    
 [8] tibble_3.2.1    ggplot2_3.4.2   tidyverse_2.0.0 targets_1.1.3  

loaded via a namespace (and not attached):
 [1] tidyselect_1.2.0   arrow_13.0.0.1     fastmap_1.1.1      digest_0.6.33      fst_0.9.8          base64url_1.4     
 [7] fstcore_0.9.14     timechange_0.2.0   mime_0.12          lifecycle_1.0.4    sf_1.0-13          ellipsis_0.3.2    
[13] processx_3.8.1     magrittr_2.0.3     compiler_4.3.0     rlang_1.1.1        tools_4.3.0        igraph_1.4.3      
[19] utf8_1.2.3         yaml_2.3.7         data.table_1.14.8  knitr_1.43         nhdplusTools_1.0.1 htmlwidgets_1.6.2 
[25] bit_4.0.5          classInt_0.4-9     curl_5.0.1         xml2_1.3.4         abind_1.4-5        KernSmooth_2.23-20
[31] withr_3.0.0        grid_4.3.0         fansi_1.0.4        e1071_1.7-13       colorspace_2.1-0   scales_1.2.1      
[37] cli_3.6.1          generics_0.1.3     rstudioapi_0.14    httr_1.4.7         tzdb_0.4.0         visNetwork_2.1.2  
[43] DBI_1.2.1          pbapply_1.7-0      ncdfgeom_1.2.0     proxy_0.4-27       maps_3.4.1         stars_0.6-4       
[49] assertthat_0.2.1   parallel_4.3.0     vctrs_0.6.5        jsonlite_1.8.5     callr_3.7.3        hms_1.1.3         
[55] bit64_4.0.5        units_0.8-2        glue_1.6.2         RNetCDF_2.7-1      codetools_0.2-19   ps_1.7.5          
[61] stringi_1.8.3      ncmeta_0.3.6       hydroloom_1.0.0    gtable_0.3.4       munsell_0.5.0      pillar_1.9.0      
[67] htmltools_0.5.5    R6_2.5.1           sbtools_1.3.0      backports_1.4.1    class_7.3-21       Rcpp_1.0.10       
[73] zip_2.3.0          xfun_0.39          pkgconfig_2.0.3   
```

## Planning 
Pipeline planning happend in [Mural](https://app.mural.co/t/gswocooeto6166/m/gswocooeto6166/1674664777393/0c9d8beacaa9c442e27bc5fe8112f05e6deaa68b?sender=uc2098797df19e98c2b2f4081). 
![plan](figures/doc_planning.png)


## Contributing
We welcome contributions and suggestions from the community. Please consider 
reporting bugs or asking questions on the [issues page](https://code.usgs.gov/wma/wp/national-geospatial-attributes/-/issues). 
If you have contributions you would like considered for
incorporation into the project you can [fork this repository](https://docs.gitlab.com/ee/user/project/repository/forking_workflow.html#creating-a-fork)
and [submit a merge request](https://docs.gitlab.com/ee/user/project/merge_requests/) for review.

Go here for details on adhering by 
the [USGS Code of Scientific Conduct](https://www.usgs.gov/office-of-science-quality-and-integrity/fundamental-science-practices).
