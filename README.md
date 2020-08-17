# acidgsea

[![Repo status: active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Travis CI build status](https://travis-ci.com/acidgenomics/acidgsea.svg?branch=master)](https://travis-ci.com/acidgenomics/acidgsea)
[![AppVeyor CI build status](https://ci.appveyor.com/api/projects/status/fa5hpl1hbf4memee/branch/master?svg=true)](https://ci.appveyor.com/project/mjsteinbaugh/acidgsea/branch/master)

Perform parameterized gene set enrichment analysis (GSEA) on multiple differential expression contrasts.

[acidgsea][] currently extends the functionality of [fgsea][].

## Installation

### [R][] method

```r
if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager")
}
install.packages(
    pkgs = "basejump",
    repos = c(
        "r.acidgenomics.com",
        BiocManager::repositories()
    )
)
```

[acidgsea]: https://acidgsea.acidgenomics.com/
[fgsea]: https://bioconductor.org/packages/fgsea/
[r]: https://www.r-project.org
