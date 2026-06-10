# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cabarrus Data Lab is a Quarto-based static website for data-driven journalism focused on Cabarrus County, NC. Source files are `.qmd` (Quarto Markdown) that can contain R code chunks for data analysis and visualization. The rendered output goes to `docs/` and is served via GitHub Pages at cabarrusdatalab.com.

## Style rules

- **No em dashes.** Never use `—` in prose, YAML descriptions, code comments, or string literals. Use a colon, comma, parentheses, semicolon, or reword the clause instead.

## Commands

```bash
# Render all source files to docs/
quarto render

# Start local dev server with live reload
quarto preview

# Render a single file
quarto render path/to/file.qmd
```

## Architecture

**Source → Output flow:**
- `.qmd` files (source) → `quarto render` → `docs/` (HTML, served by GitHub Pages)
- R code chunks in `.qmd` files are executed at render time (e.g., Census API calls, ggplot2 plots)
- `_quarto.yml` controls site-wide settings: theme (Cosmo + `styles.scss`), navbar, base URL, output directory
- Listing pages (`blog/index.qmd`, `analysis/index.qmd`) auto-generate indexes from their subdirectories

**Content sections:**
- `index.qmd` — Home page (about section + featured posts)
- `about.qmd` — Project/people page
- `blog/posts/` — Individual blog posts (numbered `0001-slug.qmd`, ...)
- `stories/` — Scrollytelling feature stories (closeRead format)
- `data-briefs/` — One-page PDF reports (Typst format, rendered separately)

**Key files:**
- `_quarto.yml` — Site config (theme, nav, output dir, repo URL)
- `styles.scss` — Custom styling (colors, fonts, card hover effects)
- `_extensions/royfrancis/accordion/` — Accordion UI component extension
- `_extensions/qmd-lab/closeread/` — Scrollytelling extension (v1.0.1)

**Deployment:** Push to `main`; GitHub Pages serves from `docs/`. No CI/CD workflows — rendering is done locally before committing.

## Feature Stories (closeRead scrollytelling)

Feature stories live in `stories/` and use `format: closeread-html` (extension at `_extensions/qmd-lab/closeread/`). Install once per repo with:

```bash
quarto add qmd-lab/closeread --no-prompt
```

**closeRead structure:**

```markdown
:::{.cr-section}
Narrative text that references sticky blocks. @cr-myblock

:::{#cr-myblock}
Content that sticks while the user scrolls past the text.
:::
:::
```

**Critical gotcha — htmlwidgets in sticky blocks:** `leaflet` maps placed inside `:::{#cr-id}` sticky blocks render as blank. The widget fails to initialize inside the hidden/opacity-transitioned container closeRead uses for sticky elements. Fix: put `ggplot2` static PNG maps in sticky blocks; move `leaflet` maps to a non-sticky section below all `.cr-section` divs, where they initialize properly on page load.

**Plotly animated line chart (cumulative reveal):**

```r
cum_frames <- map_df(seq_len(nrow(df)), function(i) {
  df[1:i, ] |> mutate(frame_id = df$year[i])
})
plot_ly(cum_frames, x=~year, y=~value, frame=~frame_id, ...) |>
  animation_opts(frame=120, easing="linear", redraw=FALSE) |>
  animation_button(label="&#9654; Play") |>
  animation_slider(currentvalue=list(prefix="Year: "))
```

This draws the line progressively. Use `redraw=FALSE` to prevent the y-axis from rescaling on each frame.

## Data Briefs (Typst PDF format)

One-page PDF reports live in `data-briefs/`. They use `format: typst` with a custom CDL-branded header/footer and stat-box callouts defined in `include-in-header`. Render individually (not as part of the site build):

```bash
quarto render data-briefs/0001-home-prices-wages.qmd
# → docs/data-briefs/0001-home-prices-wages.pdf
```

**Typst gotcha:** inline R expressions (`` `r expr` ``) are NOT evaluated inside `{=typst}` raw blocks. Instead, build the Typst string in R and emit it with `cat()` in a chunk with `#| results: asis`.

**SVG blurriness:** ggplot2 embeds the colorbar for continuous scales (`scale_fill_gradient2`, `scale_fill_viridis_c`, etc.) as a raster bitmap inside the SVG. Typst then rasterizes the whole figure at low DPI. Fix: use `#| dev: png` and `#| dpi: 300` on any `geom_sf` chunk, or switch to a binned scale (`scale_fill_steps2`, `scale_fill_stepsn`) to keep the legend vector.

## Content Conventions

- Blog posts and analysis briefs are prefixed with a 4-digit number (`0001-`, `0002-`, ...) to control ordering
- YAML frontmatter in each post controls title, date, author, categories, description, and image for listing pages
- The `docs/` directory is committed to the repo (not gitignored) — always run `quarto render` before committing content changes

## R Dependencies

Key R packages used: `tidyverse`, `tidycensus` (Census Bureau ACS data), `viridis`, `sf`, `spdep` (spatial analysis), `terra` (raster processing), `tigris` (Census boundaries). R environment is managed via the RStudio project (`cabarrus-data-lab.Rproj`).

**Note on land cover data:** Both `FedData::get_nlcd()` (MRLC WCS, changed coverage IDs) and `cdlTools::getCDL()` (CropScape WCS, returns NULL on this machine due to network issues) failed programmatically. CDL data for `0003-vanishing-farmland.qmd` is loaded from local GeoTIFFs in `data-briefs/data/`, downloaded manually from `nassgeodata.gmu.edu/CropScape` using "Download by County" for Cabarrus County (FIPS 37025), years 2008, 2015, and 2023.

**Raster workflow notes (`terra`):**
- Load CDL GeoTIFFs with `terra::rast("data/cdl_cabarrus_YYYY.tif")` (path relative to `data-briefs/`).
- Use `terra::subst(r, from, to)` for value reclassification across the full CDL class range (0-255).
- Mask to county boundary with `terra::mask(terra::vect(cabarrus_proj))`.
- Use `terra::subst(r, from, to)` for direct value substitution (reclassification).
- Use `terra::freq(r, bylayer=FALSE)` to count pixels per class, then multiply by cell area (`prod(terra::res(r)) / 4046.86`) to get acres.
- Use `terra::aggregate(r, fact=5, fun="modal")` to downsample to 150m for map display.
- Convert to data frame for ggplot2 with `as.data.frame(r, xy=TRUE)`; the third column is the layer name, rename defensively.
- On Windows, set `options(timeout=300)` before any network download.

## External Data Sources (no API key required)

| Source | What | URL pattern |
|---|---|---|
| Zillow Research | County ZHVI (middle tier, monthly) | `https://files.zillowstatic.com/research/public_csvs/zhvi/County_zhvi_uc_sfrcondo_tier_0.33_0.67_sm_sa_month.csv` |
| FRED | FHFA All-Transactions HPI for Cabarrus (`ATNHPIUS37025A`) | `https://fred.stlouisfed.org/graph/fredgraph.csv?id=ATNHPIUS37025A` |
| USDA NASS CropScape | Cropland Data Layer (via `cdlTools::getCDL(fips, year)`) | annual 30m raster by county FIPS; NC available from 2008; more reliable than MRLC WCS |

Cabarrus County FIPS: state `37`, county `025`. Filter Zillow CSV with `StateCodeFIPS == 37, MunicipalCodeFIPS == "025"`. Use `freeze: auto` on documents that fetch these large files.
