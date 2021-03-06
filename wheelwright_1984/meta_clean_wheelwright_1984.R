# Set libraries
library(reshape2)
library(tidyr)
#library(jsonlite)
library(httr)
library(data.table)
library(rcrossref)
library(taxize)
library(stringr)

library(mangal)

#------------------------------
  # Metadata
#------------------------------

lat  <- 10.3
lon  <- -84.8
srid <- 4326

# Must fill all CAP fields; null fields optional

attr_inter <- list(name        = "Bird-fruit interaction",
                   table_owner = "interactions",
                   description = "Presence-absence of interaction",
                   unit        = "NA")

# attr1 <- list(name        = "NAME",
#               table_owner = "TABLE_OWNER",
#               description = "DESCRIPTION",
#               unit        = "null")

# attr2 <- list(name        = "NAME",
#               table_owner = "TABLE_OWNER",
#               description = "DESCRIPTION",
#               unit        = "null")

ref <- list(doi        = "10.2307/2388051",
             jstor     = "NA",
             pmid      = "NA",
             paper_url = "http://download.bioon.com.cn/upload/month_0910/20091008_db07aa6c85868f647dc6uVyGu2wEUWil.attach.pdf",
             data_url  = "http://www.web-of-life.es/map.php?type=5",
             author    = "wheelwright",
             year      = "1984",
             bibtex    = "@article{Wheelwright_1984,doi = {10.2307/2388051},url = {https://doi.org/10.2307%2F2388051},year = 1984,month = {sep},publisher = {{JSTOR}},volume = {16},number = {3},pages = {173},author = {Nathaniel T. Wheelwright and William A. Haber and K. Greg Murray and Carlos Guindon},title = {Tropical Fruit-Eating Birds and Their Food Plants: A Survey of a Costa Rican Lower Montane Forest},journal = {Biotropica}}")


users <- list(name         = "Gabriel Bergeron",
              email        = "gabriel.bergeron3@usherbrooke.ca",
              orcid        = "null",
              organization = "Universite de Sherbrooke",
              type         = "administrator")


enviro <- list(name  = "attribute name",
               lat   = lat,
               lon   = lon,
               srid  = srid,
               date  = "1111-11-11",
               value = 0)


dataset <- list(name         = "wheelwringht_1984",
                 date        = "1978-01-01",
                 description = "Bird-fruit interaction in the lower montane forests of Monteverde, Costa Rica",
                 public      = TRUE)


trait <- list(date = "1111-11-11")


network <- list(name             = "wheelwringht_1984",
                 date             = "1978-01-01",
                 lat              = lat,
                 lon              = lon,
                 srid             = srid,
                 description      = "Bird-fruit interaction in the lower montane forests of Monteverde, Costa Rica",
                 public           = TRUE,
                 all_interactions = FALSE)


inter <- list(taxon_1_level = "taxon",
              taxon_2_level = "taxon",
              date          = "1978-01-01",
              direction     = "directed",
              type          = "mutualism",
              method        = "field observations",
              description   = "null",
              public        = TRUE,
              lat           = lat,
              lon           = lon,
              srid          = srid)



#------------------------------
  # Cleaning matrix
#------------------------------

# Open file
wheelwright_1984 <- read.csv2(file = "mangal-datasets/wheelwright_1984/raw/wheelwright_1984.csv", header = FALSE, sep = ",")

# Cleaning for melt()
## Get ROW one with Genus_species
x  <- unname(unlist(wheelwright_1984[1, ]))
x[1] <- 1
colnames(wheelwright_1984) <- unlist(x)
rm(x)

## Delete unused row
wheelwright_1984 <- wheelwright_1984[-1, ]

# Melt df
wheelwright_1984 <- melt(wheelwright_1984, id.vars = c(1), na.rm = TRUE)

# Remove interaction value = 0 (no interaction)
names(wheelwright_1984) <- c("sp_taxon_1", "sp_taxon_2", "value")
wheelwright_1984 <- subset(wheelwright_1984, wheelwright_1984$value != 0)

#------------------------------
# Set taxo_back and taxon table
#------------------------------
# Create taxo_back_df

## Get Unique taxon of data
taxa <- c(as.vector(unique(wheelwright_1984$sp_taxon_2)), as.vector(unique(wheelwright_1984$sp_taxon_1)))


### Check for spelling mistakes... ###


### Remove sp

taxa_back <- vector()

for (i in 1:length(taxa)) {

  if(((str_detect(taxa[i], "[:digit:]") == TRUE || str_detect(taxa[i], "[:punct:]") == TRUE) &
       str_detect(taxa[i], "sp") == TRUE) ||
       str_detect(taxa[i], "n\\.i\\.") ||
       str_detect(taxa[i], "sp$")){

    taxa_back[i] <- word(taxa[i], start = 1)

  } else {
    taxa_back[i] <- taxa[i]
  }
}

taxa_back <- unique(taxa_back)


## Select only taxa not yet in db

server <- "http://poisotlab.biol.umontreal.ca"

taxa_back_df <- data.frame()

for (i in 1:length(taxa_back)) {

  path <- modify_url(server, path = paste0("/api/v2/","taxa_back/?name=", str_replace(taxa_back[i], " ", "%20")))

  if (length(content(GET(url = path, config = add_headers("Content-type" = "application/json", 
                                                          "Authorization" = paste("bearer", readRDS("mangal-datasets/.httr-oauth")))))) == 0) {

    taxa_back_df[nrow(taxa_back_df)+1, 1] <- taxa_back[i]
  }
}

rm(taxa_back)
names(taxa_back_df) <- c("name")

## Get code by species
taxa_back_df[, "bold"] <- NA
taxa_back_df[, "eol"]  <- NA
taxa_back_df[, "tsn"]  <- NA
taxa_back_df[, "ncbi"] <- NA

### Encore probleme d"identification avec les api... ###

for (i in 1:nrow(taxa_back_df)) {
  try (expr = (taxa_back_df[i, 2] <- get_boldid(taxa_back_df[i, 1], row = 5, verbose = FALSE)[1]), silent = TRUE)
  try (expr = (taxa_back_df[i, 3] <- get_eolid(taxa_back_df[i, 1], row = 5, verbose = FALSE, key = 110258)[1]), silent = TRUE)
  try (expr = (taxa_back_df[i, 4] <- get_tsn(taxa_back_df[i, 1], row = 5, verbose = FALSE, accepted = TRUE)[1]), silent = TRUE)
  try (expr = (taxa_back_df[i, 5] <- get_uid(taxa_back_df[i, 1], row = 5, verbose = FALSE)[1]), silent = TRUE)
}

# Create taxa_df

taxa_df <- data.frame(taxa, NA)
names(taxa_df) <- c("original_name", "name_clear")

for (i in 1:nrow(taxa_df)) {

  if(((str_detect(taxa_df[i, 1], "[:digit:]") == TRUE || str_detect(taxa_df[i, 1], "[:punct:]") == TRUE) &
       str_detect(taxa_df[i, 1], "sp") == TRUE) ||
       str_detect(taxa_df[i, 1], "n\\.i\\.") == TRUE ||
      str_detect(taxa_df[i, 1], "sp$") == TRUE){

    taxa_df[i, 2] <- word(taxa_df[i, 1], start = 1)

  } else {
    taxa_df[i, 2] <- as.character(taxa_df[i, 1])
  }
}

#------------------------------
# Set traits table
#------------------------------

# traits_df <- read.csv2(file = "mangal-datasets/wheelwright_1984/data/wheelwright_1984_traits.csv", header = TRUE)

# traits_df <- melt(traits_df, id.vars = c("taxa"), na.rm = TRUE)
# names(traits_df) <- c("taxa", "name", "value")

#------------------------------
# Writing taxa and interaction table
#------------------------------

write.csv2(x = taxa_back_df, file = "mangal-datasets/wheelwright_1984/data/wheelwright_1984_taxa_back.csv", row.names = FALSE)
write.csv2(x = taxa_df, file = "mangal-datasets/wheelwright_1984/data/wheelwright_1984_taxa.csv", row.names = FALSE)
write.csv2(x = wheelwright_1984, file = "mangal-datasets/wheelwright_1984/data/wheelwright_1984_inter.csv", row.names = FALSE)
# write.csv2(x = traits_df, file = "mangal-datasets/wheelwright_1984/data/wheelwright_1984_traits.csv", row.names = FALSE)

# taxa_back_df <- read.csv2("mangal-datasets/wheelwright_1984/data/wheelwright_1984_taxa_back.csv", header = TRUE)
# taxa_df <- read.csv2("mangal-datasets/wheelwright_1984/data/wheelwright_1984_taxa.csv", header = TRUE)
# wheelwright_1984 <- read.csv2("mangal-datasets/wheelwright_1984/data/wheelwright_1984_inter.csv", header = TRUE)
# traits_df <- read.csv2("mangal-datasets/wheelwright_1984/data/wheelwright_1984_traits.csv", header = TRUE)

#------------------------------
# Throwing injection functions
#------------------------------
POST_attribute(attr_inter)
# POST_attribute(attr1)
# POST_attribute(attr2)
POST_ref(ref)
POST_user(users)
# POST_environment(enviro, attr_##)
POST_dataset(dataset, users, ref)
POST_network(network_lst = network, enviro = enviro, dataset, users)
POST_taxa_back(taxa_back = taxa_back_df)
POST_taxon(taxa_df)
# POST_traits(trait_df, network)
POST_interaction(inter_df = wheelwright_1984, inter = inter, enviro = enviro, attr = attr_inter, users)

rm(taxa, lat, lon, srid, attr_inter, ref, users, enviro, dataset, trait, network, inter, taxa_df, taxa_back_df, wheelwright_1984)
