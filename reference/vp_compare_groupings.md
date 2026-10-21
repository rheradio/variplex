# How alike two groupings are

How alike two groupings of the same features are: 1 when they are the
same, near 0 when they are unrelated (normalised mutual information).
Each grouping is a tibble with a column `feature` and one column of
group labels.

## Usage

``` r
vp_compare_groupings(a, b, method = "nmi")
```

## Arguments

- a:

  A grouping: a tibble with a column `feature` and one column of group
  labels, such as the result of
  [`vp_communities()`](https://rheradio.github.io/variplex/reference/vp_communities.md).

- b:

  Another grouping of the same features.

- method:

  The measure of similarity, as in
  [`igraph::compare()`](https://r.igraph.org/reference/compare.html):
  `"nmi"` (normalised mutual information), `"vi"`, `"split.join"`,
  `"rand"` or `"adjusted.rand"`.

## Value

A number: 1 for the same grouping, near 0 for unrelated ones.

## See also

Other patterns:
[`vp_baseline()`](https://rheradio.github.io/variplex/reference/vp_baseline.md),
[`vp_communities()`](https://rheradio.github.io/variplex/reference/vp_communities.md),
[`vp_coreness()`](https://rheradio.github.io/variplex/reference/vp_coreness.md),
[`vp_cut_features()`](https://rheradio.github.io/variplex/reference/vp_cut_features.md),
[`vp_feature_groups()`](https://rheradio.github.io/variplex/reference/vp_feature_groups.md),
[`vp_independent_parts()`](https://rheradio.github.io/variplex/reference/vp_independent_parts.md),
[`vp_odd_ones()`](https://rheradio.github.io/variplex/reference/vp_odd_ones.md),
[`vp_power_law()`](https://rheradio.github.io/variplex/reference/vp_power_law.md),
[`vp_robustness()`](https://rheradio.github.io/variplex/reference/vp_robustness.md),
[`vp_similar_features()`](https://rheradio.github.io/variplex/reference/vp_similar_features.md),
[`vp_triangle_significance()`](https://rheradio.github.io/variplex/reference/vp_triangle_significance.md),
[`vp_triangles()`](https://rheradio.github.io/variplex/reference/vp_triangles.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_compare_groupings(
  vp_communities(band, seed = 1),
  vp_communities(band, seed = 2)
)
#> [1] 1
```
