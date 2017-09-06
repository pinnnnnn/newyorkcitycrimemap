

#Load shapefile and data ----

shinyServer(function(input, output, session) {


     # Determines the visible precincts based on both selectize inputs
     allowedPrecincts <- reactive({
          if(input$filterPrecincts[1] == "Show all") {
               show <- precincts1$Precinct
          } else {
               show <- input$filterPrecincts
          }
          hide <- input$removePrecincts


               return(setdiff(show, hide))
     })

     # Filter shapes to only show visible precincts
     filteredPrecincts <- reactive({
          precincts1[(precincts1$Precinct %in% allowedPrecincts()), ]
     })

     # Same as above, but for data
     filteredData <- reactive({
          arrestData[(arrestData$Precinct %in% allowedPrecincts()), ]
     })

     #    Define color vector, according to user input
     countryVar <- reactive({

          linearValues <- {
               if(input$colorby == "race_dist"){
                    switch(as.character(input$race),
                           "W" = filteredData()$White,
                           "B" = filteredData()$Black,
                           "H" = filteredData()$Hisp,
                           "A" = filteredData()$AsPac,
                           "N" = filteredData()$Native)
               } else if(input$colorby == "race_arr"){
                    switch(as.character(input$race),
                           "W" = filteredData()$WhiteA,
                           "B" = filteredData()$BlackA,
                           "H" = filteredData()$HispA,
                           "A" = filteredData()$AsPacA,
                           "N" = filteredData()$NativeA)
               } else {
                    switch(as.character(input$colorby),
                           "arrests_weighted" = filteredData()$TotalA/filteredData()$Population*1000,
                           "arrests_raw" = filteredData()$TotalA)}
          }

          if( input$scale == 'Logarithmic') { log(linearValues+0.00001)
          } else { linearValues }

     })
     getColor <- function(values){
          lower <- min(values)
          upper <- max(values)
          mapPalette <<- colorNumeric(rev(heat.colors(10)), c(lower, upper), 10)
          mapPalette(values)
     }

     #    Render base map ----
     output$nycMap <- renderLeaflet({
          leaflet() %>%
               addTiles() %>%
               setView(-74.004, 40.705, zoom = 10) %>%
               setMaxBounds(-73.000, 40.200, -75.000, 41.100)
     })

     #    Create instance of base map where polygons can be added
     MapProxy <- leafletProxy('nycMap')

     #    Initialize information box to display default text
     output$precinctOverInfo <- renderText({"<center><h4>Hover over a precinct for more information.</h4></center>"})

     #    Prevents users from picking "Show all" with other precincts
     observe({
          if ( "Show all" %in% input$filterPrecincts &
                    input$filterPrecincts %>% length %>% is_greater_than( 1 )) {
               if( input$filterPrecincts[1] == "Show all" ) {
                    updateSelectizeInput(session, inputId = "filterPrecincts",
                                         selected = input$filterPrecincts %>% setdiff( "Show all" ))
               } else {
                    updateSelectizeInput(session, inputId = "filterPrecincts",
                                         selected = "Show all")
               }
          }})

     #    Mouseover events: highlights precinct and prints information
     observe({

          eventOver <- input$nycMap_shape_mouseover

          if(!is.numeric(eventOver$id)) {
               return()
          }

          #         Precinct information:
          precinctOver <- precincts1[precincts1$Precinct==eventOver$id,]
          precinctOverData <- arrestData[arrestData$Precinct==eventOver$id,]

          #         Highlights precinct:
          MapProxy %>%
               addPolygons(data=precinctOver, layerId='highlighted', color="white", fill = FALSE)

          #         Prints precinct information ----
          output$precinctOverInfo <- renderText({
               createTextRow <- function(label, count, total){
                    paste0("&emsp; <b>", label, ":</b> ", count, " (", round(count/total *100, 2), "%)")
               }

               paste(
                    gsub("[%]", precinctOverData$Precinct, "<b><center><h2>Precinct %</h2></center></b>"),

                    gsub("[#]", round(precinctOverData$Area, 2), "<b>Area:</b> # square miles"),
                    gsub("[#]", precinctOverData$Population, "<table style='width:100%'><tr><td><b>Population:</b> # (2010 census)"),
                    createTextRow("White", precinctOverData$White, precinctOverData$Population),
                    createTextRow("African-American", precinctOverData$Black, precinctOverData$Population),
                    createTextRow("Hispanic", precinctOverData$Hisp, precinctOverData$Population),
                    createTextRow("Asian/Pacific Islander", precinctOverData$AsPac, precinctOverData$Population),
                    createTextRow("Native American", precinctOverData$Native, precinctOverData$Population),

                    gsub("[%]", precinctOverData$TotalA, "<td><b>Total number of arrests:</b> %"),
                    createTextRow("White", precinctOverData$WhiteA, precinctOverData$TotalA),
                    createTextRow("African-American", precinctOverData$BlackA, precinctOverData$TotalA),
                    createTextRow("Hispanic", precinctOverData$HispA, precinctOverData$TotalA),
                    createTextRow("Asian/Pacific Islander", precinctOverData$AsPacA, precinctOverData$TotalA),
                    createTextRow("Native American", precinctOverData$NativeA, precinctOverData$TotalA),
                    sep="<br/>")
          })

          output$graph_perc <- renderPlot({

               precinct_pop <- as.numeric(precinctOverData[5:9])
               precinct_arr <- as.numeric(precinctOverData[10:14])
               graph_max <- max(precinct_arr/precinct_pop, na.rm=TRUE)+0.01

               barplot(
                    rbind(
                         precinct_arr/precinct_pop, rep(graph_max,5)-precinct_arr/precinct_pop
                    ), # Arrested in precinct/Living in precinct

                    main = "Proportion of Population Arrested, by Race",
                    names.arg = c("White", "Afrn Am.", "Natv Am.", "Asian", "Hispanic"),
                    ylim = c(0,graph_max),
                    xlab = "Race", ylab = "Percent in Precinct")
               mtext("(Number of arrests divided by number living in precinct)", padj = -0.6)
          })

     })

     #    Mouseout events: stop displaying information
     observeEvent(input$nycMap_shape_mouseout$id, {
          if( input$nycMap_shape_mouseout$id  %>% is.null %>% not) {

               MapProxy %>% removeShape( 'highlighted' )
               output$precinctOverInfo <- renderText("<center><h4>Hover over a precinct for more information.</h4></center>")
               output$graph_perc <- renderPlot(NULL)

          }
          })

     #    Rerender the map whenever an input changes
     observeEvent({input$colorby; input$race; input$removePrecincts; input$scale; input$filterPrecincts}, {


          MapProxy %>%
               clearControls() %>%
               clearShapes()
          if ( TRUE ) {
               MapProxy %>% addPolygons(data = filteredPrecincts(),
                           layerId = ~Precinct,
                           color = getColor(countryVar()),
                           weight = 2, fillOpacity = .6) %>%
               addLegend('bottomleft',
                         title = ifelse(input$colorby == "arrests_weighted", "Arrests per 1000 people",
                                        ifelse( input$colorby %in% c("race_dist") , "Population", "Arrests")),
                         pal = mapPalette, values = countryVar(), opacity = 0.7,
                         labFormat = labelFormat(transform = ifelse(input$scale == 'Logarithmic',
                                                                    exp,
                                                                    identity)))
          if ( input$filterPrecincts[1]  != "Show all" ) {
               MapProxy %>% addPolygons(data = filteredPrecincts(),
                                        color = 'red', weight = 2,
                                        fill = FALSE, opacity = 1)
          }
          }
     })


})
