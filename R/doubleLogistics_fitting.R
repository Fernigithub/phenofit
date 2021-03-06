# #' using cubic spline function to avoid the difficult in setting parameter
# #' lambda in smooth.spline
# #'
# #' cubic spline is inappropriate for daily inputs. Its smooth is not enough.
# #' On the contrary, smooth.spline with a low freedom can smooth well.
# #'
# #' @export
# splinefit <- function(y, t = index(y), tout = t, plot = FALSE, df.factor = 0.06, ...){
#     # xpred.out <- spline(t, y, xout = tout)$y %>% zoo(., tout)
#     n <- length(y)
#     # if n < 40, means y was satellite VI
#     # if n > 40, means daily data
#     df.factor <- ifelse (n <= 46, 1/3, df.factor)
#     freedom   <- pmax(df.factor * n, 15)
#     fit       <- smooth.spline(t, y, df = freedom)
#     xpred.out <- predict(fit, tout)$y %>% zoo(., tout)
#     structure(list(data = list(y = y, t = t),
#         pred = xpred.out, par = NULL, fun = NULL), class = "phenofit")
# }

#' @name FitDL
#' @title Fine curve fitting functions.
#' 
#' @description Fine curve fitting functions, e.g. double logistics, Asymmetric 
#' Gaussian. They are used to fit vegetation time-series in every growing season.
#'
#' @param y input vegetation index time-series.
#' @param t the corresponding doy(day of year) of y.
#' @param tout the output curve fitting time-series time steps.
#' @param optimFUN optimization function to solve curve fitting functions'
#' parameters. It's should be `optimx_fun`, or `optim_p`.
#' @param method method passed to `optimx` or `optim` function.
#' @param w weights
#' @param ... other paraters passed to optimFUN, such as weights.
#'
#' @return list(pred, par, fun)
#' @references
#' [1]. Beck, P.S.A., Atzberger, C., Hogda, K.A., Johansen, B., Skidmore, A.K.,
#'      2006. Improved monitoring of vegetation dynamics at very high latitudes:
#'      A new method using MODIS NDVI. Remote Sens. Environ.
#'      https://doi.org/10.1016/j.rse.2005.10.021.
NULL

#' @rdname FitDL
#' @export
FitDL.Zhang <- function(y, t = index(y), tout = t, 
    optimFUN = I_optimx, method = 'nlm', w, ...)
{
    if (missing(w)) w <- rep(1, length(y))
    e <- init_param(y, t, w)

    sFUN    <- "doubleLog.Zhang"
    prior  <- with(e, rbind(
        c(doy.mx   , mn, mx, doy[1]   , k  , doy[2]   , k  ),
        c(doy.mx   , mn, mx, doy[1]+t1, k*2, doy[2]-t1, k*2),
        c(doy.mx   , mn, mx, doy[1]-t1, k/2, doy[2]+t2, k/2)))

    param_lims <- e$lims[c('t0', 'mn', 'mx', 'sos', 'r', 'eos', 'r')]
    # param_lims$r[2] %<>% multiply_by(2)
    lower  <- sapply(param_lims, `[`, 1)
    upper  <- sapply(param_lims, `[`, 2)

    # lower[["r"]] %>% multiply_by(1/3)
    # upper[["r"]] %>% multiply_by(3)
    # browser()
    optim_pheno(prior, sFUN, y, t, tout, optimFUN, method, w, lower = lower, upper = upper, ...)
}

#' @rdname FitDL
#' @export
FitAG <- function(y, t = index(y), tout = t, 
    optimFUN = I_optimx, method = 'nlminb', w, ...)
{
    if (missing(w)) w <- rep(1, length(y))
    e <- init_param(y, t, w)
    # print(ls.str(envir = e))

    sFUN <- "doubleAG"
    prior <- with(e, rbind(
        c(doy.mx, mn, mx, 1/half    , 2, 1/half, 2),
        # c(doy.mx, mn, mx, 0.2*half, 1  , 0.2*half, 1),
        # c(doy.mx, mn, mx, 0.5*half, 1.5, 0.5*half, 1.5),
        c(doy.mx, mn, mx, 1/(0.8*half), 3, 1/(0.8*half), 3)))
    # referenced by TIMESAT
    lower  <- with(e$lims, c(t0[1], mn[1], mx[1], 1/(1.4*e$half), 2, 1/(1.4*e$half), 2))
    upper  <- with(e$lims, c(t0[2], mn[2], mx[2], 1/(0.1*e$half), 6, 1/(0.1*e$half), 6))

    optim_pheno(prior, sFUN, y, t, tout, optimFUN, method, w, lower = lower, upper = upper, ...)
}

#' @rdname FitDL
#' @export
FitDL.Beck <- function(y, t = index(y), tout = t, 
    optimFUN = I_optimx, method = 'nlminb', w, ...)
{
    if (missing(w)) w <- rep(1, length(y))
    e <- init_param(y, t, w)

    sFUN   <- "doubleLog.Beck"
    prior <- with(e, rbind(
        c(mn, mx, doy[1]   , k  , doy[2]   , k  ),
        c(mn, mx, doy[1]+t1, k*2, doy[2]-t2, k*2)))

    param_lims <- e$lims[c('mn', 'mx', 'sos', 'r', 'eos', 'r')]
    lower  <- sapply(param_lims, `[`, 1)
    upper  <- sapply(param_lims, `[`, 2)

    optim_pheno(prior, sFUN, y, t, tout, optimFUN, method, w, lower = lower, upper = upper, ...)
}
# mn + (mx - mn)*(1/(1 + exp(-rsp*(t - sos))) + 1/(1 + exp(rau*(t - eos))))
# attr(doubleLog.Beck, 'par') <- c("mn", "mx", "sos", "rsp", "eos", "rau")
# attr(doubleLog.Beck, 'formula') <- expression(mn + (mx - mn)*(1/(1 + exp(-rsp*(t - sos))) + 1/(1 + exp(rau*(t - eos)))))

#' @references
#' [2]. Elmore, A.J., Guinn, S.M., Minsley, B.J., Richardson, A.D., 2012.
#'      Landscape controls on the timing of spring, autumn, and growing season
#'      length in mid-Atlantic forests. Glob. Chang. Biol. 18, 656-674.
#'      https://doi.org/10.1111/j.1365-2486.2011.02521.x. \cr
#' @rdname FitDL
#' @export
FitDL.Elmore <- function(y, t = index(y), tout = t, 
    optimFUN = I_optimx, method = 'nlminb', w, ...) 
{
    e <- init_param(y, t, w)

    # doy_q  <- quantile(t, c(0.1, 0.25, 0.5, 0.75, 0.9), na.rm = TRUE)
    sFUN   <- "doubleLog.Elmore"
    prior <- with(e, rbind(
        c(mn, mx - mn, doy[1]+t1, k*2.5  , doy[2]-t2, k*2.5  , 0.002),
        c(mn, mx - mn, doy[1]   , k*1.25 , doy[2]   , k*1.25 , 0.002),
        c(mn, mx - mn, doy[1]   , k*0.5  , doy[2]   , k*0.5  , 0.05),
        c(mn, mx - mn, doy[1]-t1, k*0.25 , doy[2]+t2, k*0.25, 0.1)))
    # xpred <- m1 + (m2 - m7*t)*((1/(1 + exp((m3l - t)/m4l))) - (1/(1 + exp((m5l - t)/m6l))))
    param_lims <- e$lims[c('mn', 'mx', 'sos', 'r', 'eos', 'r')]
    lower  <- c(sapply(param_lims, `[`, 1), 0  )
    upper  <- c(sapply(param_lims, `[`, 2), Inf)

    optim_pheno(prior, sFUN, y, t, tout, optimFUN, method, w, lower = lower, upper = upper, ...)
}

# c(mn, mx - mn, doy[2], half*0.1, doy[4], half*0.1, 0.002),
# c(mn, mx - mn, doy[2], half*0.2, doy[5], half*0.2, 0.002),
# c(mn, mx - mn, doy[1], half*0.5, doy[4], half*0.5, 0.05),
# c(mn, mx - mn, doy[1], half*0.8, doy[5], half*0.8, 0.1))

# attr(doubleLog.Elmore, 'name')    <- 'doubleLog.Elmore'
# attr(doubleLog.Elmore, 'par')     <- c("mn", "mx", "sos", "rsp", "eos", "rau", "m7")
# attr(doubleLog.Elmore, 'formula') <- expression( mn + (mx - m7*t)*( 1/(1 + exp(-rsp*(t-sos))) - 1/(1 + exp(-rau*(t-eos))) ) )

#' @references
#' [3]. Gu, L., Post, W.M., Baldocchi, D.D., Black, TRUE.A., Suyker, A.E., Verma,
#'      S.B., Vesala, TRUE., Wofsy, S.C., 2009. Characterizing the Seasonal Dynamics
#'      of Plant Community Photosynthesis Across a Range of Vegetation Types,
#'      in: Noormets, A. (Ed.), Phenology of Ecosystem Processes: Applications
#'      in Global Change Research. Springer New York, New York, NY, pp. 35-58.
#'      https://doi.org/10.1007/978-1-4419-0026-5_2. \cr
#'
#' [4]. https://github.com/kongdd/phenopix/blob/master/R/FitDoubleLogGu.R
#'
#' @rdname FitDL
#' @export
FitDL.Gu <- function(y, t = index(y), tout = t, 
    optimFUN = I_optimx, method = "nlminb", w, ...)
{
    if (missing(w)) w <- rep(1, length(y))
    e <- init_param(y, t, w)

    a  <- e$ampl
    b1 <- 0.1
    b2 <- 0.1
    c1 <- 1
    c2 <- 1

    sFUN  <- "doubleLog.Gu"
    prior <- with(e, rbind(
        c(mn, a, a, doy[1]-t1, k/2 , doy[2]+t2, k/2, 1  , 1),
        c(mn, a, a, doy[1]   , k   , doy[2]   , k  , 2  , 2),
        c(mn, a, a, doy[1]   , k*2 , doy[2]   , k*2, 3  , 3),
        c(mn, a, a, doy[1]+t1, k*2 , doy[2]-t2, k*2, 0.5, 0.5),
        c(mn, a, a, doy[1]+t1, k*3 , doy[2]-t2, k*3, 5  , 5)))
    # y0 + (a1/(1 + exp(-(t - t1)/b1))^c1) - (a2/(1 + exp(-(t - t2)/b2))^c2)

    param_lims <- e$lims[c('mn', 'mx', 'mx', 'sos', 'r', 'eos', 'r')]
    lower  <- c(sapply(param_lims, `[`, 1), 0  , 0)
    upper  <- c(sapply(param_lims, `[`, 2), Inf, Inf)

    optim_pheno(prior, sFUN, y, t, tout, optimFUN, method, w, lower = lower, upper = upper, ...)
}

#' @rdname FitDL
#' @export
FitDL.Klos <- function(y, t = index(y), tout = t, 
    optimFUN = I_optimx, method = 'BFGS', w, ...)
{
    if (missing(w)) w <- rep(1, length(y))
    e <- init_param(y, t, w)

    a1 <- 0
    a2 <- 0  #ok
    b1 <- e$mn #ok
    b2 <- 0  #ok
    c  <- 0.2 * max(y)  # ok
    ## very slightly smoothed spline to get reliable maximum
    # tmp <- smooth.spline(y, df = 0.5 * length(y))#, find error: 20161104, fix tomorrow

    prior <- with(e, {
        B1 <- 4/(doy.mx - doy[1])
        B2 <- 3.2/(doy[2] - doy.mx)
        m1 <- doy[1] + 0.5 * (doy.mx - doy[1])
        m2 <- doy.mx + 0.5 * (doy[2] - doy.mx)
        m1.bis <- doy[1]
        m2.bis <- doy[2]
        q1 <- 0.5  # ok
        q2 <- 0.5  # ok
        v1 <- 2    # ok
        v2 <- 2    # ok    

        rbind(
        c(a1, a2, b1, b2, c, B1, B2, m1, m2, q1, q2, v1, v2),
        c(a1, a2, b1, 0.01, 0, B1, B2, m1, m2.bis, q1, 1, v1, 4),
        c(a1, a2, b1, b2, c, B1, B2, m1.bis, m2, q1, q2, v1, v2),
        c(a1, a2, b1, b2, c, B1, B2, m1, m2.bis, q1, q2, v1, v2),
        c(a1, a2, b1, b2, c, B1, B2, m1.bis, m2, q1, q2, v1, v2))
    })
    
    sFUN <- "doubleLog.Klos"
    optim_pheno(prior, sFUN, y, t, tout, optimFUN, method, w, ...)
}

