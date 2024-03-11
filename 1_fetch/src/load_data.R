#' @title Download national geospatial fabric
#' 
#' @description 
#' Downloads the national geospatial fabric from ScienceBase.
#' 
#' @details 
#' This function has been adapted from Lauren Koenig's work on national-network-prep (https://code.usgs.gov/wma/wp/national-network-prep/-/tree/main/)
#' which was also adapted from work in the Delaware River Basin: 
#' https://github.com/USGS-R/delaware-model-prep/blob/main/1_network/src/get_national_gf.R
#'
#' @param sb_id character string indicating the ScienceBase identifier
#' @param sb_name string vector of file names attached to the ScienceBase item of interest
#' @param out_dir directory to save the downloaded GF files 
#'
#' @examples 
#' get_geospatial_fabric(out_dir = "1_fetch/out/", 
#'                       sb_id = '5362b683e4b0c409c6289bf6', 
#'                       sb_name = 'GeospatialFabricFeatures_01.gdb')
#'
get_geospatial_fabric <- function(sb_id, sb_name, out_dir) {
  
  # check against out_dir, if already present, don't download if not needed
  if(grepl(".zip", sb_name)){
    out_file <- tools::file_path_sans_ext(sb_name)
    if(!grepl(".gdb",out_file)){
      out_file <- paste0(out_file,".gdb")
    }
  } else {
    out_file <- sb_name
  }
  out_path <- paste0(out_dir,out_file)
  
  # if the data don't yet exist, download and unzip
  if(!out_file %in% list.files(out_dir)) {
    temp_loc <- tempfile()
    sbtools::item_file_download(sb_id = sb_id, 
                                names = sb_name, 
                                destinations = temp_loc,
                                overwrite_file = TRUE)
    if(dir.exists(out_path)) unlink(out_file, recursive = TRUE)
    unzip(temp_loc, exdir = dirname(out_path))
  } else {
    message('GF is already downloaded; doing nothing')
  }

  return(out_path)
}


#' Given a ScienceBase item ID, download all files associated with the item to a local directory (create the directory if it doesn't exist). 
#'
#' @param sb_id A character string specifying the ScienceBase item ID.
#' @param dest_dir A character string specifying the local directory to download the files to. Defaults to the current working directory.
#' @param overwrite A logical value indicating whether to overwrite existing files. Defaults to FALSE.
#'
#' @return A character vector of the file paths for the downloaded files.
#'
#' @importFrom sbtools download_item_files
#'
#' @examples
#' download_sb_files("4f4e4a38e4b07f02db61cebb")
#' 
download_sb_files <- function(sb_id, dest_dir, overwrite = FALSE) {
  if (!file.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE)
  }
  
  sb_item <- sbtools::item_get(sb_id)
  if (is.null(sb_item)) {
    stop('Invalid ScienceBase item ID.')
  }
  
  sb_files <- sbtools::item_list_files(sb_id)
  for (f in seq_along(sb_files$fname)) {
    file <- sb_files[f, ]
    file_url <- file$url
    file_name <- file$fname
    dest_file <- file.path(dest_dir, file_name)
    
    if (!file.exists(file.path(dest_dir, file_name))) {
      message(paste0("Downloading file: ", file_name, " to: ", dest_file, "!"))
      download.file(file_url, dest_file, mode = "wb")
    } else {
      message(paste("File", dest_file, "already exists. Skipping download."))
    }
  }
  return(sb_files)
}


#' Download a file from Amazon S3 in chunks, WBD dataset was timing out
#'
#' @param bucket The name of the S3 bucket.
#' @param folder The path to the folder containing the object.
#' @param object The name of the object to download.
#' @param destfile The name of the file to save the downloaded object to.
#' @param access_key_id Your AWS access key ID.
#' @param secret_access_key Your AWS secret access key.
#' @param chunk_size The size of each download chunk in bytes.
#' @param timeout The timeout in seconds for each download chunk request.
#' 
#' @return The path to the downloaded file.
#'
#' @examples
#' download_in_chunks(bucket = "my-s3-bucket",
#'                    folder = "path/to/folder/",
#'                    object = "my-object.zip",
#'                    destfile = "1_fetch/out/my-object.zip",
#'                    access_key_id = "MY_ACCESS_KEY_ID",
#'                    secret_access_key = "MY_SECRET_ACCESS_KEY")
download_in_chunks <- function(bucket, folder, object, destfile,
                               access_key_id = NULL, secret_access_key = NULL,
                               chunk_size = 1024^2, timeout = 120) {
  
  if (file.exists(destfile)) {
    message(paste("File", destfile, "already exists. Skipping download."))
    return(NULL)
  }
  
  require(aws.s3)
  require(httr)
  
  # # Create s3 object
  # s3 <- aws.s3::s3(access_key_id = access_key_id,
  #                  secret_access_key = secret_access_key)
  
  # Construct URL
  url <- paste0("https://", bucket, ".s3.amazonaws.com/", folder, object)
  
  # Create empty file
  file.create(destfile)
  
  # Open connection
  con <- file(destfile, "wb")
  
  # Download file in chunks
  skip <- 0
  while(TRUE) {
    res <- httr::GET(url,
                     add_headers("Range" = paste0("bytes=", skip, "-", skip + chunk_size - 1)),
                     timeout(timeout))
    if(res$status_code == 200) {
      # End of file
      break
    }
    else if(res$status_code == 206) {
      # Partial content
      writeBin(content(res, as = "raw"), con)
      skip <- skip + chunk_size
    }
    else {
      # Error
      stop("Failed to download file: ", res$status_code, " ", res$status_message)
    }
  }
  
  # Close connection
  close(con)
  
  # Unzip file if it's a zip file
  if (tools::file_ext(destfile) == "zip") {
    unzip(destfile)
  }
  
  # Return path to downloaded file
  return(destfile)
}


