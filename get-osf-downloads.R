library(osfr)
library(tidyverse)

get_osf_files <- function(proj, path = NULL)
{
    files <- osf_ls_files(proj, path = path, type = "file")
    folders <- osf_ls_files(proj, path = path, type = "folder")
    
    if (NROW(folders) == 0)
    {
        return(files)
    }
    
    # recurse into folders
    if (is.null(path))
    {
        path <- ""
    } else {
        path <- paste0(path, "/")
    }
    bind_rows(
        files, 
        map_dfr(folders$name, function(new_path) {
            get_osf_files(proj, paste0(path, new_path))})
    )
}

#### setup ----
if (Sys.getenv("OSF_PAT") == "")
{
    warning("You may want to visit https://docs.ropensci.org/osfr/articles/auth.html for instructions on setting up an OSF personal access token.")
}

proj <- osf_retrieve_node("uadxr")

#### get complete listing of files and download counts ----
dat <- get_osf_files(proj) %>%
    mutate(downloads = 
vapply(dat$meta, function(x) {x$attributes$extra$downloads}, 0))

#### save downloads data to file ----
dat %>%
    select(name, downloads, id) %>%
    write.csv(paste0("downloads_", Sys.Date(), ".csv"), 
              row.names = FALSE, quote = FALSE)
