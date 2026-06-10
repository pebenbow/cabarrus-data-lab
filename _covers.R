## Generates cover images for Research hub pages.
## Run manually after data changes: Rscript _covers.R
## Output: img/covers/{population,housing,farmland}.png

library(tidyverse)
library(sf)
library(scales)
library(duckdb)
library(DBI)

here::i_am("_quarto.yml")
library(here)

con     <- dbConnect(duckdb(),
  here("../cabarrus-data-pipeline/db/cabarrus.duckdb"),
  read_only = TRUE)
pop     <- dbReadTable(con, "nc_population_growth")
housing <- dbReadTable(con, "cabarrus_housing")
area    <- dbReadTable(con, "nlcd_landcover_area")
geom    <- dbReadTable(con, "raw_nc_geometry")
dbDisconnect(con, shutdown = TRUE)

dir.create(here("img/covers"), showWarnings = FALSE, recursive = TRUE)

cover_theme <- theme_minimal(base_size = 13) +
  theme(
    plot.background  = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    panel.grid.minor = element_blank(),
    plot.margin      = margin(12, 12, 12, 12)
  )

# ── Population: NC county growth rate choropleth ─────────────────────────────
nc <- geom |>
  st_as_sf(wkt = "geometry_wkt", crs = 4326) |>
  left_join(pop, by = "GEOID") |>
  mutate(is_cabarrus = GEOID == "37025")

p_pop <- ggplot(nc) +
  geom_sf(aes(fill = pct_growth), color = "white", linewidth = 0.15) +
  geom_sf(data = filter(nc, is_cabarrus),
          fill = NA, color = "#0336ff", linewidth = 1.4) +
  scale_fill_steps2(
    low = "#b2182b", mid = "#eeeeee", high = "#0336ff",
    midpoint = 0, n.breaks = 7, guide = "none",
    na.value = "#e0e0e0"
  ) +
  theme_void() +
  theme(plot.background = element_rect(fill = "white", color = NA),
        plot.margin     = margin(6, 6, 6, 6))

ggsave(here("img/covers/population.png"), p_pop,
       width = 8, height = 5, dpi = 150, bg = "white")
message("Saved: img/covers/population.png")

# ── Housing: indexed home value vs. income divergence ────────────────────────
housing_long <- housing |>
  select(year, idx_home, idx_rent, idx_income) |>
  pivot_longer(-year, names_to = "series", values_to = "index") |>
  mutate(series = recode(series,
    "idx_home"   = "Home Value",
    "idx_rent"   = "Annual Rent",
    "idx_income" = "Household Income"
  ))

p_housing <- ggplot(housing_long, aes(x = year, y = index, color = series)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray75",
             linewidth = 0.6) +
  geom_line(linewidth = 1.6) +
  annotate("text", x = min(housing$year) + 0.5, y = 103,
           label = "2006 = 100", color = "gray60", size = 3.5, hjust = 0) +
  scale_color_manual(
    values = c("Home Value" = "#0336ff",
               "Annual Rent" = "#e05c2a",
               "Household Income" = "#2ca02c"),
    name = NULL
  ) +
  scale_x_continuous(breaks = seq(2006, max(housing$year), by = 4)) +
  scale_y_continuous(labels = function(x) paste0(x)) +
  labs(x = NULL, y = "Index (2006 = 100)") +
  cover_theme +
  theme(legend.position = "bottom",
        legend.text = element_text(size = 11))

ggsave(here("img/covers/housing.png"), p_housing,
       width = 8, height = 5, dpi = 150, bg = "white")
message("Saved: img/covers/housing.png")

# ── Farmland: land cover change bar chart ────────────────────────────────────
yr_first <- min(area$year)
yr_last  <- max(area$year)

class_colors <- c(
  "Water/Barren"    = "#c8c8c8",
  "Developed"       = "#d73027",
  "Forest"          = "#4a8c5c",
  "Shrub/Grassland" = "#c3dba3",
  "Farmland"        = "#d4a72c",
  "Wetland"         = "#7ac8e0"
)

change_df <- area |>
  filter(year %in% c(yr_first, yr_last)) |>
  pivot_wider(names_from = year, values_from = acres) |>
  mutate(
    change = .data[[as.character(yr_last)]] - .data[[as.character(yr_first)]],
    class  = fct_reorder(class, change)
  )

p_farmland <- ggplot(change_df, aes(x = change, y = class, fill = class)) +
  geom_col(width = 0.65, show.legend = FALSE) +
  geom_vline(xintercept = 0, color = "#333333", linewidth = 0.5) +
  scale_fill_manual(values = class_colors) +
  scale_x_continuous(
    labels = function(x) paste0(ifelse(x >= 0, "+", ""),
                                comma(round(x)), " ac")
  ) +
  labs(
    x = paste0("Change in acres, ", yr_first, "–", yr_last),
    y = NULL
  ) +
  cover_theme +
  theme(panel.grid.major.y = element_blank())

ggsave(here("img/covers/farmland.png"), p_farmland,
       width = 8, height = 5, dpi = 150, bg = "white")
message("Saved: img/covers/farmland.png")

message("All cover images generated.")
