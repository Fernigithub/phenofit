phenonames <- c('TRS2.SOS', 'TRS2.EOS', 'TRS5.SOS', 'TRS5.EOS', 'TRS6.SOS', 'TRS6.EOS',
    'DER.SOS', 'DER.POP', 'DER.EOS',
    'UD', 'SD', 'DD','RD',
    'GreenUp', 'Maturity', 'Senescence', 'Dormancy')

#' Fine curve fitting
#'
#' Curve fit vegetation index (VI) time-series of every growing season using 
#' fine curve fitting methods.
#'
#' @param y Vegetation time-series index, numeric vector
#' @param t The corresponding doy of x
#' @param tout The output interpolated time.
#' @param methods Fine curve fitting methods, can be one or more of \code{c('AG', 
#' 'Beck', 'Elmore', 'Gu', 'Klos', 'Zhang')}. 
#' @param ... other parameters passed to curve fitting function.
#' 
#' @note 'Klos' have too many parameters. It will be slow and not stable.
#' 
#' @return fFITs S3 object, see \code{\link{fFITs}} for details.
#' 
#' @seealso \code{\link{fFITs}}, 
#' \code{\link{FitAG}}, \code{\link{FitDL.Beck}}, 
#' \code{\link{FitDL.Elmore}}, \code{\link{FitDL.Gu}}, 
#' \code{\link{FitDL.Klos}}, \code{\link{FitDL.Zhang}}
#' 
#' @examples
#' library(phenofit)
#' # simulate vegetation time-series
#' fFUN = doubleLog.Beck
#' par  = c(
#'     mn  = 0.1,
#'     mx  = 0.7,
#'     sos = 50,
#'     rsp = 0.1,
#'     eos = 250,
#'     rau = 0.1)
#' t    <- seq(1, 365, 8)
#' tout <- seq(1, 365, 1)
#' y <- fFUN(par, t)
#' 
#' methods <- c("AG", "Beck", "Elmore", "Gu", "Zhang") # "Klos" too slow
#' fFITs <- curvefit(y, t, tout, methods)
#' @export
curvefit <- function(y, t = index(y), tout = t, 
    methods = c('AG', 'Beck', 'Elmore', 'Gu', 'Klos', 'Zhang'), ...)
{
    if (all(is.na(y))) return(NULL)
    if (length(methods) == 1 && methods == 'all')
        methods <- c('AG', 'Beck', 'Elmore', 'Gu', 'Klos', 'Zhang')

    params <- list(y, t, tout, optimFUN = I_optim, ...)

    # if ('spline' %in% methods) fit.spline <- splinefit(y, t, tout)
    if ('AG'     %in% methods) fit.AG     <- do.call(FitAG,       c(params, method = "nlminb"))  #nlm
    if ('Beck'   %in% methods) fit.Beck   <- do.call(FitDL.Beck,  c(params, method = "nlminb"))  #nlminb
    if ('Elmore' %in% methods) fit.Elmore <- do.call(FitDL.Elmore,c(params, method = "nlminb"))  #nlminb

    # best: BFGS, but its speed lower than other function, i.e. nlm
    if ('Gu'     %in% methods) fit.Gu     <- do.call(FitDL.Gu,    c(params, method = "nlminb"))  #nlm, ucminf
    if ('Klos'   %in% methods) fit.Klos   <- do.call(FitDL.Klos,  c(params, method = "BFGS"))    #BFGS, Nelder-Mead, L-BFGS-B
    if ('Zhang'  %in% methods) fit.Zhang  <- do.call(FitDL.Zhang, c(params, method = "nlminb"))  #nlm

    names <- ls(pattern = "fit\\.") %>% set_names(., .)
    fFITs <- lapply(names, get, envir = environment()) %>%
        set_names(toupper(gsub("fit\\.", "", names))) #remove `fit.` and update names

    structure(list(data = data.table(y, t), tout = tout, fFIT = fFITs), 
        class = 'fFITs')
}
