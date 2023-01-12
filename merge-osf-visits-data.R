library(tidyverse)

#### identify individual data files ----
data_files <- list.files(pattern = "visits_\\d{4}-\\d{2}-\\d{2}\\.csv")

#### read in and combine data from individual data files ----
# note: we take the maximum value of visits on each date when resolving 
#  conflicts. This is because visits may be incomplete for the current day when 
#  obtaining new data AND because visits for the oldest day seem to be cut off 
#  by the time of collection when obtaining new data.
#  e.g. for data collected on Jan 12 / noon:
#    * visits for Jan 12 are incomplete and are thus undercounted
#    * visits for Dec 12 don't extend before Dec 12 / noon and are thus undercounted

dat <- data_files %>%
    map_dfr(read.csv) %>%
    distinct() %>%
    group_by(date) %>%
    summarize(visits = max(visits))

#### write out combined visits data ----
dat %>%
    write.csv(paste0("visits_combined.csv"), 
              row.names = FALSE, quote = FALSE)