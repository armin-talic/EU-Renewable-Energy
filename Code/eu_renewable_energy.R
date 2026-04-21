# ==============================================================================
# SECTION 1: SETUP, DATA & THEMES
# ==============================================================================
library(tidyverse)
library(ggrepel)
library(sf)
library(rnaturalearth)
library(patchwork)
library(countrycode)
library(ggtext)
library(scales)

# 1. Base Data Filtering
eu_27_iso <- c('AUT', 'BEL', 'BGR', 'HRV', 'CYP', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRC', 'HUN', 'IRL', 'ITA', 'LVA', 'LTU', 'LUX', 'MLT', 'NLD', 'POL', 'PRT', 'ROU', 'SVK', 'SVN', 'ESP', 'SWE')
top3_countries <- c("Germany", "France", "Italy")

url <- "https://raw.githubusercontent.com/owid/energy-data/master/owid-energy-data.csv"
energy_data <- suppressMessages(read_csv(url, show_col_types = FALSE))

energy_data_countries <- energy_data %>% filter(iso_code %in% eu_27_iso)
energy_data_global <- energy_data %>% filter(!is.na(iso_code), !str_starts(iso_code, "OWID"))

# Dynamic Fallback: Find the latest year OWID actually has global GDP data
latest_gdp_year <- energy_data_global %>% filter(!is.na(gdp)) %>% pull(year) %>% max(na.rm = TRUE)
top20_gdp <- energy_data_global %>% filter(year == latest_gdp_year, !is.na(gdp)) %>% slice_max(gdp, n = 20) %>% pull(country)

top20_total <- energy_data_global %>% filter(year == 2024) %>% slice_max(primary_energy_consumption, n = 20) %>% pull(country)
if(length(top20_total) == 0) top20_total <- energy_data_global %>% filter(year == 2023) %>% slice_max(primary_energy_consumption, n = 20) %>% pull(country)

eu_data_faceted <- energy_data_countries %>% filter(year >= 2000, year <= 2024)

# 2024 Infographic Base (with Malta fallback)
data_main <- energy_data_countries %>% filter(year == 2024)
malta_fix <- energy_data_countries %>% filter(year == 2023, iso_code == "MLT")
infographic_data <- bind_rows(data_main, malta_fix) %>%
  mutate(country_display = ifelse(iso_code == "MLT", paste0(country, "*"), country))

world <- ne_countries(scale = "medium", returnclass = "sf") %>%
  mutate(iso_a3 = ifelse(admin == "France", "FRA", iso_a3))

# 2. Design System
col_bg <- "#22332B"
col_yellow <- "#E1D566"
col_green <- "#558C77"
col_bright_green <- "#7AC994"
col_red <- "#C25953"
col_blue <- "#628395"
text_light <- "#F4F1EA"
text_muted <- "#A4B5AC"

dark_theme <- theme_minimal() +
  theme(
    panel.grid = element_blank(),
    plot.background = element_rect(fill = col_bg, color = NA),
    panel.background = element_rect(fill = col_bg, color = NA),
    text = element_text(color = text_light),
    axis.text = element_text(color = text_light),
    axis.title = element_text(color = text_light, face = "bold"),
    plot.title = element_text(color = text_light, face = "bold"),
    plot.subtitle = element_text(color = text_muted),
    plot.caption = element_text(color = text_muted, face = "italic"),
    legend.background = element_rect(fill = "transparent", color = NA),
    legend.text = element_text(color = text_light),
    legend.title = element_text(color = text_light, face = "bold"),
    strip.text = element_text(color = text_light, face = "bold")
  )

format_k_whole <- function(x) ifelse(is.na(x), NA, paste0(round(x / 1000, 0), " K"))

theme_left <- function() {
  dark_theme + theme(
    panel.grid = element_blank(), axis.line = element_line(color = "#354A40"),
    plot.title = element_text(size = 14, face = "bold", hjust = 0.5, margin = margin(b=10)),
    axis.title.x = element_blank(), axis.title.y = element_text(size = 10, face = "bold", margin = margin(r=10)),
    axis.text = element_text(size = 9), plot.margin = margin(t = 10, r = 5, b = 10, l = 10)
  )
}

theme_right <- function() {
  dark_theme + theme(
    panel.grid = element_blank(), strip.text = element_text(face="bold", size = 11, margin = margin(b=8), color = text_light), 
    panel.spacing.y = unit(1.5, "lines"), axis.line = element_line(color = "#354A40"),
    plot.title = element_text(size = 14, face = "bold", hjust = 0.5, margin = margin(b=10)),
    axis.title.y = element_blank(), axis.title.x = element_blank(),
    axis.text = element_text(size = 9), plot.margin = margin(t = 10, r = 10, b = 10, l = 5)
  )
}

assemble_transition_plot <- function(p_left, p_right, title, subtitle = NULL) {
  (p_left | p_right) + 
    plot_layout(widths = c(1, 1.8), guides = "collect") +
    plot_annotation(title = title, subtitle = subtitle,
                    theme = dark_theme + theme(
                      plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
                      plot.subtitle = element_text(size = 12, hjust = 0.5, margin = margin(b = 15), color = text_muted),
                      legend.position = "right", legend.direction = "vertical", legend.title = element_blank(), legend.text = element_text(size = 10)
                    )
    )
}

# ==============================================================================
# SECTION 2: TOTAL ENERGY CONSUMPTION
# ==============================================================================

# Chart 2A: Energy Consumption Infographic (Map + Bar)
total_eu_energy <- sum(infographic_data$primary_energy_consumption, na.rm = TRUE)
map1_data <- infographic_data %>%
  filter(!is.na(primary_energy_consumption)) %>%
  arrange(desc(primary_energy_consumption)) %>%
  mutate(
    rank = row_number(),
    map_label = ifelse(rank <= 5, paste0(rank, ". ", country_display, "\n", scales::comma(round(primary_energy_consumption)), " TWh"), NA)
  )

top5_pct <- round((sum(map1_data$primary_energy_consumption[1:5], na.rm = TRUE) / total_eu_energy) * 100, 1)

map1_sf <- world %>% left_join(map1_data %>% select(iso_code, primary_energy_consumption, map_label, rank), by = c("iso_a3" = "iso_code")) %>% mutate(is_target = iso_a3 %in% eu_27_iso)
map1_labels <- map1_sf %>% filter(is_target, !is.na(primary_energy_consumption), rank <= 5)

centroids1 <- suppressWarnings(st_coordinates(st_centroid(map1_labels$geometry)))
map1_labels$lon <- centroids1[,1]
map1_labels$lat <- centroids1[,2]

map1_labels <- map1_labels %>%
  mutate(
    lon = ifelse(iso_a3 == "FRA", 2.2137, lon), lat = ifelse(iso_a3 == "FRA", 46.2276, lat),
    nudge_x_dir = case_when(iso_a3 %in% c('FRA', 'DEU') ~ -12, iso_a3 %in% c('ITA', 'ESP') ~ 0, TRUE ~ 12),
    nudge_y_dir = case_when(iso_a3 %in% c('ITA', 'ESP') ~ -6, TRUE ~ 0)
  )

plot_map1 <- ggplot() +
  geom_sf(data = map1_sf %>% filter(is_target), aes(fill = primary_energy_consumption), color = "grey60", linewidth = 0.2) +
  scale_fill_gradient(low = "#2A3D34", high = col_yellow, na.value = "#1E2D26") +
  geom_text_repel(data = map1_labels, aes(x = lon, y = lat, label = map_label),
                  size = 3.5, fontface = "bold", color = text_light, bg.color = col_bg, bg.r = 0.15, 
                  segment.color = text_muted, 
                  nudge_x = map1_labels$nudge_x_dir, nudge_y = map1_labels$nudge_y_dir,
                  min.segment.length = 0, max.overlaps = Inf) +
  coord_sf(ylim = c(31, 71), xlim = c(-15, 40), expand = TRUE) + theme_void() + dark_theme +
  theme(legend.position = "none", axis.text = element_blank(), axis.title = element_blank(), axis.ticks = element_blank(),
        plot.title = element_text(size = 16, hjust = 0.5, margin = margin(t=10, b=15)), plot.margin = margin(t = 0.5, r = -2, b = 0.5, l = 1, "cm")) +
  labs(title = "Total Energy Consumption")

bar_data <- infographic_data %>% filter(!is.na(energy_per_capita)) %>% mutate(country_display = fct_reorder(country_display, energy_per_capita))
eu_avg_energy_pc <- mean(bar_data$energy_per_capita, na.rm = TRUE)

plot_bar <- ggplot(bar_data, aes(y = country_display, x = energy_per_capita, fill = energy_per_capita)) +
  geom_col(width = 0.75) + geom_vline(xintercept = eu_avg_energy_pc, linetype = "dashed", color = text_muted, linewidth = 0.8) +
  annotate("text", y = 27.5, x = eu_avg_energy_pc, label = paste0("EU Avg: ", format_k_whole(eu_avg_energy_pc)), vjust = 0, hjust = -0.1, color = text_muted, fontface = "bold", size = 3) +
  geom_label(aes(label = format_k_whole(energy_per_capita)), fill = col_bg, label.size = NA, hjust = -0.2, size = 3, fontface = "bold", color = text_light) +
  scale_fill_gradient(low = "#2A3D34", high = col_yellow) + scale_x_continuous(expand = expansion(mult = c(0, 0.15)), labels = format_k_whole) +
  coord_cartesian(clip = "off") + theme_minimal() + dark_theme +
  theme(legend.position = "none", axis.text.y = element_text(size = 9, face = "bold"), axis.text.x = element_text(size = 9, color = text_muted), axis.title.x = element_text(size = 11, margin = margin(t = 10)), axis.title.y = element_blank(), plot.title = element_text(size = 16, hjust = 0.5, margin = margin(t=10, b=15)), panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(color = "#354A40", linetype = "dotted"), plot.margin = margin(t = 0.5, r = 5, b = 0.5, l = -2, "cm")) + labs(title = "Energy Use per Capita", x = "")

chart_energy_consumption_infographic <- (plot_map1 | plot_bar) + plot_layout(widths = c(3.5, 1.5)) + 
  plot_annotation(title = "Primary Energy Consumption (2024)", subtitle = paste0("Untransformed energy demand for heating, transport, and electricity. \n The top 5 countries make up ", top5_pct, "% of total EU primary energy demand."), caption = "* Malta data is from 2023", theme = dark_theme + theme(plot.title = element_text(size = 26, hjust = 0.5, margin = margin(t = 20, b = 5)), plot.subtitle = element_text(size = 14, hjust = 0.5, margin = margin(b = 20))))

# Chart 2B: Total Primary Energy Mix (Agg vs Top 3)
pal_3 <- c("Fossil"=col_red, "Nuclear"="#8C7A6B", "Renewables"=col_bright_green)

p3_left <- eu_data_faceted %>% group_by(year) %>% summarise(Fossil = sum(fossil_fuel_consumption, na.rm=T), Nuclear = sum(nuclear_consumption, na.rm=T), Renewables = sum(renewables_consumption, na.rm=T)) %>% pivot_longer(-year, names_to="source", values_to="twh") %>% mutate(source = factor(source, levels = names(pal_3))) %>%
  ggplot(aes(x = year, y = twh, fill = source)) + geom_area(position="fill", alpha=0.9, color=col_bg, linewidth=0.1) + scale_fill_manual(values = pal_3) + scale_y_continuous(labels = scales::percent, expand=c(0,0)) + theme_left() + labs(title = "EU-27 Aggregate", y = "Share of Energy")

p3_right <- eu_data_faceted %>% filter(country %in% top3_countries) %>% select(country, year, fossil_fuel_consumption, nuclear_consumption, renewables_consumption) %>% pivot_longer(-c(country, year), names_to="source", values_to="twh") %>% mutate(source = factor(source, labels = names(pal_3)), country = factor(country, levels = top3_countries)) %>%
  ggplot(aes(x = year, y = twh, fill = source)) + geom_area(position="fill", alpha=0.9, color=col_bg, linewidth=0.1) + facet_wrap(~country, ncol = 1) + scale_fill_manual(values = pal_3) + scale_y_continuous(labels = scales::percent, expand=c(0,0)) + theme_right() + labs(title = "Top 3 Primary Energy Consumers")

chart_energy_mix <- assemble_transition_plot(p3_left, p3_right, "Primary Energy by Source")

# Chart 2C: Renewable Mix Share Stacked Bar (2024)
plot_ren_mix <- energy_data_countries %>% filter(iso_code %in% eu_27_iso, !is.na(renewables_share_energy), !is.na(solar_share_energy), !is.na(wind_share_energy), year == 2024) %>% mutate(other_renew_share = ifelse(renewables_share_energy - solar_share_energy - wind_share_energy < 0, 0, renewables_share_energy - solar_share_energy - wind_share_energy), country = fct_reorder(country, renewables_share_energy))
plot_ren_long <- plot_ren_mix %>% select(country, `Solar` = solar_share_energy, `Wind` = wind_share_energy, `Other Renewables` = other_renew_share) %>% pivot_longer(cols = c(`Solar`, `Wind`, `Other Renewables`), names_to = "Source", values_to = "Share") %>% mutate(Source = factor(Source, levels = c("Other Renewables", "Wind", "Solar")))

chart_ren_mix_stacked_bar <- ggplot() + geom_col(data = plot_ren_long, aes(x = country, y = Share, fill = Source), width = 0.7, alpha = 0.95) +
  geom_text(data = plot_ren_mix, aes(x = country, y = renewables_share_energy, label = paste0(round(renewables_share_energy, 0), "%")), hjust = -0.2, size = 3.5, color = text_light, fontface = "bold") +
  scale_fill_manual(values = c("Solar" = col_yellow, "Wind" = col_blue, "Other Renewables" = col_bright_green)) + coord_flip(clip = "off", expand = FALSE) + scale_y_continuous(limits = c(0, max(plot_ren_mix$renewables_share_energy) * 1.15)) + dark_theme +
  theme(panel.grid.major.y = element_blank(), axis.title.y = element_blank(), axis.text.y = element_text(size = 9, face = "bold"), legend.position = "top", legend.title = element_blank(), plot.title = element_text(size = 18, hjust = 0), plot.subtitle = element_text(size = 11, hjust = 0, margin=margin(b=15)), plot.margin = margin(1, 1.5, 1, 1, "cm")) + 
  labs(title = "Renewable Energy Share of Primary Energy (2024)", subtitle = "Breakdown of total energy demand met by Solar, Wind, and Other Renewables (Hydro, Bio) for EU Countries (excluding Malta).", y = "% of Total Primary Energy")


# ==============================================================================
# SECTION 3: ELECTRICITY GENERATION & GRID
# ==============================================================================

# Chart 3A: Electricity Generation by Source
pal_8 <- c("Coal"="#354A40", "Oil"="#7A2E2B", "Gas"=col_red, "Nuclear"="#8C7A6B", "Hydro"=col_green, "Biofuel"=text_muted, "Wind"=col_blue, "Solar"=col_yellow)

p2_left <- eu_data_faceted %>% group_by(year) %>% summarise(across(c(coal_electricity, gas_electricity, oil_electricity, nuclear_electricity, wind_electricity, solar_electricity, hydro_electricity, biofuel_electricity), ~sum(., na.rm=TRUE))) %>% pivot_longer(-year, names_to="source", values_to="twh") %>% mutate(source = str_replace(source, "_electricity", "") %>% str_to_title(), source = factor(source, levels=names(pal_8))) %>%
  ggplot(aes(x = year, y = twh, fill = source)) + geom_area(position = "fill", color = col_bg, linewidth = 0.1) + scale_fill_manual(values = pal_8) + scale_y_continuous(labels = scales::percent, expand = c(0,0)) + theme_left() + labs(title = "EU-27 Aggregate", y = "Share of Electricity")

p2_right <- eu_data_faceted %>% filter(country %in% top3_countries) %>% select(country, year, coal_electricity, gas_electricity, oil_electricity, nuclear_electricity, wind_electricity, solar_electricity, hydro_electricity, biofuel_electricity) %>% pivot_longer(-c(country, year), names_to="source", values_to="twh") %>% mutate(source = str_replace(source, "_electricity", "") %>% str_to_title(), source = factor(source, levels=names(pal_8)), country = factor(country, levels = top3_countries)) %>%
  ggplot(aes(x = year, y = twh, fill = source)) + geom_area(position = "fill", color = col_bg, linewidth = 0.1) + facet_wrap(~country, ncol = 1) + scale_fill_manual(values = pal_8) + scale_y_continuous(labels = scales::percent, expand = c(0,0)) + theme_right() + labs(title = "Top 3 Primary Energy Consumers")

chart_elec_source <- assemble_transition_plot(p2_left, p2_right, "Electricity Generation by Source (2024)")

# Chart 3B: Coal vs Renewables
pal_battle <- c("Coal"="#7A2E2B", "Renewables"=col_bright_green)

p8_left <- eu_data_faceted %>% group_by(year) %>% summarise(coal = sum(coal_electricity, na.rm=T), ren = sum(renewables_electricity, na.rm=T)) %>%
  ggplot(aes(x = year)) + geom_line(aes(y = coal, color="Coal"), linewidth=1.2) + geom_line(aes(y = ren, color="Renewables"), linewidth=1.2) + geom_ribbon(aes(ymin=pmin(coal, ren), ymax=pmax(coal, ren), fill=ren>coal), alpha=0.2) + scale_color_manual(values = pal_battle) + scale_fill_manual(values=c("FALSE"="#7A2E2B", "TRUE"=col_bright_green), guide="none") + theme_left() + labs(title="EU-27 Aggregate", y="Generation (TWh)")

p8_right <- eu_data_faceted %>% filter(country %in% top3_countries) %>% mutate(country=factor(country, levels=top3_countries)) %>%
  ggplot(aes(x = year)) + geom_line(aes(y = coal_electricity, color="Coal"), linewidth=1.2) + geom_line(aes(y = renewables_electricity, color="Renewables"), linewidth=1.2) + geom_ribbon(aes(ymin=pmin(coal_electricity, renewables_electricity), ymax=pmax(coal_electricity, renewables_electricity), fill=renewables_electricity>coal_electricity), alpha=0.2) + facet_wrap(~country, ncol=1, scales="free_y") + scale_color_manual(values = pal_battle) + scale_fill_manual(values=c("FALSE"="#7A2E2B", "TRUE"=col_bright_green), guide="none") + theme_right() + labs(title="Top 3 Primary Energy Consumers")

chart_coal_vs_ren <- assemble_transition_plot(p8_left, p8_right, "Coal vs. Renewables (Electricity Generation)")

# Chart 3C: Fossil Heatmap
fossil_trend_data <- energy_data_countries %>% filter(year >= 2000, year <= 2024, !is.na(fossil_share_elec))
order_fossil_2024 <- fossil_trend_data %>% filter(year == max(year)) %>% arrange(fossil_share_elec) %>% pull(country)
fossil_heatmap_data <- fossil_trend_data %>% mutate(country = factor(country, levels = rev(order_fossil_2024)))
fossil_diff_data <- energy_data_countries %>% filter(year %in% c(2000, 2024), !is.na(fossil_share_elec)) %>% select(country, year, fossil_share_elec) %>% pivot_wider(names_from = year, values_from = fossil_share_elec, names_prefix = "yr_") %>% drop_na() %>% mutate(shift = yr_2024 - yr_2000, shift_label = ifelse(shift > 0, paste0("+", round(shift, 0), "%"), paste0(round(shift, 0), "%")), country = factor(country, levels = rev(order_fossil_2024)))

plot_fossil_heatmap <- ggplot(fossil_heatmap_data, aes(x = year, y = country, fill = fossil_share_elec)) +
  geom_tile(color = col_bg, linewidth = 0.4) + 
  geom_text(data = fossil_heatmap_data %>% filter(year == max(year)), aes(label = paste0(round(fossil_share_elec, 0), "%")), color = text_light, size = 3, fontface = "bold", show.legend = FALSE) +
  scale_fill_gradientn(colors = c(col_bright_green, col_yellow, col_red, "#7A2E2B"), limits = c(0, 100), breaks = seq(0, 100, 25), labels = function(x) paste0(x, "%")) +
  scale_x_continuous(expand = c(0, 0), breaks = seq(2000, 2024, 5)) + dark_theme +
  theme(axis.text.y = element_text(face = "bold", size = 9, margin = margin(r = 10)), axis.title = element_blank(), legend.position = "top", legend.justification = "center") +
  guides(fill = guide_colorbar(title = "Fossil Fuel %", title.position = "top", title.hjust = 0.5, direction = "horizontal", barwidth = unit(8, "cm")))

plot_fossil_diff <- ggplot(fossil_diff_data, aes(x = shift, y = country, fill = shift)) + geom_col(width = 0.7) +
  geom_text(aes(label = shift_label, hjust = ifelse(shift < 0, 1.2, -0.2)), size = 3, fontface = "bold", color = text_light) +
  scale_fill_gradient2(low = col_bright_green, mid = "#4A5D53", high = col_red, midpoint = 0) + scale_x_continuous(position = "top", expand = expansion(mult = c(0.4, 0.4))) + dark_theme +
  theme(legend.position = "none", axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank(), axis.title.y = element_blank(), axis.title.x.top = element_text(size = 10, face = "bold", hjust = 0.5)) + labs(x = "2000 to 2024 Change")

chart_fossil_heatmap <- plot_fossil_heatmap + plot_fossil_diff + plot_layout(widths = c(6, 1.5)) + 
  plot_annotation(title = "Grid Decarbonization (2000 to 2024)", subtitle = "Percentage of electricity generated from fossil fuels (2000 vs 2024)", theme = dark_theme + theme(plot.title = element_text(size = 24, face = "bold", hjust = 0.5), plot.subtitle = element_text(size = 14, hjust = 0.5, color = text_muted)))

# Chart 3D: Grid Gap Dumbbell
dumbbell_data_gap <- energy_data_countries %>% filter(iso_code %in% eu_27_iso) %>% group_by(iso_code) %>% filter(year == 2024) %>% ungroup() %>% select(country, fossil_share_elec, renewables_share_elec, nuclear_share_elec) %>% mutate(nuclear_share_elec = replace_na(nuclear_share_elec, 0)) %>% drop_na(fossil_share_elec, renewables_share_elec) %>% mutate(low_carbon_share = renewables_share_elec + nuclear_share_elec, country = fct_reorder(country, low_carbon_share))

chart_grid_gap_dumbbell <- ggplot(dumbbell_data_gap) +
  geom_segment(aes(y = country, yend = country, x = low_carbon_share, xend = fossil_share_elec), color = "#4A5D53", linewidth = 1.2) +
  geom_point(aes(y = country, x = low_carbon_share, color = "Low-Carbon (Renewable + Nuclear)"), size = 3.5) + geom_point(aes(y = country, x = fossil_share_elec, color = "Fossil Fuels"), size = 3.5) +
  scale_color_manual(values = c("Fossil Fuels" = col_red, "Low-Carbon (Renewable + Nuclear)" = col_bright_green)) + dark_theme +
  theme(panel.grid = element_blank(), plot.title = element_text(size = 18, margin = margin(b = 5)), axis.text.y = element_text(size = 9, face = "bold"), legend.position = "top", legend.title = element_blank()) +
  labs(title = "The Grid Gap (2024)", subtitle = "Fossil vs. Low-Carbon Share", x = "% Share of Total Electricity Generation", y = NULL)

# Chart 3E: Butterfly Comparison (Renewable Electricity 2010 vs 2024)
country_names <- energy_data_countries %>% select(iso_code, country) %>% distinct()
d_2010 <- energy_data_countries %>% filter(year == 2010, iso_code %in% eu_27_iso) %>% select(iso_code, val_2010 = renewables_share_elec)
d_2024 <- energy_data_countries %>% filter(year <= 2024, iso_code %in% eu_27_iso, !is.na(renewables_share_elec)) %>% group_by(iso_code) %>% arrange(desc(year)) %>% slice(1) %>% ungroup() %>% select(iso_code, val_2024 = renewables_share_elec, fallback_year = year)
comp_data <- tibble(iso_code = eu_27_iso) %>% left_join(d_2010, by = "iso_code") %>% left_join(d_2024, by = "iso_code") %>% left_join(country_names, by = "iso_code") %>% mutate(shift = val_2024 - val_2010, country_display = ifelse(!is.na(fallback_year) & fallback_year < 2024, paste0(country, "*"), country), country_display = fct_reorder(country_display, replace_na(val_2024, -1)))
max_limit <- max(c(comp_data$val_2010, comp_data$val_2024), na.rm = TRUE) * 1.15
thm_clear <- theme_void() + dark_theme + theme(axis.text=element_blank(), axis.title=element_blank(), axis.ticks=element_blank(), panel.grid=element_blank())

p_left_b <- ggplot(comp_data, aes(y = country_display)) + geom_col(aes(x = val_2010), fill = "#4A5D53", width = 0.6, na.rm = TRUE) + geom_text(aes(x = val_2010, label = ifelse(is.na(val_2010), "", paste0(round(val_2010, 0), "%"))), hjust = 1.2, color = text_muted, size = 4, fontface = "bold", na.rm = TRUE) + scale_x_reverse(limits = c(max_limit, 0), expand = c(0,0)) + labs(subtitle = "2010") + thm_clear + theme(plot.margin = margin(t=10,r=0,b=10,l=10), plot.subtitle=element_text(hjust=0.5, size=18, face="bold", color=text_muted, margin=margin(b=15)))
p_mid_b <- ggplot(comp_data, aes(y = country_display)) + geom_text(aes(x = 0, label = country_display), color = text_light, fontface = "bold", size = 4.5) + scale_x_continuous(limits = c(-0.1, 0.1), expand = c(0,0)) + labs(subtitle = " ") + thm_clear + theme(plot.margin = margin(t=10,r=0,b=10,l=0))
p_right_b <- ggplot(comp_data, aes(y = country_display)) + geom_col(aes(x = val_2024), fill = col_bright_green, width = 0.6, na.rm = TRUE) + geom_text(aes(x = val_2024, label = ifelse(is.na(val_2024), "", paste0(round(val_2024, 0), "%"))), hjust = -0.2, color = col_bright_green, size = 4, fontface = "bold", na.rm = TRUE) + scale_x_continuous(limits = c(0, max_limit), expand = c(0,0)) + labs(subtitle = "2024") + thm_clear + theme(plot.margin = margin(t=10,r=10,b=10,l=0), plot.subtitle=element_text(hjust=0.5, size=18, face="bold", color=col_bright_green, margin=margin(b=15)))

chart_ren_butterfly <- (p_left_b | p_mid_b | p_right_b) + plot_layout(widths = c(4, 0.8, 4)) + plot_annotation(title = "Renewable Electricity (2010 vs 2024)", theme = dark_theme + theme(plot.title = element_text(size = 24, hjust = 0.5, margin=margin(t=10,b=5)), plot.margin = margin(1,1,1,1,"cm")))

# ==============================================================================
# SECTION 4: RENEWABLES
# ==============================================================================

# Chart 4A: Renewable Share Maps
build_eu_renewable_map <- function(yr, metric_col, map_title) {
  target_data <- infographic_data %>% filter(!is.na(!!sym(metric_col))) %>% select(iso_code, metric_val = !!sym(metric_col))
  top3 <- target_data %>% arrange(desc(metric_val)) %>% head(3)
  iso2_codes <- tolower(countrycode(top3$iso_code, origin = "iso3c", destination = "iso2c"))
  flag_imgs <- paste0("<img src='https://flagcdn.com/w40/", iso2_codes, ".png' width='18' height='13' style='vertical-align: middle;'/>")
  legend_html <- paste0("<b style='font-size:12pt; color:", col_yellow, ";'>Top 3 Leaders</b><br><br>", paste(flag_imgs, paste0(" <span style='color:", text_light, "; vertical-align: middle;'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b> ", round(top3$metric_val, 1), "%</b></span>"), sep = "", collapse = "<br><br>"))
  
  world_sf <- world %>% left_join(target_data, by = c("iso_a3" = "iso_code")) %>% mutate(is_eu = iso_a3 %in% eu_27_iso, has_data = !is.na(metric_val))
  
  ggplot() +
    geom_sf(data = world_sf %>% filter(is_eu, !has_data), fill = "#1E2D26", color = "grey60", linewidth = 0.2) +
    geom_sf(data = world_sf %>% filter(is_eu, has_data), aes(fill = metric_val), color = "grey60", linewidth = 0.2) +
    scale_fill_gradientn(colors = c(col_red, col_yellow, col_bright_green), limits = c(0, 100), breaks = c(0, 25, 50, 75, 100), labels = function(x) paste0(x, "%"), name = "Renewable Share:", na.value = "#1E2D26") +
    annotate("richtext", x = -11, y = 69, label = legend_html, hjust = 0, vjust = 1, fill = alpha(col_bg, 0.8), color = text_muted, label.padding = unit(c(0.8, 0.8, 0.8, 0.8), "lines"), label.r = unit(0.2, "lines")) +
    coord_sf(ylim = c(31, 71), xlim = c(-15, 40), expand = TRUE) + theme_void() + dark_theme +
    theme(legend.position = "bottom", legend.direction = "horizontal", legend.key.width = unit(2.5, "cm"), axis.text = element_blank(), axis.title = element_blank(), axis.ticks = element_blank(), plot.title = element_text(size = 18, hjust = 0.5, margin = margin(t=10, b=15))) +
    guides(fill = guide_colorbar(title.position = "top", title.hjust = 0.5, barheight = unit(0.4, "cm"))) + labs(title = map_title)
}

chart_renewable_maps <- (build_eu_renewable_map(2024, "renewables_share_elec", "Renewable Electricity (2024)") | build_eu_renewable_map(2024, "renewables_share_energy", "Renewable Energy Total (2024)")) + plot_layout(guides = "collect") & theme(legend.position = "bottom", legend.justification = "center")

# Chart 4B: Composition of Renewables
pal_ren <- c("Wind"=col_blue, "Solar"=col_yellow, "Other"=col_green)

p4_left <- eu_data_faceted %>% group_by(year) %>% summarise(Wind = sum(wind_electricity, na.rm=T), Solar = sum(solar_electricity, na.rm=T), Other = sum(hydro_electricity, na.rm=T) + sum(biofuel_electricity, na.rm=T)) %>% pivot_longer(-year, names_to="source", values_to="twh") %>% mutate(source = factor(source, levels=names(pal_ren))) %>%
  ggplot(aes(x = year, y = twh, fill = source)) + geom_area(position="fill", color=col_bg, linewidth=0.1) + scale_fill_manual(values = pal_ren, labels=c("Wind", "Solar", "Other Renewables")) + scale_y_continuous(labels = scales::percent, expand=c(0,0)) + theme_left() + labs(title="EU-27 Aggregate", y="Share of Renewables")

p4_right <- eu_data_faceted %>% filter(country %in% top3_countries) %>% mutate(Other = hydro_electricity + biofuel_electricity) %>% select(country, year, wind_electricity, solar_electricity, Other) %>% pivot_longer(-c(country, year), names_to="source", values_to="twh") %>% mutate(source = factor(source, levels=c("Other", "wind_electricity", "solar_electricity"), labels=names(pal_ren)), country = factor(country, levels=top3_countries)) %>%
  ggplot(aes(x = year, y = twh, fill = source)) + geom_area(position="fill", color=col_bg, linewidth=0.1) + facet_wrap(~country, ncol=1) + scale_fill_manual(values = pal_ren) + scale_y_continuous(labels = scales::percent, expand=c(0,0)) + theme_right() + labs(title="Top 3 Primary Energy Consumers")

chart_ren_composition <- assemble_transition_plot(p4_left, p4_right, "Composition of Renewables (Electricity)")

# Chart 4C: Wind Farm
wind_top10 <- energy_data_global %>% filter(year == 2024, !is.na(wind_electricity)) %>% slice_max(wind_electricity, n = 10) %>% mutate(x_pos = as.numeric(fct_reorder(country, -wind_electricity)), is_eu = iso_code %in% eu_27_iso, blade_col = ifelse(is_eu, text_light, "#354A40"), tower_col = ifelse(is_eu, text_muted, "#2A3D34"))
if(nrow(wind_top10) == 0) wind_top10 <- energy_data_global %>% filter(year == 2023, !is.na(wind_electricity)) %>% slice_max(wind_electricity, n = 10) %>% mutate(x_pos = as.numeric(fct_reorder(country, -wind_electricity)), is_eu = iso_code %in% eu_27_iso, blade_col = ifelse(is_eu, text_light, "#354A40"), tower_col = ifelse(is_eu, text_muted, "#2A3D34"))
y_blade <- max(wind_top10$wind_electricity) * 0.08
x_blade <- 0.35

plot_wind_farm <- ggplot(wind_top10, aes(x = x_pos, y = wind_electricity)) +
  geom_segment(aes(xend = x_pos, y = 0, yend = wind_electricity, color = tower_col), linewidth = 2) +
  geom_segment(aes(xend = x_pos, y = wind_electricity, yend = wind_electricity + y_blade, color = blade_col), linewidth = 1) +
  geom_segment(aes(xend = x_pos + x_blade, y = wind_electricity, yend = wind_electricity - (y_blade * 0.6), color = blade_col), linewidth = 1) +
  geom_segment(aes(xend = x_pos - x_blade, y = wind_electricity, yend = wind_electricity - (y_blade * 0.6), color = blade_col), linewidth = 1) +
  geom_point(color = col_bg, size = 1.5) +
  geom_text(aes(label = round(wind_electricity, 0), y = wind_electricity + (y_blade * 1.8), color = blade_col), fontface = "bold", size = 3) +
  scale_color_identity() + scale_x_continuous(breaks = 1:10, labels = levels(fct_reorder(wind_top10$country, -wind_top10$wind_electricity))) +
  dark_theme + theme(axis.line.x = element_line(color = col_bright_green, linewidth = 2), panel.grid = element_blank(), axis.title = element_blank()) +
  labs(title = "Top 10 Wind Energy Producers (2024)", subtitle = "TWh generated. EU countries are highlighted; others are dimmed.")

# Chart 4D: Solar Sunburst (Bubble Grid)
solar_top10 <- energy_data_global %>% filter(year == 2024, !is.na(solar_electricity)) %>% slice_max(solar_electricity, n = 10) %>% arrange(desc(solar_electricity)) %>% mutate(rank = row_number(), row = ifelse(rank <= 5, 2, 1), col = ifelse(rank <= 5, rank, rank - 5), is_eu = iso_code %in% eu_27_iso, color_flag = ifelse(is_eu, col_yellow, "#354A40"))
if(nrow(solar_top10) == 0) solar_top10 <- energy_data_global %>% filter(year == 2023, !is.na(solar_electricity)) %>% slice_max(solar_electricity, n = 10) %>% arrange(desc(solar_electricity)) %>% mutate(rank = row_number(), row = ifelse(rank <= 5, 2, 1), col = ifelse(rank <= 5, rank, rank - 5), is_eu = iso_code %in% eu_27_iso, color_flag = ifelse(is_eu, col_yellow, "#354A40"))

plot_sunburst <- ggplot(solar_top10, aes(x = col, y = row)) +
  geom_point(aes(size = solar_electricity), color = solar_top10$color_flag, alpha = 0.9) +
  geom_text(aes(label = paste0(country, "\n", round(solar_electricity, 1), " TWh")), nudge_y = -0.38, color = text_light, fontface = "bold", size = 3.5, lineheight = 1.1) +
  scale_size_continuous(range = c(8, 30), guide = "none") +
  scale_y_continuous(limits = c(0.2, 2.5)) +
  scale_x_continuous(limits = c(0.5, 5.5)) +
  dark_theme + theme(axis.text = element_blank(), axis.title = element_blank(), panel.grid = element_blank(), axis.line = element_blank()) +
  labs(title = "Top 10 Solar Energy Producers (2024)", subtitle = "Total solar generation (TWh). Bubble size represents energy produced. EU nations highlighted in yellow.")


# ==============================================================================
# SECTION 5: EMISSIONS (ELECTRICITY SECTOR)
# ==============================================================================

# Chart 5A: Shadow Chart Emissions Grid
emissions_data_shadow <- energy_data_global %>% filter(country %in% top20_total, !is.na(greenhouse_gas_emissions)) %>% group_by(country) %>% mutate(base_em = first(greenhouse_gas_emissions), pct_change = ((greenhouse_gas_emissions - base_em) / base_em) * 100, trend = ifelse(last(greenhouse_gas_emissions) > base_em, "Increasing", "Decreasing")) %>% ungroup()
bg_shadow <- emissions_data_shadow %>% select(year, pct_change, shadow_group = country)


# Chart 5B: Global Imbalance Area Chart
valid_data_burden <- energy_data_global %>% filter(year >= 2000, year <= 2024, !is.na(greenhouse_gas_emissions), !is.na(population), !is.na(iso_code))
top10_2024 <- valid_data_burden %>% filter(year == 2024) %>% slice_max(greenhouse_gas_emissions, n = 10) %>% pull(country)
if(length(top10_2024) == 0) top10_2024 <- valid_data_burden %>% filter(year == 2023) %>% slice_max(greenhouse_gas_emissions, n = 10) %>% pull(country)
rest_label <- "Rest of World"

dual_area_data <- valid_data_burden %>% mutate(group_country = ifelse(country %in% top10_2024, country, rest_label)) %>% group_by(year, group_country) %>% summarise(total_ghg = sum(greenhouse_gas_emissions, na.rm = TRUE), total_pop = sum(population, na.rm = TRUE), .groups = "drop") %>% mutate(group_country = factor(group_country, levels = c(rest_label, rev(top10_2024))))
top10_pal <- setNames(c(col_red, col_blue, col_yellow, col_bright_green, "#8C7A6B", "#D48C70", col_green, "#628395", "#A4B5AC", "#E1D566"), top10_2024)
top10_pal[rest_label] <- "#354A40"

plot_ghg_share <- ggplot(dual_area_data, aes(x = year, y = total_ghg, fill = group_country)) + geom_area(position = "fill", color = col_bg, linewidth = 0.1) + scale_fill_manual(values = top10_pal) + scale_y_continuous(labels = scales::percent, expand = c(0, 0)) + dark_theme + theme(legend.position = "none", axis.title.x = element_blank()) + labs(title = "Share of Global Electricity Emissions", y = "100% Total")
plot_pop_share <- ggplot(dual_area_data, aes(x = year, y = total_pop, fill = group_country)) + geom_area(position = "fill", color = col_bg, linewidth = 0.1) + scale_fill_manual(values = top10_pal) + scale_y_continuous(labels = scales::percent, expand = c(0, 0)) + dark_theme + theme(axis.title = element_blank()) + labs(title = "Share of Global Population")

final_comparison_burden <- (plot_ghg_share | plot_pop_share) + plot_layout(guides = "collect") + plot_annotation(title = "The Global Imbalance: Electricity Emissions vs. Population", theme = dark_theme + theme(plot.title = element_text(hjust = 0.5, size = 20), legend.position = "bottom", legend.title = element_blank()))

# Chart 5C: Top 100 Heatmap
pc_data <- energy_data_global %>% filter(year >= 2000, year <= 2024, !is.na(greenhouse_gas_emissions), !is.na(population)) %>% mutate(ghg_pc = (greenhouse_gas_emissions * 1e6) / population)
top100_2024 <- pc_data %>% filter(year == max(year)) %>% slice_max(ghg_pc, n = 100) %>% pull(country)
trend_pc_data <- pc_data %>% filter(country %in% top100_2024) %>% mutate(country = factor(country, levels = rev(top100_2024)))
actual_max_pc <- suppressWarnings(max(trend_pc_data$ghg_pc, na.rm = TRUE))
if (is.infinite(actual_max_pc)) actual_max_pc <- 10 

plot_top100_ordered <- ggplot(trend_pc_data, aes(x = year, y = country, fill = ghg_pc)) +
  geom_tile(color = col_bg, linewidth = 0.1) +
  scale_fill_gradientn(colors = c(col_bright_green, "#8FBC8F", col_yellow, col_red, "#C32148"), values = scales::rescale(c(0, 2.45, 4.9, (4.9 + actual_max_pc)/2, actual_max_pc), to = c(0, 1)), limits = c(0, actual_max_pc), breaks = c(0, 4.9, actual_max_pc), labels = c("0", "4.9\n(Global Avg)", paste0(round(actual_max_pc, 1), " Tonnes\n(Max)")), name = "Emissions Per Capita (Tonnes):", na.value = col_bg) +
  scale_x_continuous(expand = c(0, 0), breaks = seq(2000, 2024, 2)) + dark_theme +
  theme(panel.grid = element_blank(), legend.position = "top", legend.direction = "horizontal", legend.title = element_text(face = "bold", size = 11, color = text_light), legend.text = element_text(size = 10, color = text_muted), legend.key.width = unit(4, "cm"), legend.key.height = unit(0.4, "cm"), legend.margin = margin(t = 10, b = 20), axis.text.y = element_text(size = 8, color = text_light, face = "bold"), axis.ticks = element_blank(), axis.text.x = element_text(size = 10, face = "bold", color = text_muted), plot.title = element_text(size = 20, face = "bold", color = text_light, hjust = 0.5), plot.subtitle = element_text(size = 12, color = text_muted, hjust = 0.5, margin = margin(b=15)), plot.margin = margin(1, 1, 1, 1, "cm")) +
  labs(title = "Electricity Emissions Per Capita (Top 100)", subtitle = "Countries ordered from highest to lowest based on their most recent footprint.", x = "Year", y = NULL) + guides(fill = guide_colorbar(title.position = "left", title.vjust = 0.8))


# ==============================================================================
# SECTION 6: ECONOMICS & EFFICIENCY
# ==============================================================================
# Chart 6B: EU Economic Decoupling Ribbon
eu_agg_wide_dec <- energy_data_countries %>% filter(year >= 2000, !is.na(gdp), !is.na(primary_energy_consumption)) %>% group_by(year) %>% summarise(gdp = sum(gdp, na.rm = TRUE), primary_energy_consumption = sum(primary_energy_consumption, na.rm = TRUE), .groups = 'drop') %>% mutate(idx_gdp = (gdp / gdp[year == 2000]) * 100, idx_energy = (primary_energy_consumption / primary_energy_consumption[year == 2000]) * 100)
eu_agg_long_dec <- eu_agg_wide_dec %>% select(year, idx_gdp, idx_energy) %>% pivot_longer(cols = c(idx_gdp, idx_energy), names_to = "metric", values_to = "index") %>% mutate(metric = ifelse(metric == "idx_gdp", "GDP", "Energy Use"))

top3_data_dec <- energy_data_countries %>% filter(year >= 2000, country %in% top3_countries, !is.na(gdp), !is.na(primary_energy_consumption)) %>% group_by(country) %>% mutate(idx_gdp = (gdp / gdp[year == 2000]) * 100, idx_energy = (primary_energy_consumption / primary_energy_consumption[year == 2000]) * 100) %>% ungroup()
top3_labels_dec <- top3_data_dec %>% group_by(country) %>% filter(year == max(year)) %>% mutate(decoup_val = round(idx_gdp - idx_energy, 1), facet_label = paste0(country, " (+", decoup_val, " pts)")) %>% select(country, facet_label)
top3_wide_dec <- top3_data_dec %>% left_join(top3_labels_dec, by = "country") %>% mutate(country = factor(country, levels = top3_countries), facet_label = fct_reorder(facet_label, as.numeric(country)))
top3_long_dec <- top3_wide_dec %>% select(country, facet_label, year, idx_gdp, idx_energy) %>% pivot_longer(cols = c(idx_gdp, idx_energy), names_to = "metric", values_to = "index") %>% mutate(metric = ifelse(metric == "idx_gdp", "GDP", "Energy Use"), country = factor(country, levels = top3_countries), facet_label = fct_reorder(facet_label, as.numeric(country)))

plot_eu_dec <- ggplot() + geom_ribbon(data = eu_agg_wide_dec, aes(x = year, ymin = idx_energy, ymax = idx_gdp), fill = col_bright_green, alpha = 0.2) + geom_hline(yintercept = 100, linetype = "dashed", color = text_muted) + geom_line(data = eu_agg_long_dec, aes(x = year, y = index, color = metric), linewidth = 1.2) + geom_point(data = eu_agg_long_dec %>% filter(year == max(year)), aes(x = year, y = index, color = metric), size = 3, show.legend = FALSE) + geom_text(data = eu_agg_long_dec %>% filter(year == max(year)), aes(x = year, y = index, label = round(index, 1), color = metric), hjust = -0.3, fontface = "bold", size = 4, show.legend = FALSE) + scale_color_manual(values = c("GDP" = col_blue, "Energy Use" = col_yellow)) + scale_y_continuous(limits = c(70, 150)) + scale_x_continuous(expand = expansion(mult = c(0.02, 0.15))) + dark_theme + theme(plot.margin = margin(t = 0.5, r = 1, b = 0.5, l = 0.5, "cm")) + labs(title = "EU-27 Aggregate", x = NULL, y = "Index (2000 = 100)")
plot_top3_dec <- ggplot() + geom_ribbon(data = top3_wide_dec, aes(x = year, ymin = idx_energy, ymax = idx_gdp), fill = col_bright_green, alpha = 0.2, show.legend = FALSE) + geom_hline(yintercept = 100, linetype = "dashed", color = text_muted) + geom_line(data = top3_long_dec, aes(x = year, y = index, color = metric), linewidth = 1, show.legend = FALSE) + facet_wrap(~facet_label, ncol = 1) + scale_color_manual(values = c("GDP" = col_blue, "Energy Use" = col_yellow)) + scale_y_continuous(limits = c(70, 150)) + scale_x_continuous(expand = expansion(mult = c(0.02, 0.20))) + dark_theme + theme(plot.margin = margin(t = 0.5, r = 0.5, b = 0.5, l = 1, "cm"), strip.text = element_text(color = text_light, face = "bold", size = 11)) + labs(title = "Top 3 Primary Energy Consumers", x = NULL, y = "Index")

chart_eu_decoupling_ribbon <- (plot_eu_dec | plot_top3_dec) + plot_layout(widths = c(1.3, 1), guides = "collect") + plot_annotation(title = "Efficiency & Decoupling", caption = "* GDP is adjusted for inflation and differences in living costs between countries.", theme = dark_theme + theme(plot.title = element_text(size = 24, hjust = 0.5, margin = margin(t = 15, b = 5)), plot.caption = element_text(size = 10, hjust = 0, color = text_muted, face = "italic", margin = margin(t = 15)))) & theme(legend.position = "bottom", legend.justification = "center", legend.title = element_blank(), legend.text = element_text(size = 13, face = "bold"))


# Top 10 World Economies (Reliable source: World Bank / IMF 2023/2024 GDP Rankings)
top_10_economies <- c("United States", "China", "Germany", "Japan", "India", 
                      "United Kingdom", "France", "Italy", "Brazil", "Canada")


global_data_dec <- energy_data %>%
  filter(year >= 2000, country %in% top_10_economies, !is.na(gdp), !is.na(primary_energy_consumption)) %>%
  # Ensure we only have one row per country-year by summarizing just in case there are duplicates
  group_by(country, year) %>%
  summarise(
    gdp = sum(gdp, na.rm = TRUE),
    primary_energy_consumption = sum(primary_energy_consumption, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(country) %>%
  # Safely extract the base year (2000) value using max/mean trick to ensure length 1
  mutate(
    base_gdp = max(gdp[year == 2000], na.rm = TRUE),
    base_energy = max(primary_energy_consumption[year == 2000], na.rm = TRUE),
    idx_gdp = (gdp / base_gdp) * 100,
    idx_energy = (primary_energy_consumption / base_energy) * 100
  ) %>%
  ungroup() %>%
  # Handle cases where base year was 0 or NA (creates Inf/NaN)
  filter(is.finite(idx_gdp), is.finite(idx_energy))

# 2. Create Labels with Decoupling Difference (End Year)
global_labels_dec <- global_data_dec %>%
  group_by(country) %>%
  filter(year == max(year)) %>%
  mutate(
    decoup_val = round(idx_gdp - idx_energy, 1),
    # If GDP is higher than Energy, it's positive decoupling (+)
    sign = ifelse(decoup_val >= 0, "+", ""),
    facet_label = paste0(country, " (", sign, decoup_val, " pts)")
  ) %>%
  select(country, facet_label)

# 3. Join Labels and Prepare Wide/Long Formats
global_wide_dec <- global_data_dec %>%
  left_join(global_labels_dec, by = "country") %>%
  mutate(
    country = factor(country, levels = top_10_economies),
    facet_label = fct_reorder(facet_label, as.numeric(country))
  )

global_long_dec <- global_wide_dec %>%
  select(country, facet_label, year, idx_gdp, idx_energy) %>%
  pivot_longer(cols = c(idx_gdp, idx_energy), names_to = "metric", values_to = "index") %>%
  mutate(
    metric = ifelse(metric == "idx_gdp", "GDP", "Energy Use"),
    country = factor(country, levels = top_10_economies),
    facet_label = fct_reorder(facet_label, as.numeric(country))
  )

# 4. Create the Faceted Ribbon Chart (Matching your dark_theme design)
chart_global_decoupling_ribbon <- ggplot() +
  # The green/red ribbon. If you only want green like the EU chart, remove the ifelse and just use col_bright_green.
  # Here we use a trick to show green if GDP > Energy, red if Energy > GDP (optional, or stick to solid green)
  geom_ribbon(data = global_wide_dec, 
              aes(x = year, ymin = idx_energy, ymax = idx_gdp), 
              fill = col_bright_green, alpha = 0.2, show.legend = FALSE) +
  geom_hline(yintercept = 100, linetype = "dashed", color = text_muted) +
  geom_line(data = global_long_dec, aes(x = year, y = index, color = metric), linewidth = 1) +
  scale_color_manual(values = c("GDP" = col_blue, "Energy Use" = col_yellow)) +
  # Set Y-axis scale identically for all countries from 50 to 600
  scale_y_continuous(limits = c(50, 600)) +
  # Removed scales = "free_y" so all charts share the exact same fixed axis
  facet_wrap(~ facet_label, nrow = 2) + 
  dark_theme +
  theme(
    plot.margin = margin(t = 1, r = 1, b = 1, l = 1, "cm"),
    strip.text = element_text(color = text_light, face = "bold", size = 11),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 13, face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  labs(
    title = "Top 10 Global Economies: Efficiency & Decoupling",
    subtitle = "Change in GDP vs. Primary Energy Consumption (Index: 2000 = 100)",
    x = NULL, 
    y = "Index"
  )

print(chart_global_decoupling_ribbon)
# ==============================================================================
# SECTION 7: PRINT & EXPORT
# ==============================================================================

# Primary Energy and Renewables
print(chart_energy_consumption_infographic)
print(chart_energy_mix)
print(chart_ren_mix_stacked_bar)

# Electricity
print(chart_elec_source)
print(chart_ren_composition)
print(chart_coal_vs_ren)
print(chart_fossil_heatmap)
print(chart_grid_gap_dumbbell)
print(chart_ren_butterfly)

# Wind and Solar Global Leaders 
print(plot_wind_farm)
print(plot_sunburst)

# Economic Decoupling
print(chart_eu_decoupling_ribbon)
