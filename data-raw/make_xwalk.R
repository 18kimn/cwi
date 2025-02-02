# output: block, block_grp, tract, town, town_fips, county, county_fips, msa, msa_fips, puma, puma_fips
sf::sf_use_s2(FALSE)

counties <- tidycensus::fips_codes %>%
  dplyr::filter(state == "CT") %>%
  dplyr::mutate(county_fips = paste0(state_code, county_code)) %>%
  dplyr::select(county, county_fips)

# no 2020 CB pumas yet
blocks <- tigris::blocks("09", year = 2020) %>%
  janitor::clean_names() %>%
  dplyr::filter(aland20 > 0) %>%
  dplyr::mutate(county_fips = paste0(statefp20, countyfp20)) %>%
  dplyr::mutate(tract = paste0(county_fips, tractce20)) %>%
  dplyr::mutate(block_grp = substr(geoid20, 1, 12)) %>%
  sf::st_drop_geometry() %>%
  dplyr::select(block = geoid20, block_grp, tract, county_fips)

puma_sf <- tigris::pumas("09", cb = FALSE, year = 2020) %>%
  janitor::clean_names() %>%
  dplyr::select(puma = namelsad10, puma_fips = geoid10) %>%
  dplyr::mutate(puma = stringr::str_remove(puma, " Towns?")) %>%
  dplyr::mutate(puma = stringr::str_remove(puma, " PUMA"))

msa_sf <- tigris::core_based_statistical_areas(cb = TRUE, year = 2020) %>%
  janitor::clean_names() %>%
  dplyr::filter(grepl("CT", name)) %>%
  dplyr::select(msa = name, msa_fips = geoid)

town2puma <- sf::st_join(town_sf, puma_sf, join = sf::st_intersects,
                         left = TRUE, largest = TRUE,
                         suffix = c("_town", "_puma")) %>%
  sf::st_drop_geometry() %>%
  dplyr::select(town = name, town_fips = GEOID, puma, puma_fips)

town2msa <- sf::st_join(town_sf, msa_sf, join = sf::st_intersects,
                        left = TRUE, largest = TRUE) %>%
  sf::st_drop_geometry() %>%
  dplyr::select(town = name, msa, msa_fips)

tract2town <- sf::st_join(tract_sf, town_sf, join = sf::st_intersects,
                          left = TRUE, largest = TRUE,
                          suffix = c("_tract", "_town")) %>%
  sf::st_drop_geometry() %>%
  dplyr::select(tract = name_tract, town = name_town) %>%
  dplyr::as_tibble()

xwalk <- blocks %>%
  dplyr::left_join(counties, by = "county_fips") %>%
  dplyr::left_join(tract2town, by = "tract") %>%
  dplyr::left_join(town2msa, by = "town") %>%
  dplyr::left_join(town2puma, by = "town") %>%
  dplyr::select(block, block_grp, tract, town, town_fips, county, county_fips, msa, msa_fips, puma, puma_fips) %>%
  dplyr::as_tibble()

usethis::use_data(xwalk, overwrite = TRUE)
usethis::use_data(tract2town, overwrite = TRUE)
