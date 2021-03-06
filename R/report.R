#' @include main.R
NULL

#' Report feature group data
#'
#' Functionality to report data produced by most workflow steps such as
#' features, feature groups, calculated chemical formulae and tentatively
#' identified compounds.
#'
#' These functions are usually called at the very end of the workflow. It is
#' used to report various data on features and feature groups. In addition,
#' these functions may be used for reporting formulae and/or compounds that were
#' generated for the specified feature groups. Data can be reported in tabular
#' form (\emph{i.e.} \file{.csv} files) by \code{reportCSV} or graphically by
#' \code{reportPDF} and \code{reportHTML}. The latter functions will plot for
#' instance chromatograms and annotated mass spectra, which are useful to get a
#' graphical overview of results.
#'
#' All functions have a wide variety of arguments that influence the reporting
#' process. Nevertheless, most parameters are optional and only required to be
#' given for fine tuning. In addition, only those objects (\emph{e.g.} formulae,
#' compounds, clustering) that are desired to be reported need to be specified.
#'
#' @param fGroups The \code{\link{featureGroups}} object that should be used for
#'   reporting data.
#' @param path The destination file path for files generated during reporting.
#'   Will be generated if needed.
#' @param reportFGroups If \code{TRUE} then feature group data will be reported.
#' @param formulas,compounds,compsCluster,components Further objects
#'   (\code{\link{formulas}}, \code{\link{compounds}},
#'   \code{\link{compoundsCluster}}, \code{\link{components}}) that should be
#'   reported. Specify \code{NULL} to skip reporting a particular object.
#' @param reportFormulaSpectra If \code{TRUE} then explained MS/MS spectra (if
#'   available) for candidate formulae will be reported. Specifying
#'   \code{formulas} and setting this argument to \code{FALSE} still allows
#'   further annotation of compound MS/MS spectra.
#' @param MSPeakLists A \code{\link{MSPeakLists}} object that is
#'   \emph{mandatory} when spectra for formulae and/or compounds will be
#'   reported.
#' @param retMin If \code{TRUE} then report retention times in minutes
#'   (otehrwise seconds).
#' @param EICRtWindow,EICMzWindow,EICTopMost,EICOnlyPresent Plotting parameters
#'   passed to \code{\link{plotEIC}} (\emph{i.e.} \code{rtWindow},
#'   \code{mzWindow}, \code{topMost} and \code{onlyPresent} arguments).
#' @param compoundsOnlyUsedScorings If \code{TRUE} then only scorings are plotted
#'   that actually have been used to rank data (see the \code{scoreTypes}
#'   argument to \code{\link{generateCompoundsMetfrag}} for more details).
#' @param formulasTopMost,compoundsTopMost Only this amount of top ranked
#'   candidate formulae/compounds are reported. Lower values may significantly
#'   speed up reporting. Set to \code{NULL} to ignore.
#' @param clearPath If \code{TRUE} then the destination path will be
#'   (recursively) removed prior to reporting.
#'
#' @templateVar normParam compoundsNormalizeScores,formulasNormalizeScores
#' @templateVar excludeParam compoundsExclNormScores,formulasExclNormScores
#' @template norm-args
#'
#' @note Any formulae and compounds for feature groups which are not present
#'   within \code{fGroups} (\emph{i.e.} because it has been subset afterwards)
#'   will not be reported.
#'
#' @name reporting
NULL


prepareReportPath <- function(path, clear)
{
    if (clear)
        unlink(path, TRUE)
    mkdirp(path)
}

optimizePngPlots <- function(plotFiles, maxProcAmount)
{
    plotsPerBlock <- 50
    blocks <- ceiling(length(plotFiles) / plotsPerBlock)
    pqcmd <- getCommandWithOptPath("pngquant", "pngquant")
    mainArgs <- c("--skip-if-larger", "--force")
    
    # older pngquant versions may not support the --strip argument yet
    if (any(grepl("--strip", suppressWarnings(executeCommand(pqcmd, stderr = TRUE)), fixed = TRUE)))
        mainArgs <- c(mainArgs, "--strip")
    
    cmdQueue <- lapply(seq_len(blocks), function(bl)
    {
        startpl <- (bl - 1) * plotsPerBlock + 1
        endpl <- min(startpl + plotsPerBlock - 1, length(plotFiles))
        return(list(block = bl, startpl = startpl, endpl = endpl, command = pqcmd,
                    args = c(mainArgs, plotFiles[seq(startpl, endpl)])))
    })

    message("Optimizing plot sizes...")
    executeMultiProcess(cmdQueue, function(cmd)
    {
        # pngquant create new files as <filename_without_extension>-fs8.png --> rename them to original names
        plots <- plotFiles[seq(cmd$startpl, cmd$endpl)]
        qplots <- paste0(tools::file_path_sans_ext(plots), "-fs8.png")
        qexist <- file.exists(qplots)
        file.rename(qplots[qexist], plots[qexist])
    }, maxProcAmount = maxProcAmount)

    invisible(NULL)
}

makeCachedPlot <- function(out, plotFunc, plotArgs, w, h, bg = "white", cacheDB)
{
    hash <- do.call(paste0(plotFunc, "Hash"), plotArgs)
    cache <- loadCacheData("reportPlots", hash, cacheDB)

    if (!is.null(cache))
        writeBin(cache, out)
    else
    {
        withr::with_png(out, width = w, height = h, units = "in", res = 72, bg = bg,
                        code = do.call(plotFunc, plotArgs))
        saveCacheData("reportPlots", readBin(out, "raw", file.info(out)$size), hash, cacheDB)
    }
}

textPlot <- function(txt)
{
    withr::with_par(list(mar = c(0, 2, 0, 0)), {
        plot(1:10, 1:10, ann = FALSE, xaxt = "n", yaxt = "n", xlab = "", ylab = "", type = "n", adj = 1, bty = "n") # empty dummy plot
        text(1, 5, txt, adj = 0, cex = 0.8)
    })
}

reportFGroupTable <- function(fGroups, path, fGroupsAsRows, reportAnalysisInfo, reportRetMz, retMin)
{
    printf("Exporting feature group table...")

    if (length(fGroups) == 0)
    {
        printf("No feature groups!\n")
        invisible(return(NULL))
    }

    gTable <- copy(groups(fGroups))
    gInfo <- groupInfo(fGroups)
    anaInfo <- analysisInfo(fGroups)

    if (reportAnalysisInfo)
    {
        gTable <- insertDTColumn(gTable, "blank", anaInfo$blank, 1)
        gTable <- insertDTColumn(gTable, "replicate_group", anaInfo$group, 1)
    }

    if (fGroupsAsRows)
    {
        gTable <- transpose(gTable)
        setnames(gTable, anaInfo$analysis)
        initbl <- if (reportAnalysisInfo) rep("", 2) else c()

        rnames <- rownames(gInfo)
        if (reportAnalysisInfo)
            rnames <- c("replicate_group", "blank", rnames)

        if (reportRetMz)
        {
            gTable <- insertDTColumn(gTable, "m/z", c(initbl, gInfo$mzs), 1)
            rts <- if (retMin) gInfo$rts / 60 else gInfo$rts
            gTable <- insertDTColumn(gTable, "retention", c(initbl, rts), 1)
        }
    }
    else
    {
        if (reportRetMz)
        {
            gi <- setnames(transpose(gInfo[, c("rts", "mzs")]), rownames(gInfo))
            if (reportAnalysisInfo) # add two dummy columns
                gi <- cbind(replicate_group = "", blank = "", gi)

            gTable <- rbind(gi, gTable)
            rnames <- c("retention", "mz", anaInfo$analysis)
        }
    }

    write.csv(gTable, file.path(path, sprintf("%s.csv", class(fGroups))), row.names = rnames)

    printf("Done!\n")
}

reportFGroupPlots <- function(fGroups, path, plotGrid, rtWindow, mzWindow, retMin, topMost, onlyPresent, EICs)
{
    printf("Exporting feature group plots...\n")

    if (length(fGroups) == 0)
    {
        printf("No feature groups!\n")
        invisible(return(NULL))
    }

    gTable <- groups(fGroups)
    gCount <- length(fGroups)
    gInfo <- groupInfo(fGroups)
    anaInfo <- analysisInfo(fGroups)

    pdfFile <- file.path(path, sprintf("%s.pdf", class(fGroups)))
    pdf(pdfFile, paper = "a4", pointsize = 10, width = 8, height = 11)

    # all feature groups
    plotEIC(fGroups, rtWindow, mzWindow, retMin, 1, EICs, TRUE, FALSE)

    par(mfrow = plotGrid)
    prog <- openProgBar(0, gCount)
    for (grpi in seq_len(gCount))
    {
        plotEIC(fGroups[, grpi], rtWindow, mzWindow, retMin, topMost, EICs, onlyPresent = onlyPresent, colourBy = "rGroups")
        setTxtProgressBar(prog, grpi)
    }

    setTxtProgressBar(prog, gCount)
    close(prog)
    dev.off()

    # UNDONE: may fail sometimes (on AppVeyor)
    # tools::compactPDF(pdfFile)
    # tools::compactPDF(pdfFile, gs_quality = "ebook")

    invisible(NULL)
}

reportFeatureTable <- function(fGroups, path, retMin)
{
    printf("Exporting feature tables...\n")

    fTable <- featureTable(fGroups)

    fcount <- length(fTable)
    prog <- openProgBar(0, fcount)

    for (anai in seq_along(fTable))
    {
        ana <- names(fTable)[anai]
        out <- file.path(path, sprintf("%s-%s.csv", class(getFeatures(fGroups)), ana))
        tab <- copy(fTable[[ana]])
        if (retMin)
            tab[, ret := ret / 60]
        write.csv(tab, out)

        setTxtProgressBar(prog, anai)
    }

    setTxtProgressBar(prog, fcount)
    close(prog)
}

reportFormulaTable <- function(fGroups, path, formulas, normalizeScores, excludeNormScores)
{
    printf("Exporting formula table...")

    gNames <- names(fGroups)

    for (grp in groupNames(formulas))
    {
        if (grp %in% gNames && nrow(formulas[[grp]]) > 0)
        {
            out <- file.path(path, sprintf("%s-%s.csv", class(fGroups), grp))

            ft <- formulas[[grp]]
            if (normalizeScores != "none")
                ft <- normalizeFormScores(ft, formulas@scoreRanges[[grp]], normalizeScores == "minmax", excludeNormScores)
            write.csv(ft, out)
        }
    }

    printf("Done!\n")
}

reportFormulaSpectra <- function(fGroups, path, formulas, topMost, normalizeScores, excludeNormScores,
                                 MSPeakLists, EICRtWindow, EICMzWindow, retMin, EICTopMost, EICs)
{
    printf("Exporting formula MS/MS spectra...\n")

    if (length(formulas) == 0)
    {
        printf("No formulas!\n")
        invisible(return(NULL))
    }

    if (length(formulas) == 0)
        invisible(return(NULL))

    if (!is.null(topMost))
        formulas <- filter(formulas, topMost = topMost)

    formGroups <- intersect(groupNames(formulas), names(fGroups))
    fcount <- length(formGroups)
    if (fcount == 0)
        invisible(return(NULL))
    
    prog <- openProgBar(0, fcount)

    for (grp in formGroups)
    {
        ft <- formulas[[grp]]

        if (nrow(ft) > 0)
        {
            out <- file.path(path, sprintf("%s-%s.pdf", class(fGroups), grp))
            # a4r: width=11.69, height=8.27
            pdf(out, paper = "a4r", pointsize = 10, width = 11, height = 8)

            plotEIC(fGroups[, grp], EICRtWindow, EICMzWindow, retMin, EICTopMost, EICs)

            for (precursor in unique(ft$formula))
            {
                # NOTE: layout/mfrow/mfcol doesn't work because of the legend positioning (thinks 2 plots are made...)

                scr <- split.screen(c(2, 1))
                scr <- c(scr, split.screen(c(1, 2), screen = scr[2]))

                screen(scr[1])

                if (is.null(MSPeakLists[[grp]][["MSMS"]]))
                {
                    # no MSMS spectrum, i.e. MS only formula
                    textPlot("No MS/MS data available.")
                }
                else
                    plotSpec(formulas, precursor, grp, MSPeakLists = MSPeakLists)

                screen(scr[3])
                plotScores(formulas, precursor, grp, normalizeScores = normalizeScores,
                           excludeNormScores = excludeNormScores)

                screen(scr[4])

                textPlot(paste0(getFormInfoList(formulas[[grp]], precursor), collapse = "\n"))

                close.screen(scr)
            }
            dev.off()
        }

        setTxtProgressBar(prog, match(grp, formGroups))
    }

    setTxtProgressBar(prog, fcount)
    close(prog)
}

reportCompoundTable <- function(fGroups, path, compounds, normalizeScores, excludeNormScores, compsCluster)
{
    printf("Exporting identification results tables...")

    gInfo <- groupInfo(fGroups)
    gNames <- names(fGroups)
    anaInfo <- analysisInfo(fGroups)
    compTable <- compoundTable(compounds)
    mcn <- mergedCompoundNames(compounds)

    if (!is.null(compsCluster))
        cutcl <- cutClusters(compsCluster)

    if (normalizeScores != "none")
        compTable <- mapply(compTable, compounds@scoreRanges, FUN = normalizeCompScores,
                            MoreArgs = list(mCompNames = mcn, minMaxNormalization = normalizeScores == "minmax",
                                            exclude = excludeNormScores),
                            SIMPLIFY = FALSE)

    for (grp in names(compTable))
    {
        if (grp %in% gNames && nrow(compTable[[grp]]) > 0)
        {
            out <- file.path(path, sprintf("%s-%s.csv", class(fGroups), grp))
            tab <- compTable[[grp]][, -getAllCompCols("fragInfo", names(compTable[[grp]]), mergedCompoundNames(compounds)),
                                    with = FALSE]
            if (!is.null(compsCluster) && !is.null(cutcl[[grp]]))
                tab[, cluster := cutcl[[grp]]]
            write.csv(tab, out)
        }
    }

    printf("Done!\n")
}

reportCompoundSpectra <- function(fGroups, path, MSPeakLists, compounds, compsCluster,
                                  formulas, EICRtWindow, EICMzWindow, retMin,
                                  EICTopMost, EICs, normalizeScores, exclNormScores, onlyUsedScorings, topMost)
{
    printf("Exporting compound identification MS/MS spectra...\n")

    gNames <- names(fGroups)
    gInfo <- groupInfo(fGroups)
    anaInfo <- analysisInfo(fGroups)
    # specs <- loadAllSpectra(anaInfo$analysis, anaInfo$path)
    pLists <- peakLists(MSPeakLists)

    if (length(compounds) == 0)
    {
        printf("No compounds!\n")
        invisible(return(NULL))
    }

    if (!is.null(topMost))
        compounds <- filter(compounds, topMost = topMost)

    if (!is.null(compsCluster))
        cutcl <- cutClusters(compsCluster)

    compTable <- compoundTable(compounds)
    idcount <- length(compTable)
    prog <- openProgBar(0, idcount)

    for (gi in seq_along(compTable))
    {
        grp <- names(compTable)[gi]
        if (nrow(compTable[[grp]]) > 0)
        {
            fgrpi <- match(grp, gNames)
            if (is.na(fgrpi))
                next

            out <- file.path(path, sprintf("%s-%s.pdf", class(fGroups), grp))
            # a4r: width=11.69, height=8.27
            pdf(out, paper = "a4r", pointsize = 10, width = 11, height = 8)

            plotEIC(fGroups[, fgrpi], EICRtWindow, EICMzWindow, retMin, EICTopMost, EICs)

            for (idi in seq_len(nrow(compTable[[grp]])))
            {
                # NOTE: layout/mfrow/mfcol doesn't work because of the legend positioning (thinks 2 plots are made...)

                scr <- split.screen(c(2, 1))
                scr <- c(scr, split.screen(c(1, 2), screen = scr[2]))

                screen(scr[1])
                plotSpec(compounds, idi, grp, MSPeakLists = MSPeakLists, formulas = formulas)

                screen(scr[3])
                plotScores(compounds, idi, grp, normalizeScores, exclNormScores, onlyUsedScorings)

                screen(scr[4])

                # draw text info
                txt <- paste0(getCompInfoList(compTable[[grp]], idi, FALSE, mergedCompoundNames(compounds)),
                              collapse = "\n")
                if (!is.null(compsCluster) && !is.null(cutcl[[grp]]))
                    txt <- paste(txt, sprintf("cluster: %d", cutcl[[grp]][idi]), sep = "\n")

                textPlot(txt)

                close.screen(scr)
            }

            dev.off()
        }
        setTxtProgressBar(prog, gi)
    }

    setTxtProgressBar(prog, idcount)
    close(prog)
}

reportCompoundClusters <- function(fGroups, compsCluster, path)
{
    printf("Exporting compound clusters...\n")

    cutcl <- cutClusters(compsCluster)
    cutcl <- cutcl[names(cutcl) %in% names(fGroups)]
    ls <- lengths(compsCluster)
    ccount <- length(cutcl)

    if (ccount == 0)
    {
        printf("No compound clusters!\n")
        invisible(return(NULL))
    }

    prog <- openProgBar(0, ccount)

    for (gi in seq_along(cutcl))
    {
        grp <- names(cutcl)[gi]
        if (length(cutcl[[grp]]) > 0)
        {
            out <- file.path(path, sprintf("%s-%s-clusters.pdf", class(fGroups), grp))
            withr::with_pdf(out, paper = "a4", code =
            {
                plot(compsCluster, groupName = grp)
                par(mfrow = c(3, 3))
                for (i in seq_len(ls[[grp]]))
                    plotStructure(compsCluster, groupName = grp, cluster = i)
            })
        }
        setTxtProgressBar(prog, gi)
    }

    setTxtProgressBar(prog, ccount)
    close(prog)
}

reportComponentTable <- function(components, path, retMin)
{
    printf("Exporting component table...")

    if (length(components) == 0)
        printf("No components!\n")
    else
    {
        cTable <- rbindlist(componentTable(components), idcol = "component")

        if (retMin)
            cTable[, rt := rt / 60]
        write.csv(cTable, file.path(path, "components.csv"))

        printf("Done!\n")
    }
}

reportComponentPlots <- function(fGroups, path, components, EICRtWindow, EICMzWindow, retMin, EICs)
{
    printf("Exporting component plots...\n")

    if (length(components) == 0)
    {
        printf("No components!\n")
        invisible(return(NULL))
    }

    gInfo <- groupInfo(fGroups)
    anaInfo <- analysisInfo(fGroups)
    cInfo <- componentInfo(components)
    cTable <- componentTable(components)

    prog <- openProgBar(0, length(components))

    pdf(file.path(path, "components.pdf"), paper = "a4", pointsize = 10, width = 8, height = 11)

    # HACK: this should be replaced some proper inheritance/methods at some point
    isHClust <- inherits(components, "componentsIntClust")

    if (isHClust)
    {
        plotHeatMap(components, interactive = FALSE)
        plot(components)
        clProps <- clusterProperties(components)
    }

    for (cmpi in seq_len(length(components)))
    {
        if (isHClust)
        {
            scr <- split.screen(c(3, 1))
            scr <- c(scr, split.screen(c(1, 2), scr[3]))
        }
        else
            scr <- split.screen(c(2, 1))

        screen(scr[1])
        plotEIC(components, cmpi, fGroups, title = sprintf("Component %d", cmpi), rtWindow = EICRtWindow,
                mzWindow = EICMzWindow, retMin = retMin, EICs = EICs)

        screen(scr[2])
        plotSpec(components, cmpi, main = sprintf("ret: %.1f; m/z: %.4f - %.4f",
                                                  cInfo$ret[cmpi], min(cTable[[cmpi]]$mz), max(cTable[[cmpi]]$mz)))

        if (isHClust)
        {
            screen(scr[4])
            plotInt(components, index = cmpi, main = "normalized")

            screen(scr[5])
            fg <- fGroups[, unique(cTable[[cmpi]]$group)]
            plotInt(fg, average = clProps$average, main = "absolute")
        }

        close.screen(scr)

        setTxtProgressBar(prog, cmpi)
    }

    dev.off()
    close(prog)
}

#' @details \code{reportCSV} generates tabular data (\emph{i.e.} \file{.csv}
#'   files) for given data to be reported. This may also be useful to allow
#'   import by other tools for post processing.
#'
#' @param reportFGroupsAsRows Report feature groups as rows (instead of columns)
#'   within the resulting \file{.csv} file.
#' @param reportFGroupsAnalysisInfo Include analyses information (reference and
#'   replicate groups) in the reported feature groups table \file{.csv} file.
#' @param reportFGroupsRetMz Include feature group information (retention time
#'   and \emph{m/z}) within the reported feature groups table \file{.csv} file.
#' @param reportFeatures If set to \code{TRUE} then for each analysis a
#'   \file{.csv} file will be generated with information about its detected
#'   features.
#'
#' @rdname reporting
#' @aliases reportCSV
#' @export
setMethod("reportCSV", "featureGroups", function(fGroups, path, reportFGroupsAsRows, reportFGroupsAnalysisInfo,
                                                 reportFGroupsRetMz, reportFeatures,
                                                 formulas, formulasNormalizeScores, formulasExclNormScores,
                                                 compounds, compoundsNormalizeScores, compoundsExclNormScores,
                                                 compsCluster, components, retMin, clearPath)
{
    ac <- checkmate::makeAssertCollection()
    checkmate::assertPathForOutput(path, overwrite = TRUE, add = ac)
    aapply(checkmate::assertFlag, . ~ reportFGroupsAsRows + reportFGroupsAnalysisInfo + reportFGroupsRetMz +
               reportFeatures + retMin + clearPath,
           fixed = list(add = ac))
    aapply(checkmate::assertClass, . ~ formulas + compounds + compsCluster + components,
           c("formulas", "compounds", "compoundsCluster", "components"),
           null.ok = TRUE, fixed = list(add = ac))
    aapply(assertNormalizationMethod, . ~ formulasNormalizeScores + compoundsNormalizeScores, fixed = list(add = ac))
    aapply(checkmate::assertCharacter, . ~ formulasExclNormScores + compoundsExclNormScores,
           min.chars = 1, null.ok = TRUE, fixed = list(add = ac))
    checkmate::reportAssertions(ac)

    if (length(fGroups) == 0)
    {
        cat("No feature groups, nothing to report...\n")
        invisible(return(NULL))
    }
    
    prepareReportPath(path, clearPath)

    reportFGroupTable(fGroups, path, reportFGroupsAsRows, reportFGroupsAnalysisInfo, reportFGroupsRetMz, retMin)

    if (reportFeatures)
    {
        p <- file.path(path, "features")
        mkdirp(p)
        reportFeatureTable(fGroups, p, retMin)
    }

    if (!is.null(formulas) && length(formulas) > 0)
    {
        p <- file.path(path, "formulas")
        mkdirp(p)
        reportFormulaTable(fGroups, p, formulas, formulasNormalizeScores, formulasExclNormScores)
    }

    if (!is.null(compounds))
    {
        p <- file.path(path, "compounds")
        mkdirp(p)
        reportCompoundTable(fGroups, p, compounds, compoundsNormalizeScores, compoundsExclNormScores, compsCluster)
    }

    if (!is.null(components))
        reportComponentTable(components, path, retMin)
})

#' @details \code{reportPDF} will report graphical data (\emph{e.g.}
#'   chromatograms and mass spectra) within PDF files. Compared
#'   to \code{reportHTML} this function may be faster and yield smaller report
#'   files, however, its functionality is a bit more basic and generated data is
#'   more 'scattered' around.
#'
#' @param EICGrid An integer vector in the form \code{c(columns, rows)} that is
#'   used to determine the plotting grid when reporting EICs in PDF files.
#'
#' @rdname reporting
#' @aliases reportPDF
#' @export
setMethod("reportPDF", "featureGroups", function(fGroups, path, reportFGroups,
                                                 formulas, formulasTopMost, formulasNormalizeScores,
                                                 formulasExclNormScores, reportFormulaSpectra,
                                                 compounds, compoundsNormalizeScores, compoundsExclNormScores,
                                                 compoundsOnlyUsedScorings, compoundsTopMost, compsCluster,
                                                 components, MSPeakLists, retMin, EICGrid,
                                                 EICRtWindow, EICMzWindow, EICTopMost, EICOnlyPresent, clearPath)
{
    ac <- checkmate::makeAssertCollection()
    checkmate::assertPathForOutput(path, overwrite = TRUE, add = ac)
    aapply(checkmate::assertFlag, . ~ reportFGroups + reportFormulaSpectra +
               compoundsOnlyUsedScorings + retMin + EICOnlyPresent + clearPath,
           fixed = list(add = ac))
    aapply(checkmate::assertClass, . ~ formulas + compounds + compsCluster + components + MSPeakLists,
           c("formulas", "compounds", "compoundsCluster", "components", "MSPeakLists"),
           null.ok = TRUE, fixed = list(add = ac))
    aapply(assertNormalizationMethod, . ~ formulasNormalizeScores + compoundsNormalizeScores, fixed = list(add = ac))
    aapply(checkmate::assertCharacter, . ~ formulasExclNormScores + compoundsExclNormScores,
           min.chars = 1, null.ok = TRUE, fixed = list(add = ac))
    aapply(checkmate::assertCount, . ~ formulasTopMost + compoundsTopMost + EICTopMost,
           positive = TRUE, null.ok = TRUE, fixed = list(add = ac))
    checkmate::assertIntegerish(EICGrid, lower = 1, any.missing = FALSE, len = 2, add = ac)
    aapply(checkmate::assertNumber, . ~ EICRtWindow + EICMzWindow, lower = 0, finite = TRUE, fixed = list(add = ac))
    checkmate::reportAssertions(ac)

    if ((!reportFGroups && is.null(formulas) && is.null(compounds) && is.null(components)) || length(fGroups) == 0)
    {
        cat("No feature groups, nothing to report...\n")
        invisible(return(NULL))
    }

    if (is.null(MSPeakLists) &&
        ((!is.null(formulas) && reportFormulaSpectra) || !is.null(compounds)))
        stop("MSPeakLists is NULL, please specify when reporting formula and/or compounds")

    prepareReportPath(path, clearPath)

    if (reportFGroups || !is.null(formulas) || !is.null(compounds) || !is.null(components))
    {
        cat("Loading all EICs... ")
        EICs <- getEICsForFGroups(fGroups, EICRtWindow, EICMzWindow, EICTopMost, EICOnlyPresent)
        cat("Done!\n")
    }

    if (reportFGroups)
        reportFGroupPlots(fGroups, path, EICGrid, EICRtWindow, EICMzWindow, retMin, EICTopMost, EICOnlyPresent, EICs)

    if (reportFormulaSpectra && !is.null(formulas))
    {
        p <- file.path(path, "formulas")
        mkdirp(p)
        reportFormulaSpectra(fGroups, p, formulas, formulasTopMost, formulasNormalizeScores,
                             formulasExclNormScores, MSPeakLists,
                             EICRtWindow, EICMzWindow, retMin, EICTopMost, EICs)
    }

    if (!is.null(compounds))
    {
        p <- file.path(path, "compounds")
        mkdirp(p)
        reportCompoundSpectra(fGroups, p, MSPeakLists, compounds, compsCluster, formulas, EICRtWindow, EICMzWindow, retMin,
                              EICTopMost, EICs, compoundsNormalizeScores, compoundsExclNormScores, compoundsOnlyUsedScorings,
                              compoundsTopMost)
    }

    if (!is.null(compsCluster))
    {
        p <- file.path(path, "compounds")
        mkdirp(p)
        reportCompoundClusters(fGroups, compsCluster, p)
    }

    if (!is.null(components))
        reportComponentPlots(fGroups, path, components, EICRtWindow, EICMzWindow, retMin, EICs)
})


#' @details \code{reportHTML} will report graphical data (\emph{e.g.}
#'   chromatograms and mass spectra) and summary information in an easy
#'   browsable \code{HTML} file using \link{rmarkdown}, \link{flexdashboard} and
#'   \link{knitr}.
#'
#' @param reportPlots A character vector specifying what should be plotted.
#'   Valid options are: \code{"chord"}, \code{"venn"}, \code{"upset"} (plot a
#'   chord, Venn and UpSet diagram, respectively), \code{"eics"} (plot EICs for
#'   individual feature groups) and \code{"formulas"} (plot annotated formula
#'   spectra). Set to \code{"none"} to plot none of these.
#' @param includeMFWebLinks A \code{character} specifying to which feature
#'   groups a web link should be added in the annotation page to
#'   \href{https://msbi.ipb-halle.de/MetFragBeta/index.xhtml}{MetFragWeb}.
#'   Options are: \code{"compounds"} (only to those with compounds results),
#'   \code{"MSMS"} (only to those with MSMS peak lists) or \code{"none"}.
#' @param interactiveHeat If \code{TRUE} an interactive heatmap HTML widget will
#'   be generated to display hierarchical clustering results. Set to
#'   \code{FALSE} for a 'regular' static plot.
#' @param selfContained If \code{TRUE} the output will be a standalone HTML file
#'   which contains all graphics and script dependencies. When \code{FALSE}, the
#'   latter will be placed in an additional directory (\file{report_files})
#'   which should remain present when viewing the output file. Especially on
#'   Windows, a non-self contained output might be desirable when reporting
#'   large amounts of data to prevent \command{pandoc} from running out of
#'   memory.
#' @param optimizePng If \code{TRUE} then \command{pngquant} is used to reduce
#'   the size of generated graphics. A signficant reduction in disk space usage
#'   may be seen, however, at the cost additional processing time.
#' @param maxProcAmount Maximum amount of \command{pngquant} commands to run in
#'   parallel. Higher numbers will decrease processing time, with an optimum
#'   usually close to the amount of CPU cores.
#' @param openReport If set to \code{TRUE} then the output report file will be
#'   opened with the system browser.
#' @param noDate If \code{TRUE} then the current date is not added to the
#'   report. This is mainly used for testing and its main purpose is to
#'   guarentees equal report files when `reportHTML()` is called multiple times
#'   with equal arguments.
#'
#' @references Creating MetFrag landing page URLs based on code from
#'   \href{https://github.com/Treutler/MetFamily}{MetFamily} R package. \cr\cr
#'   \addCitations{knitr}{2} \cr\cr \addCitations{knitr}{3}
#'
#' @rdname reporting
#' @aliases reportHTML
#' @export
setMethod("reportHTML", "featureGroups", function(fGroups, path, reportPlots, formulas, formulasTopMost,
                                                  formulasNormalizeScores, formulasExclNormScores,
                                                  compounds, compoundsNormalizeScores, compoundsExclNormScores,
                                                  compoundsOnlyUsedScorings, compoundsTopMost,
                                                  compsCluster, includeMFWebLinks, components, interactiveHeat,
                                                  MSPeakLists, retMin, EICRtWindow, EICMzWindow,
                                                  EICTopMost, EICOnlyPresent, selfContained,
                                                  optimizePng, maxProcAmount, clearPath, openReport, noDate)
{
    # UNDONE: mention pandoc win limits

    ac <- checkmate::makeAssertCollection()
    checkmate::assertPathForOutput(path, overwrite = TRUE, add = ac)
    reportPlots <- checkmate::matchArg(reportPlots, c("none", "chord", "venn", "upset", "eics", "formulas"),
                                       several.ok = TRUE, add = ac)
    aapply(checkmate::assertFlag, . ~ compoundsOnlyUsedScorings + interactiveHeat + retMin + EICOnlyPresent +
               selfContained + optimizePng + clearPath + openReport + noDate,
           fixed = list(add = ac))
    aapply(checkmate::assertClass, . ~ formulas + compounds + components + MSPeakLists,
           c("formulas", "compounds", "components", "MSPeakLists"),
           null.ok = TRUE, fixed = list(add = ac))
    aapply(assertNormalizationMethod, . ~ formulasNormalizeScores + compoundsNormalizeScores, fixed = list(add = ac))
    aapply(checkmate::assertCharacter, . ~ formulasExclNormScores + compoundsExclNormScores,
           min.chars = 1, null.ok = TRUE, fixed = list(add = ac))
    aapply(checkmate::assertCount, . ~ formulasTopMost + compoundsTopMost + EICTopMost,
           positive = TRUE, null.ok = TRUE, fixed = list(add = ac))
    checkmate::assertChoice(includeMFWebLinks, c("compounds", "MSMS", "none"), add = ac)
    aapply(checkmate::assertNumber, . ~ EICRtWindow + EICMzWindow, lower = 0, finite = TRUE, fixed = list(add = ac))
    checkmate::assertCount(maxProcAmount, positive = TRUE, add = ac)
    checkmate::reportAssertions(ac)

    if (length(fGroups) == 0)
    {
        cat("No feature groups, nothing to report...\n")
        invisible(return(NULL))
    }
    
    if ("none" %in% reportPlots)
        reportPlots <- ""

    if (is.null(MSPeakLists) &&
        ((!is.null(formulas) && "formulas" %in% reportPlots) || !is.null(compounds)))
        stop("MSPeakLists is NULL, please specify when reporting formula and/or compounds")

    prepareReportPath(path, clearPath)

    workPath <- file.path(tempdir(TRUE), "report")
    unlink(workPath, TRUE)
    mkdirp(workPath)

    file.copy(system.file("report", "main.Rmd", package = "patRoon"), workPath)
    file.copy(system.file("report", "annotation.Rmd", package = "patRoon"), workPath)
    file.copy(system.file("report", "components.Rmd", package = "patRoon"), workPath)

    # rmarkdown needs absolute path as relative paths will be from the path of the Rmd
    if (!R.utils::isAbsolutePath(path))
        path <- R.utils::getAbsolutePath(path)

    EICs <- NULL

    # NOTE: loading EICs is done outside knitr environment: the current working
    # directory is changed so we loose access to the cache.

    # UNDONE: always load EICs? Need them for summary EIC plot
    # if (reportFGroups || (!is.null(formulas) && reportFormulaSpectra) ||
    #     !is.null(compounds) || !is.null(components))
    {
        cat("Loading all EICs... ")
        EICs <- getEICsForFGroups(fGroups, EICRtWindow, EICMzWindow, EICTopMost, EICOnlyPresent)
        cat("Done!\n")
    }

    if (!is.null(formulas) && !is.null(formulasTopMost))
        formulas <- filter(formulas, topMost = formulasTopMost)
    if (!is.null(compounds) && !is.null(compoundsTopMost))
        compounds <- filter(compounds, topMost = compoundsTopMost)

    rmdVars <- list(outPath = path, fGroups = fGroups, groupNames = names(fGroups), gInfo = groupInfo(fGroups),
                    reportPlots = reportPlots, EICRtWindow = EICRtWindow, EICMzWindow = EICMzWindow,
                    retMin = retMin, EICTopMost = EICTopMost, EICOnlyPresent = EICOnlyPresent, EICs = EICs,
                    compounds = compounds, compsCluster = compsCluster, includeMFWebLinks = includeMFWebLinks,
                    MSPeakLists = MSPeakLists, formulas = formulas, formulasNormalizeScores = formulasNormalizeScores,
                    formulasExclNormScores = formulasExclNormScores, compoundsNormalizeScores = compoundsNormalizeScores,
                    compoundsExclNormScores = compoundsExclNormScores,
                    compoundsOnlyUsedScorings = compoundsOnlyUsedScorings,
                    components = components, interactiveHeat = interactiveHeat, selfContained = selfContained,
                    optimizePng = optimizePng, maxProcAmount = maxProcAmount,
                    noDate = noDate)

    # HACK: not sure what exactly happens here, but... kableExtra adds latex
    # dependencies by default, which then may cause serious memory leakage when
    # rmarkdown::render() is called repeatedly. For now just remove them temporarily.
    knitMeta <- knitr::knit_meta("latex_dependency", clean = TRUE)
    on.exit(knitr::knit_meta_add(knitMeta), add = TRUE)

    outputFile <- file.path(path, "report.html")

    # normalize cache path so it can be used in report working directory
    withr::with_options(list(DT.warn.size = FALSE,
                             patRoon.cache.fileName = normalizePath(getOption("patRoon.cache.fileName")),
                             patRoon.progress.opts = list(file = stderr())),
                        rmarkdown::render(file.path(workPath, "main.Rmd"), output_file = outputFile,
                                          output_options = list(self_contained = selfContained),
                                          quiet = TRUE))

    if (openReport)
        utils::browseURL(paste0("file://", outputFile))

    invisible(NULL)
})
