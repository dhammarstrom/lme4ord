% Generated by roxygen2 (4.0.1): do not edit by hand
\name{setReTrm.lme4}
\alias{lme4}
\alias{setReTrm.lme4}
\title{lme4 emulator}
\usage{
\method{setReTrm}{lme4}(object, addArgsList, auxEnv = NULL,
  devfunEnv = NULL)
}
\arguments{
\item{object}{a \code{\link{reTrmStruct}} object}

\item{addArgsList}{a list of named quantities within which
\code{addArgsExpr} is evaluated}

\item{auxEnv}{an optional auxilliary environment containing
objects that are possibly required for the setting of a random
effects term structure (currently this is almost always the
environment of a call to \code{\link{strucParseFormula}}, unless
\code{setReTrm} is called directly)}

\item{devfunEnv}{optional environment of the deviance function}
}
\description{
lme4 emulator
}
\section{Mixed model formula usage}{

\code{lme4(linForm | grpFac)}
\describe{
\item{grpFac:}{grouping factor}
}
}

\section{Parameters}{

\describe{
\item{Covariance:}{elements of the upper triangle of the relative covariance factor for the random effects vector}
\item{Loadings:}{none}
}
}
\seealso{
Other setReTrm: \code{\link{biplot.factAnal}},
  \code{\link{factAnal}}, \code{\link{scores.factAnal}},
  \code{\link{setReTrm.factAnal}}; \code{\link{cooccur}},
  \code{\link{setReTrm.cooccur}}; \code{\link{expDecay}},
  \code{\link{setReTrm.expDecay}};
  \code{\link{findReTrmClasses}}, \code{\link{getAddArgs}},
  \code{\link{ranef.reTrmStruct}}, \code{\link{setReTrm}},
  \code{\link{setReTrm.default}}; \code{\link{flexvar}},
  \code{\link{setReTrm.flexvar}};
  \code{\link{getCorStruct}}, \code{\link{nlmeCorStruct}},
  \code{\link{setReTrm.nlmeCorStruct}};
  \code{\link{identity}}, \code{\link{setReTrm.identity}};
  \code{\link{obslev}}, \code{\link{setReTrm.obslev}};
  \code{\link{phyloEdge}},
  \code{\link{setReTrm.phyloEdge}}; \code{\link{sem}},
  \code{\link{setReTrm.sem}};
  \code{\link{setReTrm.varExp}}, \code{\link{varExp}};
  \code{\link{setReTrm.varIdent}}, \code{\link{varIdent}}
}

