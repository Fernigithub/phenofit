# source('main_phenofit.R')
suppressMessages({
    library(phenofit)
    library(shiny)
    # library(DT)
    library(data.table)
    library(magrittr)

    library(plyr)
    library(purrr)
})

# load('data/phenoflux115_ET&GPP&VI.rda')
# load('inst/shiny/check_season/data/phenoflux_115.rda')
# load('inst/shiny/check_season/data/ET&GPP&VI_flux115.rda')
# sites <- sort(sites)

#' Generate DT::datatable
DT_datatable <- function(
    df,
    pageLength = 10,
    columnDefs = list(list(className = 'dt-center')), ...){

    DT::datatable(df, options = list(
        # autoWidth = TRUE,
        # columnDefs = list(list(width = '10px', targets = c(4:10)))
        searching = FALSE, lengthChange = FALSE,
        pageLength = pageLength,
        columnDefs = columnDefs, ...
    ))
}

#' check_file
#' Check file whether exist. If not, then give a notification.
check_file <- function(file, duration = 10){
    filename <- deparse(substitute(file))
    if (is.null(file)) file <- "NULL"

    if (file.exists(file)) {
        TRUE
    } else {
        showNotification(sprintf("invalid %s: %s", filename, file),
                         duration = duration, type = "warning")
        FALSE
    }
}

#' Make sure date character in \code{df} has been converted to \code{Date} object.
check_datestr <- function(df){
    var_times <-  intersect(c("t", "date"), colnames(df))
    for (i in seq_along(var_times)){
        varname <- var_times[i]
        df[[varname]] %<>% lubridate::ymd()
    }
    df
}

#' update all INPUT data according to \code{input} file.
updateINPUT <- function(input){
    status <- FALSE
    if (input$file_type == '.rda | .RData') {
        file_rda  <- input$file_rda$datapath
        if (check_file(file_rda)) {
            load(file_rda)
            check_datestr(df)
            status <- TRUE
        }
    } else if (input$file_type == 'text'){
        file_site <- input$file_site$datapath
        file_veg  <- input$file_veg$datapath

        if (check_file(file_veg)) {
            df    <<- fread(file_veg)
            check_datestr(df)
            sites <<- unique(df$site) %>% sort()

            if (check_file(file_site)){
                st <<- fread(file_site)
            } else {
                st <<- data.table(ID = seq_along(sites), site = sites, lat = 30)
            }
            status <- TRUE
        }
    }
    # list(df = df, st = st, sites = sites)
    return(status)
}

#' update vegetation index variable Y in df
#'
#' @param rv reactiveValues.
#' @param varname variable name of vegetation index.
update_VI <- function(rv, varname){
    # varname <- input$txt_varVI

    print('\t update_VI ...')
    if (!is.null(varname) && !(varname %in% c("", "y"))) {
        eval(parse(text = sprintf('rv$df$y <- rv$df$%s', varname)))
    }
}

#' convert_QC2weight
convert_QC2weight <- function(input){
    qcFUN <- input$qcFUN
    varQC <- input$txt_varQC

    if (varQC %in% colnames(df)){
        warning(sprintf("No QC variable %s in df! ", varQC))
    }

    if (input$check_QC2weight && varQC %in% colnames(df)){
        eval(parse(text = sprintf('df[, c("w", "QC_flag") := %s(%s, wmin = 0.2)]',
            qcFUN, varQC)))
    }
}

################################################################################
#' getDf.site
#' 
#' Select the data of specific site. Only those variables 
#' \code{c('t', 'y', 'w')} selected.
getDf.site  <- function(df, sitename, dateRange){
    d <- dplyr::select(df[site == sitename, ], dplyr::matches("t|y|w|QC_flag"))
    # if has no \code{QC_flag}, it will be generated by \code{w}.

    # filter dateRange
    if (!missing(dateRange)){
        bandname <- intersect(c("t", "date"), colnames(d))[1]
        dates    <- d[[bandname]]
        I <- dates >= dateRange[1] & dates <= dateRange[2]
        d <- d[I, ]
    }
    d
    #%T>% plot_input(365)
}

getINPUT.site <- function(df, st, sitename, dateRange){
    sp       <- st[site == sitename]
    south    <- sp$lat < 0
    IGBP     <- sp$IGBP %>% {ifelse(is.null(.), "", .)}

    titlestr <- sprintf("[%s] IGBP=%s, lat = %.2f", sp$site, IGBP, sp$lat)

    d <- getDf.site(df, sitename, dateRange)
    d_new <- add_HeadTail(d, south = south, nptperyear)
    INPUT <- do.call(check_input, d_new)

    INPUT$south    <- south
    INPUT$titlestr <- titlestr
    # list(INPUT = INPUT, plotdat = d)
    INPUT
}

#' Cal growing season dividing information
#'
#' @param input Shiny \code{input} variable
#' @param INPUT An object returned by \code{check_season}
#'
cal_season <- function(input, INPUT){
    param <- list(
        FUN_season     = input$FUN_season,
        rFUN           = input$rFUN,
        iters          = input$iters,
        lambda         = input$lambda,
        nf             = input$nf,
        frame          = input$frame,
        wFUN           = input$wFUN,
        maxExtendMonth = input$maxExtendMonth,
        rytrough_max   = input$rytrough_max,
        threshold_max  = input$threshold_max,
        threshold_min  = input$threshold_min
    )
    # param <- lapply(varnames, function(var) input[[var]])
    param <- c(list(INPUT = INPUT), param)
    # print(str(param))
    do.call(check_season, param) # brk return
}

check_season <- function(INPUT,
                         FUN_season = c("season", "season_3y"),
                         rFUN = "wWHIT",
                         wFUN = "wTSM",
                         lambda = 1000,
                         iters = 3,
                         IsPlot = F, ...) {
    # sitename <- "US-ARM" # "FR-LBr", "ZA-Kru", "US-ARM"

    FUN_season <- get(FUN_season[1])
    wFUN       <- get(wFUN)

    res  <- FUN_season(INPUT,
                     rFUN = get(rFUN),
                     wFUN = wFUN,
                     IsPlot = IsPlot,
                     IsPlot.OnlyBad = FALSE,                     
                     lambda = lambda,
                     iters = iters,
                     MaxPeaksPerYear = 3,
                     MaxTroughsPerYear = 4,
                     ...,
                     # caution about the following parameters
                     minpeakdistance = nptperyear/6,
                     ypeak_min = 0
    )

    if (IsPlot){
        abline(h = 1, col = "red")
        title(INPUT$titlestr)
    }
    return(res)
}

phenofit_all <- function(input, progress = NULL){
    n   <- length(sites)
    res <- list()

    # parameters for Fine Fitting
    params_fineFitting <- list(
        methods      = input$FUN, #c("AG", "zhang", "beck", "elmore", 'Gu'), #,"klos",
        # debug        = FALSE,
        wFUN         = get(input$wFUN2),
        nextent      = 2,
        maxExtendMonth = 3,
        minExtendMonth = 1,
        QC_flag        = NULL,
        minPercValid = 0.2,
        print        = TRUE
    )

    showProgress <- !is.null(progress)
    if (showProgress){
        on.exit(progress$close())
        progress$set(message = sprintf("phenofit (n=%d) | running ", n), value = 0)
    }

    # print('debug 1 ...')
    # browser()

    for (i in 1:n){
        # tryCatch({
        # }, error = function(e){
        # })
        if (showProgress){
            progress$set(i, detail = paste("Doing part", i))
        }
        fprintf("phenofit (n = %d) | running %03d ... \n", i, n)

        sitename <- sites[i]
        INPUT    <- getINPUT.site(df, st, sitename)

        # Rough Fitting and gs dividing
        brks   <- cal_season(input, INPUT)

        params <- c(list(INPUT = INPUT, brks = brks), params_fineFitting)
        fit    <- do.call(curvefits, params)

        # Good of fitting of Fine Fitting
        stat <- ldply(fit, GOF_fFITs, .id = "flag") %>% data.table()

        # Phenological Metrics
        pheno <- PhenoExtract(fit)

        ans   <- list(fit = fit, INPUT = INPUT, seasons = brks, stat = stat, pheno = pheno)
        ############################# CALCULATION FINISHED #####################
        res[[i]] <- ans
    }
    set_names(res, sites)
}

# plot_data <- function(d, title){
#     par(setting)
#     do.call(check_input, d) %>% plot_input()
#     mtext(title, side = 2, line = 2, cex = 1.3, font = 2)
# }

################################################################################
# https://stackoverflow.com/questions/48592842/show-inf-in-dtdatatable
options(
    htmlwidgets.TOJSON_ARGS = list(na = 'string'),
    shiny.maxRequestSize=30*1024^2
)
