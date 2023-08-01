library(RSelenium)
library(rvest)
library(tidyverse)
library(lubridate)

#### navigate to analytics page ----

analytics_page <- "https://osf.io/uadxr/analytics"

rD <- rsDriver(browser = "firefox", port = 4545L, verbose = F)
driver <- rD[["client"]]
driver$navigate(analytics_page)
Sys.sleep(15)

#### select past month for data ----

## click on date range button
date_rng_class <- "_date-range-button_1mhar6"
date_btn <- driver$findElement(using = "class", 
                               value = date_rng_class)
date_btn$clickElement()
Sys.sleep(3)

## click on "Past month" option
btns <- driver$findElements(using = "tag name", 
                            value = "button")
btns_text <- unlist(lapply(btns, function(x) {x$getElementText()}))
month_btn <- btns[[which(btns_text == "Past month")]]
month_btn$clickElement()

#### get data from chart ----
html <- driver$getPageSource()[[1]] %>%
    read_html()

charts <- html_elements(html, "._ChartWrapper_1hff7g")
visits_chart_idx <- which(html_elements(charts, "._panel-title_1hff7g") %>%
                              html_text() == "Unique visits")
visits_chart <- charts[visits_chart_idx]

data_points <- html_elements(visits_chart, ".c3-circle")
stopifnot(length(data_points) > 0)
points_x <- html_attr(data_points, "cx")
points_y <- html_attr(data_points, "cy")

x_ticks <- visits_chart %>% 
    html_elements(".c3-axis-x") %>% 
    html_elements(".tick")

x_ticks_pos <- (x_ticks %>% 
                    html_attr("transform") %>%
                    str_match("translate\\((\\d+), 0\\)"))[,2]

x_ticks_dates <- x_ticks %>% 
    html_text() %>%
    parse_date_time("md")

## check for, and correct year if the parsing of month and day used today's year 
##   for last year's dates 
wrong_year_idx <- x_ticks_dates > Sys.Date()
if (any(wrong_year_idx))
{
    x_ticks_dates[wrong_year_idx] <- x_ticks_dates[wrong_year_idx] - years(1)
}

## check for, and remove duplicate x ticks (not sure why this happens)
if (length(x_ticks_pos) > length(unique(x_ticks_pos)))
{
    idx <- seq_along(unique(x_ticks_pos))
    x_ticks_pos <- x_ticks_pos[idx]
    x_ticks_dates <- x_ticks_dates[idx]
}

y_ticks <- visits_chart %>% 
    html_elements(".c3-axis-y") %>% 
    html_elements(".tick")

y_ticks_pos <- (y_ticks %>% 
                    html_attr("transform") %>%
                    str_match("translate\\(0,(\\d+)\\)"))[,2] %>%
    as.numeric()

y_ticks_val <- y_ticks %>% 
    html_text() %>%
    as.numeric()

stopifnot(all(points_x %in% x_ticks_pos))
dat <- data.frame(x = points_x, y = points_y) %>%
    left_join(data.frame(x = x_ticks_pos, date = x_ticks_dates))

y_scale <- lm(y_ticks_val ~ y_ticks_pos)
dat$visits <- round(predict(y_scale, 
                            data.frame(y_ticks_pos = as.numeric(points_y))))

#### save visits data to file ----
dat %>%
    select(date, visits) %>%
    write.csv(paste0("visits_", Sys.Date(), ".csv"), 
              row.names = FALSE, quote = FALSE)

