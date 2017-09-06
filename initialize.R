# library("rgdal")
#
# precincts <- readOGR("police_precincts.geojson", "OGRGeoJSON")

#Install required packages ----
if(!require(magrittr)) install.packages("magrittr")
if(!require(shinydashboard)) install.packages("shinydashboard")
if(!require(leaflet)) install.packages("leaflet")
if(!require(maptools)) install.packages('maptools')
library(magrittr)

#Load shapefile and data ----
library("maptools")
# if(!exists("precincts")) {precincts <- readShapeSpatial("nypp_2013/OGRGeoJSON.shp")
# precincts$FID <- unique(arrestData$Precinct)
# names(precincts) <- "Precinct"}

if(!exists("arrestData")) arrestData <- read.csv("arrestData16.csv")

if(!exists("precincts1")) precincts1 <- readShapeSpatial("precincts1/nypp")

