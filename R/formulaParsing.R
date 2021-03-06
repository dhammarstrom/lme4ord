## ----------------------------------------------------------------------
## Formula parsing
##
## used by:  structuredGLMM.R
## uses:  randomEffectsStructures.R, structuredSparseMatrices.R
## ----------------------------------------------------------------------


##' Parse a mixed model formula
##'
##' @param formula mixed model formula
##' @param data an object coercible to data frame
##' @param addArgs list of additional arguments to
##' \code{\link{setReTrm}} methods
##' @param reTrmsList if \code{NULL} \code{\link{mkReTrmStructs}} is used
##' @param parList potential named list of initial parameters
##' @param ... additional parameters to \code{\link{as.data.frame}}
##' @return A list with components:
##' \item{response}{The response vector}
##' \item{fixed}{The fixed effects model matrix}
##' \item{random}{List of random effects terms returned by
##' \code{\link{mkReTrmStructs}} and updated with
##' \code{\link{setReTrm}}.}
##' \item{Zt}{The sparse transposed random effects model matrix, of
##' class \code{dgCMatrix}.}
##' \item{Lambdat}{The sparse transposed relative covariance factor,
##' of class \code{dgCMatrix}}
##' \item{mapToModMat}{function taking the \code{loads} parameters and
##' returning the values of the non-zero elements of \code{Zt}
##' (i.e. the \code{x} slot of \code{Zt})}
##' \item{mapToCovFact}{function taking the \code{covar} parameters
##' and returning the values of the non-zero elements of
##' \code{Lambdat} (i.e. the \code{x} slot of \code{Lambdat})}
##' \item{initPars}{The initial parameter vector}
##' \item{parInds}{List of indices to the different types of
##' parameters.}
##' \item{lower, upper}{Vectors of lower and upper bounds on
##' \code{initPars}.}
##' \item{devfunEnv}{Environment of the deviance function.}
##' \item{formula}{Model formula.}
##' @rdname strucParseFormula
##' @export
strucParseFormula <- function(formula, data, addArgs = list(), reTrmsList = NULL,
                              parList = NULL, ...) {
                                        # get and construct basic
                                        # information: (1) list of
                                        # formulas, (2) data, and (3)
                                        # the environment that will
                                        # eventually become the
                                        # environment of the deviance
                                        # function (i try to keep a
                                        # reference to this
                                        # environment in lots of
                                        # places)
    sf        <- splitForm(formula)
    data      <- as.data.frame(data, ...)
    devfunEnv <- new.env()

                                        # initially set up the random
                                        # effects term structures
    if(is.null(reTrmsList)) reTrmsList <- mkReTrmStructs(sf, data)

                                        # extract the respose, fixed
                                        # effects model matrix, and
                                        # list of random effects
                                        # structures
    response <- try(model.response(model.frame(sf$fixedFormula, data)),
                    silent = TRUE)
                                        # allow for no-response case
                                        # (i.e. simulations)
    if(inherits(response, "try-error")) {
        response <- rep(NA, nrow(data))
        sf$fixedFormula <- sf$fixedFormula[-2]
    }
    fixed    <- model.matrix(sf$fixedFormula, data)
    random   <- lapply(reTrmsList, setReTrm, addArgs = addArgs,
                       auxEnv = environment(),
                       devfunEnv = devfunEnv)

                                        # lists of structured sparse
                                        # matrices
    ZtList      <- lapply(random, "[[",      "Zt")
    LambdatList <- lapply(random, "[[", "Lambdat")

                                        # bind the lists together,
                                        # while ensuring that the
                                        # order is appropriate for
                                        # coercing to dgCMatrix
                                        # objects
    Zt      <- sortedBind(     ZtList, type = "row" )
    Lambdat <- sortedBind(LambdatList, type = "diag")

                                        # get initial values for model
                                        # parameters
    init <- list(covar = getInit(Lambdat),
                 fixef = rep(0, ncol(fixed)),
                 loads = getInit(Zt))
    parInds <- mkParInds(init)
    initPars <- unlist(init)

                                        # get lower and upper bounds
                                        # on parameters for the
                                        # optimizer
    lowerLoadsList <- lapply(random, "[[", "lowerLoads")
    upperLoadsList <- lapply(random, "[[", "upperLoads")
    lowerCovarList <- lapply(random, "[[", "lowerCovar")
    upperCovarList <- lapply(random, "[[", "upperCovar")
    lower <- c(unlist(lowerCovarList),
               rep(-Inf, ncol(fixed)),
               unlist(lowerLoadsList))
    upper <- c(unlist(upperLoadsList),
               rep( Inf, ncol(fixed)),
               unlist(upperCovarList))
    names(lower) <- names(upper) <- names(initPars)

                                        # fill the environment of the
                                        # deviance function with those
                                        # objects that depend on the
                                        # order of random effects
                                        # terms
    devfunEnv <- list2env(list(nRePerTrm = sapply(LambdatList, nrow),
                               nLambdatParPerTrm = sapply(LambdatList, parLength),
                                    nZtParPerTrm = sapply(     ZtList, parLength),
                               reTrmClasses = sf$reTrmClasses),
                          envir = devfunEnv)

                                        # fill the environments of the
                                        # transformation functions
                                        # with objects that depend on
                                        # the order of random effects
                                        # terms
    random <- lapply(random, update)

    ans <- list(response = response, fixed = fixed, random = random,
                Zt = Zt, Lambdat = Lambdat,
                mapToModMat = mkSparseTrans(Zt),
                mapToCovFact = mkSparseTrans(Lambdat),
                initPars = initPars, parInds = parInds,
                lower = lower, upper = upper,
                devfunEnv = devfunEnv,
                formula = formula)
    ans <- structure(ans, class = "strucParseFormula")

    if(!is.null(parList)) ans <- update(ans, parList)

    return(ans)
}

##' @param x \code{strucParseFormula} objects
##' @rdname strucParseFormula
##' @method print strucParseFormula
##' @export
print.strucParseFormula <- function(x, ...) {
    cat("Structured parsed formula\n")
    cat("=========================\n")
    print(x$formula)
    cat("\nInitial fixed effect coefficients\n")
    cat(  "---------------------------------\n")
    print(with(x, initPars[parInds$fixef]))
    cat("\nInitial random effect terms\n")
    cat(  "---------------------------\n")
    print(x$random)
}

##' @param object \code{strucParseFormula} objects
##' @rdname strucParseFormula
##' @export
model.matrix.strucParseFormula <- function(object, ...) object$fixed

##' @param nsim number of simulations
##' @param seed random seed (see \code{\link{set.seed}})
##' @param weights \code{\link{weights}} for each observation
##' @param family \code{\link{family}} object
##' @rdname strucParseFormula
##' @export
simulate.strucParseFormula <- function(object, nsim = 1, seed = NULL,
                                       weights = NULL,
                                       family = binomial(), ...) {
    if(!is.null(seed)) set.seed(seed)
    nobs <- length(object$response)
    if(is.null(weights)) weights <- rep(1, nobs)
    replicate(nsim, {
        fe <- as.numeric(model.matrix(object) %*% with(object, initPars[parInds$fixef]))
        re <- Reduce("+", lapply(getReTrm(object), simReTrm))
        familySimFun(family)(weights, nobs, family$linkinv(fe + re))
    })
}

##' @rdname strucParseFormula
##' @export
getParTypes <- function(object) {
    types <- character(0)
    trmNames <- names(object$random)
    randomPars <- listTranspose(lapply(object$random, getInit))
    whichCovarTerms <- sapply(lapply(randomPars$initCovar, length), ">", 0)
    whichLoadsTerms <- sapply(lapply(randomPars$initLoads, length), ">", 0)
    if(length(object$initPars[object$parInds$fixef]) > 0) types <- c(types, "fixef")
    if(length(object$initPars[object$parInds$weigh]) > 0) types <- c(types, "weigh")
    if(any(whichCovarTerms)) {
        types <- c(types, paste("covar", trmNames[whichCovarTerms], sep = "."))
    }
    if(any(whichLoadsTerms)) {
        types <- c(types, paste("loads", trmNames[whichLoadsTerms], sep = "."))
    }
    return(types)
}

##' @method update strucParseFormula
##' @rdname strucParseFormula
##' @export
update.strucParseFormula <- function(object, parList, ...) {
    if(missing(parList)) return(getParTypes(object))
    parType <- names(parList)
                                        # get braodTypes (i.e. covar,
                                        # loads, fixef, or weigh) and
                                        # get narrowTypes (i.e. names
                                        # of random effects terms)
    breakUpNames <- strsplit(parType, ".", fixed = TRUE)
    broadTypes <- sapply(breakUpNames, "[", 1)
    narrowTypes <- sapply(lapply(breakUpNames, "[", -1), paste, collapse = ".")

                                        # set initial values and
                                        # update where necessary
    for(i in seq_along(broadTypes)) {
        if(broadTypes[i] == "fixef") object$initPars[object$parInds$fixef] <- parList[[i]]
        if(broadTypes[i] == "weigh") object$initPars[object$parInds$weigh] <- parList[[i]]
        if(broadTypes[i] == "covar") {
            setInit(object$random[[narrowTypes[i]]]$Lambdat, parList[[i]])
            object$random[[narrowTypes[i]]]$Lambdat <-
                update(object$random[[narrowTypes[i]]]$Lambdat)
        }
        if(broadTypes[i] == "loads") {
            setInit(object$random[[narrowTypes[i]]]$Zt, parList[[i]])
            object$random[[narrowTypes[i]]]$Zt <- 
                update(object$random[[narrowTypes[i]]]$Zt)
        }
    }

                                        # propogate the new initial
                                        # values and updates down
                                        # through the parsed formula
                                        # object
    newRandomInit <- lapply(listTranspose(lapply(object$random, getInit)), unlist)
    if(any(broadTypes == "covar")) {
        setInit(object$Lambdat, newRandomInit$initCovar)
        object$Lambdat <- update(object$Lambdat)
        object$initPars[object$parInds$covar] <- newRandomInit$initCovar
    }
    if(any(broadTypes == "loads")) {
        setInit(object$Zt, newRandomInit$initLoads)
        object$Zt <- update(object$Zt)
        object$initPars[object$parInds$loads] <- newRandomInit$initLoads
    }
    
    return(object)
}


##' Split a formula
##'
##' @param formula Generalized mixed model formula
##' @importFrom lme4 expandDoubleVerts
##' @importFrom lme4 nobars
##' @rdname splitForm
##' @export
splitForm <- function(formula) {

    specials <- findReTrmClasses()
                                        # ignore any specials not in
                                        # formula
    specialsToKeep <- sapply(lapply(specials, grep,
                                    x = as.character(formula[[length(formula)]])),
                             length) > 0L
    specials <- specials[specialsToKeep]

    ## Recursive function: (f)ind (b)ars (a)nd (s)pecials
    ## cf. fb function in findbars (i.e. this is a little DRY)
    fbas <- function(term) {
        if (is.name(term) || !is.language(term)) return(NULL)
        for (sp in specials) if (term[[1]] == as.name(sp)) return(term)
        if (term[[1]] == as.name("(")) return(term)
        stopifnot(is.call(term))
        if (term[[1]] == as.name('|')) return(term)
        if (length(term) == 2) return(fbas(term[[2]]))
        c(fbas(term[[2]]), fbas(term[[3]]))
    }
    formula <- expandDoubleVerts(formula)
                                        # split formula into separate
                                        # random effects terms
                                        # (including special terms)
    formSplits <- fbas(formula)
                                        # check for hidden specials
                                        # (i.e. specials hidden behind
                                        # parentheses)
    formSplits <- lapply(formSplits, uncoverHiddenSpecials)
                                        # vector to identify what
                                        # special (by name), or give
                                        # "(" for standard terms, or
                                        # give "|" for specials
                                        # without a setReTrm method
    formSplitID <- sapply(lapply(formSplits, "[[", 1), as.character)
    as.character(formSplits[[1]])
                                        # warn about terms without a
                                        # setReTrm method
    badTrms <- formSplitID == "|"
    if(any(badTrms)) {
        stop("can't find setReTrm method(s)\n",
             "use findReTrmClasses() for available methods")
        # FIXME: coerce bad terms to unstructured as attempted below
        warning(paste("can't find setReTrm method(s) for term number(s)",
                      paste(which(badTrms), collapse = ", "),
                      "\ntreating those terms as unstructured"))
        formSplitID[badTrms] <- "("
        fixBadTrm <- function(formSplit) {
            as.formula(paste(c("~(", as.character(formSplit)[c(2, 1, 3)], ")"),
                             collapse = " "))[[2]]
        }
        formSplits[badTrms] <- lapply(formSplits[badTrms], fixBadTrm)
    }

                                        # capture additional arguments
    reTrmAddArgs <- lapply(formSplits, "[", -2)[!(formSplitID == "(")]
                                        # remove these additional
                                        # arguments
    formSplits <- lapply(formSplits, "[", 1:2)
                                        # standard RE terms
    formSplitStan <- formSplits[formSplitID == "("]
                                        # structured RE terms
    formSplitSpec <- formSplits[!(formSplitID == "(")]

    
    

    if(length(formSplitSpec) == 0) stop(
                 "no special covariance structures. ",
                 "please use lmer or glmer, ",
                 "or use findReTrmClasses() for available structures.")


    ## fixedFormula <- formula(paste(formula[[2]], "~",
    ##                               as.character(noSpecials(nobars(formula)))[[3]]))
    fixedFormula <- noSpecials(nobars(formula))
    reTrmFormulas <- c(lapply(formSplitStan, "[[", 2),
                       lapply(formSplitSpec, "[[", 2))
    reTrmClasses <- c(rep("unstruc", length(formSplitStan)),
                      sapply(lapply(formSplitSpec, "[[", 1), as.character))
    
    return(list(fixedFormula  = fixedFormula,
                reTrmFormulas = reTrmFormulas,
                reTrmAddArgs  = reTrmAddArgs,
                reTrmClasses  = reTrmClasses))
}

reParen <- function(reTrm) paste("(", deparse(reTrm), ")", sep = "", collapse = "")

##' @rdname splitForm
##' @param splitFormula results of \code{splitForm}
##' @export
reForm <- function(splitFormula) {
    characterPieces <- c(list(deparse(splitFormula$fixedFormula)),
                         lapply(splitFormula$reTrmFormulas, reParen))
    as.formula(do.call(paste, c(characterPieces, list(sep = " + "))))
}


##' @param term language object
##' @rdname splitForm
##' @export
noSpecials <- function(term) {
    nospec <- noSpecials_(term)
    if (is(term,"formula") && length(term)==3 && is.symbol(nospec)) {
        ## called with two-sided RE-only formula:
        ##    construct response~1 formula
        nospec <- reformulate("1", response = deparse(nospec))
    }
    return(nospec)
}

noSpecials_ <- function(term) {
    if (!anySpecial(term)) return(term)
    if (isSpecial(term)) return(NULL)
    nb2 <- noSpecials(term[[2]])
    nb3 <- noSpecials(term[[3]])
    if (is.null(nb2)) return(nb3)
    if (is.null(nb3)) return(nb2)
    term[[2]] <- nb2
    term[[3]] <- nb3
    term
}

isSpecial <- function(term) {
    if(is.call(term)) {
        for(cls in findReTrmClasses()) {
            if(term[[1]] == cls) return(TRUE)
        }
    }
    FALSE
}

isAnyArgSpecial <- function(term) {
    for(i in seq_along(term)) {
        if(isSpecial(term[[i]])) return(TRUE)
    }
    FALSE
}

anySpecial <- function(term) {
    any(findReTrmClasses() %in% all.names(term))
}

simStruc <- function(formula, data, addArgs, family, ...) {
    parsedForm <- strucParseFormula(formula, data = data, addArgs = addArgs, ...)
}

uncoverHiddenSpecials <- function(trm) {
    if(trm[[1]] == "(") {
        if(anySpecial(trm[[2]][[1]])) trm <- trm[[2]]
    }
    return(trm)
}

