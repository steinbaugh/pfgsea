## NOTE Consider adding method support for matrix here, which is useful
## for a table of values across multiple contrasts.

## NOTE Consider adding an "entrezId" key type for DESeqAnalysis class.



#' @name RankedList
#' @inherit RankedList-class title description return
#' @note Updated 2021-06-22.
#'
#' @section Gene symbol multi-mapping:
#'
#' Multiple gene IDs can map to a gene symbol (e.g. *Homo sapiens* HGNC names).
#' In this event, we're averaging the stat values using `mean()` internally.
#'
#' @inheritParams AcidRoxygen::params
#' @inheritParams params
#' @param keyType `character(1)`.
#'   Key type:
#'   - Gene name (a.k.a. symbol; e.g. "TSPAN6").
#'     *Recommended by default.*
#'   - Gene identifier (e.g. "ENSG00000000003").
#' @param value `character(1)`.
#'   Value type to use for GSEA ranked list.
#'   Currently supported:
#'
#'   1. `stat`: Wald test statistic. This column is returned by `results()`
#'      but is removed in [DESeq2::lfcShrink()] return, currently.
#'   2. `log2FoldChange`: Shrunken log2 fold change. Note that this option
#'      requires [DESeq2::lfcShrink()] return to be slotted.
#'   3. `padj`: Adjusted *P* value. This don't provide directional ranks, but
#'      is offered as a legacy option. Not generally recommended.
#'
#' @examples
#' ## DESeqAnalysis ====
#' data(deseq, package = "DESeqAnalysis")
#' x <- RankedList(deseq)
#' print(x)
#'
#' ## FGSEAList ====
#' data(fgsea, package = "AcidGSEA")
#' x <- RankedList(fgsea)
#' print(x)
NULL



## Updated 2021-03-04.
`RankedList,DataFrame` <-  # nolint
    function(
        object,
        value,
        keyType = c("geneName", "geneId"),
        gene2symbol = NULL
    ) {
        validObject(object)
        validObject(gene2symbol)
        assert(
            is(object, "DataFrame"),
            is(gene2symbol, "Gene2Symbol") || is.null(gene2symbol),
            isSubset(value, colnames(object))
        )
        keyType <- match.arg(keyType)
        switch(
            EXPR = keyType,
            "geneId" = {
                assert(
                    hasRownames(object),
                    hasNoDuplicates(rownames(object))
                )
                x <- as(object, "DataFrame")[[value]]
                names(x) <- rownames(object)
            },
            "geneName" = {
                assert(
                    is(gene2symbol, "Gene2Symbol"),
                    hasRownames(gene2symbol)
                )
                x <- as(object, "DataFrame")
                y <- as(gene2symbol, "DataFrame")
                ## Join the gene-to-symbol mappings, so we can convert Ensembl
                ## gene identifiers to gene symbols, for use with GSEA MSigDb
                ## GMT files.
                cols <- setdiff(colnames(x), colnames(y))
                assert(hasLength(cols))
                x <- x[, cols]
                x[["rowname"]] <- rownames(x)
                y[["rowname"]] <- rownames(y)
                x <- leftJoin(x, y, by = "rowname")
                x <- x[, c("geneName", value), drop = FALSE]
                x <- x[complete.cases(x), , drop = FALSE]
                x <- unique(x)
                ## Average the value per gene symbol, if necessary.
                x[["geneName"]] <- as.factor(x[["geneName"]])
                if (any(duplicated(x[["geneName"]]))) {
                    rownames(x) <- NULL
                    dupes <- which(duplicated(x[["geneName"]]))
                    dupes <- as.character(x[["geneName"]][dupes])
                    dupes <- sort(unique(dupes))
                    alert(sprintf(
                        fmt = "Averaging '%s' value for %d gene %s: %s.",
                        value,
                        length(dupes),
                        ngettext(
                            n = length(dupes),
                            msg1 = "symbol",
                            msg2 = "symbols"
                        ),
                        toString(dupes, width = 100L)
                    ))
                }
                ## Split by the gene symbol.
                x <- split(x = x, f = x[["geneName"]])
                ## Calculate mean expression per symbol.
                x <- vapply(
                    X = x[, value],
                    FUN = mean,
                    FUN.VALUE = numeric(1L),
                    USE.NAMES = TRUE
                )
            }
        )
        ## Arrange from positive to negative.
        x <- sort(x, decreasing = TRUE)
        ## Return ranked list.
        out <- SimpleList(x)
        metadata(out) <- list(
            "gene2symbol" = gene2symbol,
            "keyType" = keyType,
            "packageVersion" = .pkgVersion,
            "value" = value
        )
        new(Class = "RankedList", out)
    }

formals(`RankedList,DataFrame`)[["value"]] <- .rankedListValue



#' @rdname RankedList
#' @export
setMethod(
    f = "RankedList",
    signature = signature("DataFrame"),
    definition = `RankedList,DataFrame`
)



## Updated 2021-03-04.
`RankedList,DESeqResults` <-  # nolint
    function(
        object,
        value,
        keyType = c("geneName", "geneId"),
        gene2symbol
    ) {
        validObject(object)
        out <- RankedList(
            object = as(object, "DataFrame"),
            value = match.arg(value),
            keyType = match.arg(keyType),
            gene2symbol = gene2symbol
        )
        names(out) <- tryCatch(
            expr = contrastName(object),
            error = function(e) NULL
        )
        out
    }

formals(`RankedList,DESeqResults`)[["value"]] <- .rankedListValue



#' @rdname RankedList
#' @export
setMethod(
    f = "RankedList",
    signature = signature("DESeqResults"),
    definition = `RankedList,DESeqResults`
)



## Updated 2021-03-04.
`RankedList,DESeqAnalysis` <-  # nolint
    function(
        object,
        value,
        keyType = c("geneName", "geneId", "entrezId")
    ) {
        validObject(object)
        value <- match.arg(value)
        keyType <- match.arg(keyType)
        gene2symbol <- NULL
        ## Extract the DESeqResults list. Note that we're requiring shrunken
        ## LFCs if the user wants to return those values instead of using the
        ## Wald test statistic ("stat").
        resultsList <- slot(
            object = object,
            name = ifelse(
                test = identical(value, "log2FoldChange"),
                yes = "lfcShrink",
                no = "results"
            )
        )
        assert(is(resultsList, "list"))
        ## Entrez identifier mapping mode.
        switch(
            EXPR = keyType,
            "entrezId" = {
                dds <- as(object, "DESeqDataSet")
                rowData <- rowData(dds)
                if (hasColnames(rowData)) {
                    colnames(rowData) <-
                        camelCase(colnames(rowData), strict = TRUE)
                }
                if (!isSubset("entrezId", colnames(rowData))) {
                    stop("Object does not contain Entrez identifiers.")
                }
                g2e <- IntegerList(rowData[["entrezId"]])
                names(g2e) <- rownames(rowData)
                keep <- !all(is.na(g2e))
                g2e <- g2e[keep, , drop = FALSE]
                ## For genes that don't map 1:1, use the oldest identifier.
                g2e <- IntegerList(lapply(
                    X = g2e,
                    FUN = function(x) {
                        head(sort(na.omit(x)), n = 1L)
                    }
                ))
                g2e <- unlist(g2e, use.names = TRUE)
                assert(!any(is.na(g2e)))
                ## Replace the rownames in results list with Entrez identifiers.
                idx <- match(
                    x = names(g2e),
                    table = rownames(resultsList[[1L]])
                )
                assert(identical(length(idx), length(g2e)))
                if (length(idx) < nrow(dds)) {
                    n <- nrow(dds) - length(idx)
                    alertWarning(sprintf(
                        "Dropping %d %s without an Entrez identifier.",
                        n,
                        ngettext(
                            n = n,
                            msg1 = "gene",
                            msg2 = "genes"
                        )
                    ))
                }
                resultsList <- lapply(
                    X = resultsList,
                    FUN = function(x) {
                        x <- x[idx, , drop = FALSE]
                        rownames(x) <- unname(g2e)
                        x
                    }
                )
                keyType <- "geneId"
            },
            "geneName" = {
                ## Get the gene-to-symbol mappings. We're returning in long
                ## format so we can average the values for each gene symbol,
                ## since for some genomes gene IDs multi-map to symbols.
                suppressMessages({
                    gene2symbol <- Gene2Symbol(
                        object = as(object, "DESeqDataSet"),
                        format = "unmodified"
                    )
                })
            }
        )
        ## Get parameterized GSEA list values for each DESeqResults contrast.
        bplapply <- eval(.bplapply)
        list <- bplapply(
            X = resultsList,
            FUN = RankedList,
            value = value,
            keyType = keyType,
            gene2symbol = gene2symbol
        )
        ## Extract the required metadata from the first slotted return object
        ## defined from DESeqResults method.
        meta <- metadata(list[[1L]])
        ## Now loop across the DESeqResults method return and unlist, so we
        ## don't have an additional nested list level.
        list <- lapply(
            X = list,
            FUN = unlist,
            recursive = FALSE,
            use.names = FALSE
        )
        out <- SimpleList(list)
        metadata(out) <- meta
        new(Class = "RankedList", out)
    }

formals(`RankedList,DESeqAnalysis`)[["value"]] <-
    formals(`RankedList,DESeqResults`)[["value"]]



#' @rdname RankedList
#' @export
setMethod(
    f = "RankedList",
    signature = signature("DESeqAnalysis"),
    definition = `RankedList,DESeqAnalysis`
)



## Updated 2020-09-23.
`RankedList,FGSEAList` <-  # nolint
    function(object) {
        rl <- metadata(object)[["rankedList"]]
        assert(is(rl, "RankedList"))
        rl
    }



#' @rdname RankedList
#' @export
setMethod(
    f = "RankedList",
    signature = signature("FGSEAList"),
    definition = `RankedList,FGSEAList`
)
