#' @title Vectorized function to enrich GO exact terms with a list of gene sets against a common background.
#' @return a \code{list} of \code{data.frame} for GO exact enrichment result.
#' @details \code{goea} conduct regular goea analysis with Fisher's exact test / permutation test.
#' @param gene_set a list of character vectors contains gene IDs of the query gene sets.
#' @param back_ground a character vector contains the IDs of the background genes.
#' @param orgDb an \code{OrgDb} object defined by AnnotationDbi.
#' @param category a character specifying the gene ontology category, can be one in "BP", "CC", and "MF", default "BP".
#' @param gene_key a character specifying the type of the gene ID, the available types of the keys can be find using \code{keytypes(org.Hs.eg.db)}, default "ENTREZID".
#' @param min_bg_count term minimum number of occurence in background genes; default 1.
#' @param max_bg_count term maximum number of occurence in background genes; default Inf.
#' @param min_gs_count term minimum number of occurence in gene set genes; default 1.
#' @param max_gs_count term maximum number of occurence in gene set genes; default Inf.
#' @param EASE_Score whether or not use EASE score method. (a more conservative hypergeomatric test calculation used in DAVID)
#'for more details please refer to \url{https://david.ncifcrf.gov/helps/functional_annotation.html#fisher}, default FALSE.
#' @param pvalue_correction method used for multiple hypothesis adjustment, can be one in "holm", "hochberg", "hommel", "bonferroni", "BH", "BY","fdr", and "none".
#' @param interpret_term whether to let the GO term readable, default FALSE.
#' @param show_gene_name whether to attach readable gene names for each GO term, default FALSE.
#' @param GO_Slim whether to run GSEA only on GO slim terms (a certain subset to GO terms), default FALSE.
#' @param Slim_ss a character sting of GO terms that define the scope of GO Slim. if not provided, the GO slim would be the generic subset defined in : \url{http://geneontology.org/ontology/subsets/goslim_generic.obo}
#' @param Exclude_self whether the GO slim terms of its own category should be removed. i.e. remove terms of c("GO:0008150","GO:0005575","GO:0003674"), default TRUE; this option is only applied when GO_Slim = TRUE.
#'
#' @importFrom AnnotationDbi select Term
#' @importFrom GO.db GOTERM
#' @export
goea <- function(gene_set,
                 back_ground,
                       orgDb,
                       category="BP",
                       gene_key = "ENTREZID",
                       min_bg_count = 1,
                       max_bg_count = Inf,
                       min_gs_count = 1,
                       max_gs_count = Inf,
                       EASE_Score= F,
                       pvalue_correction = "BH",
                       interpret_term = F,
                       show_gene_name = F,
                       GO_Slim = F,
                       Slim_ss = NULL,
                       Exclude_self = T
                       ) {

  if(any(duplicated(back_ground))) {
    warning("back_ground gene IDs contain duplicated terms, the duplicates are removed",call. = TRUE)
    back_ground = unique(back_ground)
  }

  if(class( gene_set ) == "character") { gene_set = list(gene_set) }

  if(any(sapply(gene_set, function(x) any(duplicated(x)) ))) {
    warning("gene set gene IDs contain duplicated terms, the duplicates are removed",call. = TRUE)
    gene_set = lapply(gene_set, function(x) unique(x))
  }

  stopifnot(category %in% c("BP","CC","MF"))

  GO_indx <- gene2go(Gene_ID = back_ground,
                     Gene_key_type = gene_key,
                     OrgDB = orgDb,
                     Category = category,
                     Slim = GO_Slim,
                     Slim_subset = Slim_ss,
                     Exclude_self_slim = Exclude_self)

  GO_tb <- table(GO_indx$GO)

  filter_go <- GO_tb >= min_bg_count & GO_tb <= max_bg_count

  GO_indx <- GO_indx[ GO_indx$GO %in% (names(GO_tb)[filter_go]), ] #Drop the genes that do not have our interested GO terms.

  Freq_bg <- table( as.character( GO_indx$GO ) )

  bg_genes_num <- length( unique(GO_indx[[gene_key]]) )

  result_lst <- list()

  for(i in 1:length(gene_set) ) {

    indx_match <- GO_indx[[gene_key]] %in% gene_set[[i]]

    Freq_gs <- table( as.character( GO_indx$GO [ indx_match ] ) )

    Freq_gs <- Freq_gs[ Freq_gs >= min_gs_count & Freq_gs <= max_gs_count ]

    result_lst[[i]] <- gsea(
      freq_gs = Freq_gs,
      freq_bg = Freq_bg,
      gs_total_gene = length(unique(GO_indx[[gene_key]] [indx_match])),
      bg_total_gene = bg_genes_num,
      adj_method = pvalue_correction,
      ease = EASE_Score
    )

  }

  if(show_gene_name) {
    gene_names <- suppressWarnings( select(orgDb, keys = GO_indx[[gene_key]], columns = c("GENENAME"), keytype = gene_key) )
    gene_names <- gene_names [!duplicated( gene_names$ENTREZID ),"GENENAME"]
    gene_names <- split(gene_names,GO_indx$GO)
    result_lst <- Map(function(x,y) {
     y$genes_names = sapply( gene_names[as.character( y$term )], paste0, collapse = ", ")
     return(y)
    }, gene_set,
    result_lst)
  }

  if(interpret_term) {
    term_defs <- Term(GOTERM)
    result_lst <- lapply(result_lst, function(x) {
      x$definition = term_defs[as.character(x$term)]
      return(x[,c(1,7,2,3,4,5,6)])
    })
  }

  if(length(result_lst) == 1){
  return(result_lst[[1]])
  } else {
  names(result_lst) = names(gene_set)
  return( result_lst )
  }
}
