% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/components-nontarget.R
\docType{class}
\name{componentsNT-class}
\alias{componentsNT-class}
\alias{componentsNT}
\alias{plotGraph,componentsNT-method}
\alias{plotGraph}
\title{Components class for homologous series.}
\usage{
\S4method{plotGraph}{componentsNT}(obj, onlyLinked = TRUE)
}
\arguments{
\item{obj}{The \code{componentsRC} object to plot.}

\item{onlyLinked}{If \code{TRUE} then only series with links are plotted.}
}
\value{
\code{plotGraph} returns the result of \code{\link{visNetwork}}.
}
\description{
This class is derived from \code{\link{components}} and is used to store
results from unsupervised homolog detection with the \pkg{\link{nontarget}}
package.
}
\details{
Objects from this class are generated by
\code{\link{generateComponentsNontarget}}
}
\section{Methods (by generic)}{
\itemize{
\item \code{plotGraph}: Plots an interactive network graph for linked
homologous series (\emph{i.e.} series with (partial) overlap which could
not be merged). The resulting graph can be browsed interactively and allows
quick inspection of series which may be related. The graph is constructed
with the \pkg{\link{igraph}} package and rendered with
\pkg{\link{visNetwork}}.
}}

\references{
\addCitations{nontarget}{1} \cr\cr \addCitations{enviPat}{1}

\addCitations{igraph}{1} \cr \cr \addCitations{visNetwork}{1}
}
\seealso{
\code{\link{components}} and \link{component-generation}
}
