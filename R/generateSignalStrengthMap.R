#----------------------------------------
#@author: Taggart Bonham
#@website: http://taggartbonham.me
#@github: https://github.com/jtbon20/SignalMapping
#@Project: Signal Strength Mapping
#@Description: 

#----------------------------------------

#--------------------
#Generate Local Area
#--------------------
require(yaml)
require(pixmap)
library(raster)
require(sp)

# read yaml for data about Map
mapBaseLocation <- readline(prompt="Enter Path to Folder of Map YAML and PGM: ")
mapDetails <- yaml.load_file(mapLocation + "map.yaml")

#read .PGM for raster of local area Map
map <- read.pnm(file = mapLocation + "map.yaml")

#convert map coordinate system using information from yaml
#resolution
res = mapDetails$resolution
map@cellres <- c(res, res)

#bounding box 
gridSizeX = map@size[1]
gridSizeY = map@size[2]
maxX = res * gridSizeX + mapDetails$origin[1]
maxY = res * gridSizeY + mapDetails$origin[2]
map@bbox<- c(mapDetails$origin[1:2], maxX, maxY )

vectorOfPoints = as.vector(t(map@grey)) #saved because using multiple times to cut down on computation

#create Grid to use for converting map into spatial grid dataframe
blankRaster <- raster(nrows=gridSizeX, ncols=gridSizeY, xmn=mapDetails$origin[1], xmx=maxX,ymn=mapDetails$origin[2], ymx=maxY)
mapGrid = GridTopology(bbox(blankRaster)[,1] + res(blankRaster)/2, res(blankRaster), dim(blankRaster)[2:1])
mapSpatial <- SpatialGridDataFrame(mapGrid, as.data.frame(vectorOfPoints)) #ugly, but best way to pair data

#decoding map meanings for later use
solidValMap = max(vectorOfPoints)
openValMap = min(vectorOfPoints)



#--------------------
#Gather Trial Data
#--------------------
require(data.table)

#read from yaml in the python part, send in w proper names/values etc.
longMin = map@bbox[1]
longMax = map@bbox[3]
latMin = map@bbox[2]
latMax = map@bbox[4]

dataLocation <- readline(prompt="Enter Path to CSV of Data: ")
dta = read.csv(dataLocation)
signalDta = subset(dta, select=c(field.pose.pose.position.x, field.pose.pose.position.y, signal_strength))
numberOfEntries = length(signalDta[,1])

#Calculations to reformat numbers to be from
#normal range of ~(-80,-30) to [0,100].
sigMin = min(signalDta$signal_strength)
sigRange = abs(max(signalDta$signal_strength)- sigMin)
adjustedMax = 100

for (i in seq(0,numberOfEntries,1)){
  #calculate new adjusted wifi score
  adjStrength = (signalDta$signal_strength[i] + sigMin)*(adjustedMax/sigRange)
  #save data
  signalDta$signal_strength[i] <- adjStrength
}

#convert to spatial dataframe
xy <- signalDta[,c(1,2)]
spdf <- SpatialPointsDataFrame(coords = xy, data = signalDta)
spdf@bbox <-  mapSpatial@bbox# #change spatial extent to match map



#--------------------
# Spatial Interpolation
#--------------------
library(gstat) # Use gstat's idw routine
library(sp)    # Used for the spsample function

# Create an empty grid where n is the total number of cells
grd              <- as.data.frame(spsample(spdf, "regular", n=500000))
names(grd)       <- c("X", "Y")
coordinates(grd) <- c("X", "Y")
gridded(grd)     <- TRUE  # Create SpatialPixel object
fullgrid(grd)    <- TRUE  # Create SpatialGrid object

# Interpolate the grid cells using a power value of 2 (idp=2.0)
spdf.idw <- gstat::idw(signalDta$signal_strength ~ 1, spdf, newdata=grd, idp=2.0)

# Convert to raster object for printing
r       <- raster(spdf.idw)

#--------------------
# Make Map
#--------------------
require(tmap)

roomPal <- c("#000000", "#969696", "#FFFFFF") #palette of colors to draw room

#draw room with room color palette, signal strength overlaid over lidar map of area
tm_shape(mapSpatial) + tm_raster(palette = roomPal, n = 3, contrast = c(0, 1), title="Room Occupany Map", auto.palette.mapping = FALSE ) +
  tm_shape(spdf) + tm_dots(size=.01, col = "red") +
  tm_shape(r) +  tm_raster(n=10,palette = "Reds", auto.palette.mapping = FALSE, title="Signal Strength", alpha=.4) +
  tm_layout(legend.outside = TRUE)
