# UI file for Shiny App phenoRemote
# Initiate the UI
ui = fluidPage(shinyjs::useShinyjs(), useShinyalert(), includeCSS("./Aesthetics/styles.css"),
               mainPanel(
                 img(src='phenoSynth.png', id = 'phenoSynthLogo'),
                 hidden(bsModalNoClose("curatedDataLogin", "CuratedDataLogin",
                   title="AppEEARS Login Details", size='small',
                   textInput('username', 'Username', placeholder = '<username to earthdata>'),
                   passwordInput('pwInp', 'Password', placeholder = '<password to earthdata>'),
                   div(id = 'loginButtons',
                     withBusyIndicatorUI(actionButton('butLogin', 'Login', class = 'btn-primary', icon = icon('sign-in'))),
                     actionButton('byPassLogin', 'Use Phenocam Data')),
                   # footer = h4(actionLink('create_account','Create an account'),align='right'),
                   tags$head(tags$style("#curatedDataLogin .modal-footer{display:none}
                     .modal-header .close{display:none}"),
                     tags$script("$(document).ready(function(){
                       $('#curatedDataLogin').modal();
                       });"))),
                   actionButton('phenosynthAppeearsBtn', 'PhenoSynth Data')),
                 bsModal("saveShpPopup",
                         "Download shapefile", "saveShp",
                         tags$head(tags$style("#window .modal{backdrop: 'static'}")),
                         size = "small",
                         selectInput('shapefiles', "Select Shapefile", c('None')),
                         textInput('savePaoiFilename', 'Edit Shapefile Name:'),
                         actionButton('downloadShp', 'Download shapefile')
                 ),
                 bsModal("emailShpPopup",
                         "Email shapefile", "emailShp",
                         tags$head(tags$style("#window .modal{backdrop: 'static'}")),
                         size = "medium",
                         selectInput('shapefiles2', "Select Shapefile", c('None')),
                         textInput('paoiUser', 'Name'),
                         textInput('paoiEmail', 'Email'),
                         textInput('paoiNotes', 'Notes or Comments'),
                         actionButton('emailShpButton', 'Email shapefile')
                 ),
                 bsModal("uploadShpPopup",
                   "Upload shapefile", "uploadShp",
                   tags$head(tags$style("#window .modal{backdrop: 'static'}")),
                   size = "medium",
                   fileInput('shpFileName', 'Select shapefile', multiple = TRUE, accept = c('.shp','.dbf','.sbn','.sbx','.shx','.prj'))
                 ),
                 bsModal("getDataPopup",
                         "Get Data for Analysis", "getData",
                         size = "medium",
                         # selectInput('dataTypes_get', 'Data Types', multiple = TRUE, selected = c('GCC', 'NDVI', 'EVI','Transition Dates', 'NPN'), c('GCC', 'NDVI', 'EVI', 'Transition Dates', 'NPN')),
                         selectInput('dataTypes_get', 'Data Types', multiple = TRUE, selected = c('GCC', 'NDVI', 'EVI', 'Transition Dates'), c('GCC', 'NDVI', 'EVI', 'Transition Dates')),
                         withBusyIndicatorUI(actionButton('getDataButton', 'Get Data', class='btn-primary')),
                         br(),
                         tags$head(tags$style("#getDataPopup .modal-footer{ display:none } 
                                               #getDataPopup .modal-header button{ display:none } 
                                               #getDataPopup {keyboard:false; backdrop: 'static';}"))
                 ),
                 bsModal("plotDataPopup",
                         "Select Plot Data", "plotRemoteData",
                         tags$head(tags$style("#window .modal{backdrop: 'static'}")),
                         size = "small",
                         withBusyIndicatorUI(actionButton('plotDataButton', 'Plot Data', class='btn-primary')),
                         br(),
                         # selectInput('dataTypes_plot', 'Data Types', multiple = TRUE, selected = c('GCC', 'NDVI', 'EVI', 'NPN'), c('GCC', 'NDVI', 'EVI', 'Transition Dates', 'NPN')),
                         selectInput('dataTypes_plot', 'Data Types', multiple = TRUE, selected = c('GCC', 'NDVI', 'EVI'), c('GCC', 'NDVI', 'EVI')),
                         selectInput('phenocamFrequency', 'GCC Frequency', multiple = FALSE, selected = '3 day', c('1 day', '3 day')),
                         h4('Requires at least GCC, EVI, or NDVI'),
                         tags$head(tags$style("#plotDataPopup .modal-footer{ display:none } 
                                               #plotDataPopup .modal-header button{ display:none } 
                                               #plotDataPopup {keyboard:false; backdrop: 'static';}"))
                 ),
                 
                 bsModal("downloadDataPopup",
                         "Download Data from Plot", "downloadData",
                         tags$head(tags$style("#window .modal{backdrop: 'static'}")),
                         size = "medium",
                         selectInput('dataTypes_download', 'Data Types',selected = 'NDVI', multiple = FALSE, 
                           c('EVI', 'NDVI', 'GCC Data', 'GCC Spring Transition Dates', 'GCC Fall Transition Dates', 'MODIS Transition Dates', 'Selected Pixel CSV')),
                         downloadButton('downloadDataButton', 'Download'),
                         tags$head(tags$style("#getDataPopup .modal-footer{ display:none}"))
                 ),
                 bsModal("removeCachedDataModal",
                   "Removing locally cached data", "openDeleteDataModal",
                   h4('Are you sure you want to remove all downloaded data for this site?'),
                   checkboxInput('boolDeleteData', 'Select checkbox and then press button that appears'),
                   withBusyIndicatorUI(actionButton('removeCachedData', 'Remove Data', class='btn-primary')),
                   tags$head(tags$style("#plotDataPopup .modal-footer{ display:none } 
                                               #plotDataPopup .modal-header button{ display:none } 
                                               #plotDataPopup {keyboard:false; backdrop: 'static';}"))
                 ),
                 
                 navbarPage("PhenoSynth-v1 Release", id="navbar",
                          tabPanel("Site explorer",
                                   div(class="outer",
                                       tags$head(
                                                 includeCSS("./Aesthetics/styles.css"),
                                                 includeScript("./Aesthetics/gomap.js")),

                        # If not using custom CSS, set height of leafletOutput to a number instead of percent
                        leafletOutput("map", width="100%", height="100%"),
                        textOutput("See Field of View (FOV)"),

                        hidden(
                        absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,
                                      draggable = FALSE, top = 70, left = "auto", right = 20, bottom = "auto",
                                      width = 320, height = "auto", style="z-index:600;",
                                      h2(id = 'explorerTitle', "Site Explorer"),
                                      h2(id = 'analyzerTitle', "Site Analyzer"),
                                      actionButton('siteExplorerMode', 'Back to Site Explorer'),
                                      actionButton("usZoom", "Show Contiguous US"),
                                      actionButton('showSites', 'Show all Sites'),
                                      actionButton("siteZoom", "Zoom to Selected Site"),
                                      selectInput("filterSites", 'Filter Sites by', site_filters, selected = 'All', multiple = FALSE),
                                      selectInput("site", "Phenocam Site Name", cams_$Sitename, selected = 'acadia'),
                                      withBusyIndicatorUI(actionButton('analyzerMode', 'Enter Analyze Mode', class='btn-primary')),
                                      checkboxInput("drawROI", "See PhenoCam Field of View (FOV)", value = FALSE),
                                      numericInput('azm', 'FOV degrees (1 to 360)',value=0, min=0,max=360),
                                      checkboxInput('drawImage', "Show site PhenoCam Image", value = TRUE),
                                      checkboxInput("drawImageROI", "Show ROI on PhenoCam Image", value = FALSE),
                                      selectInput('pftSelection', 'PhenoCam ROI Vegetation', ''),
                                      checkboxInput("highlightPixelModeNDVI", "Select MODIS Pixels (250m resolution)", value = FALSE),
                                      actionButton('getData', 'Import Data'),
                                      actionButton('openDeleteDataModal', 'Remove Data'),
                                      actionButton('uploadShp', 'Upload Shapefile'),
                                      actionButton('clearPixels', 'Clear Pixels'),
                                      withBusyIndicatorUI(actionButton('plotRemoteData', 'Plot Data', class='btn-primary'))
                                      # sliderInput('nlcdOpacity', 'NLCD Opacity', min = .1, max = 1, value =.7, step = .1)
                        )),
                                     
                        absolutePanel(id = 'currentImage', class = 'panel panel-default', 
                                      draggable = TRUE,  top = 'auto', left = 250, right = 'auto' , bottom = 10,
                                      width = 375, height = 225, style="z-index:500;",
                                      actionButton('showImage', '-', value=FALSE),
                                      actionButton('showROIimage', 'Overlay selected ROI'),
                                      actionButton('imagePlus', 'Enlarge'),
                                      actionButton('imageMinus', 'Shrink'),
                                      tags$div(id = 'image')
                        ),
                                     
                        absolutePanel(id = 'plotpanel', class = 'panel panel-default', 
                                      draggable = TRUE,  top = 'auto', left = 400, right = 'auto' , bottom = 20,
                                      width = 375, height = 225, style="z-index:500;",
                                      actionButton('hidePlot', '-', value=FALSE),
                                      plotOutput("currentPlot", height = 225)
                        ),
                                     
                        absolutePanel(id = 'mouseBox', class = 'panel panel-default', fixed = TRUE,
                                      draggable = FALSE,  top = 'auto', left = 'auto', right = 20 , bottom = 185,
                                      width = 240, height = 40, style="z-index:500;",
                                      verbatimTextOutput("mouse")
                        ),
                                     
                        absolutePanel(id = 'siteTitle', class = 'panel panel-default', fixed = FALSE, style="z-index:500;",
                                      draggable = FALSE,  top = 25, left = 'auto', right = 320 , bottom = 'auto',
                                      div(id = 'analyzerHeader', uiOutput("analyzerTitle"))
                        )
                      ) # close div outer
                    ), # close tab panel
                            

           hidden(
           tabPanel('pAOI Management', value='paoiTab',

                    tags$div(id='pAOItab',
                    actionButton('saveShp', 'Download Shapefile'),
                    actionButton('emailShp', 'Email Shapefile'),
                    br(),
                    br(), br(),
                    DTOutput("pAOIchart"))
           )),

           tabPanel('phenoSynth User Guide',
                    div(id = 'phenoSynthUserGuide',
                      shiny::includeMarkdown('../phenoSynth/Images_for_UserGuide/UserGuide.Rmd') )
              
           ),
                   
           tabPanel('PhenoCam Metadata',
                    dataTableOutput('phenoTable')
           ),
    
           tabPanel('Plot Data', value = 'PlotPanel',
                    checkboxGroupInput("plotTheseBoxes", label = h4("Select Plots to Display"), 
                                       choices = list("GCC" = 'GCC', "All NDVI" = 'all_ndvi', "High Quality NDVI" = 'hiq_ndvi',
                                                      'All EVI' = 'all_evi', 'High Quality EVI' = 'hiq_evi',
                                                      'Transition Dates (EVI/NDVI)' = 'tds_sat'), inline=TRUE,
                                       selected=c('GCC','all_ndvi','hiq_ndvi','all_evi','hiq_evi','tds_sat')),
                    h3(id = 'plotTitle',''),
                    plotlyOutput("data_plot", width='100%', height = 'auto'),
                    hr(),
                    actionButton('downloadData', 'Download Dataframe'),
                    hr(),
                    h3('Selected Pixel Data'),
                    br(),
                    dataTableOutput('plotTable')
           ),
                   
           # tabPanel('AppEEARS',
           #   hidden(actionButton('appeearsLogout', 'Logout')),
           #   hidden(actionButton('appeearsLogin', 'Login')),
           #   div( id = 'appeearsTab', 
           #     h1("PhenoSynth's AppEEARS Data Center"),
           #     br(),
           #       mainPanel(
           #         hidden(absolutePanel(id = 'appeearsTools', class = 'panel panel-default', 
           #           draggable = TRUE,  top = -75, left = 'auto', right = '35%' , bottom = 'auto',
           #           width = 400, height = 'auto', style="z-index:500;",
           #           withBusyIndicatorUI(actionButton('pullAppeearsTasks', 'View AppEEARS Tasks', class='btn-primary')),
           #           # selectInput('sitesCached', 'Sites Cached in AppEEARS', multiple = TRUE, selected = cams_$site[1], cams_$site),
           #           # selectInput('camsWithRois', 'Cam Sites with ROIS', multiple = TRUE, selected = appeears_tasks_ndvi_tera$site_name[1], appeears_tasks_ndvi_tera$site_name),
           #           selectInput('siteDifference', 'Difference between ROIS and AppEEARS tasks', multiple = TRUE, choices=''),
           #           actionButton('submitTasks', 'Submit Tasks for selected'),
           #           textInput('submitionsLeft', 'Submitions left', value = 100)
           #           )),
           #         tabsetPanel(
           #           id = 'appeearsPanelPhenoSynth',
           #           tabPanel("NDVI TERA", DT::dataTableOutput("appeearsTable1")),
           #           tabPanel("NDVI AQUA", DT::dataTableOutput("appeearsTable2")),
           #           tabPanel("EVI TERA", DT::dataTableOutput("appeearsTable3")),
           #           tabPanel("EVI AQUA", DT::dataTableOutput("appeearsTable4")),
           #           tabPanel("MODIS Landcover", DT::dataTableOutput("appeearsTable5")),
           #           tabPanel("MODIS Transition Dates", DT::dataTableOutput("appeearsTable6"))
           #         ),
           #           br(),
           #           hidden(div(id = 'myTasks',
           #             h2('My AppEEARS Tasks'),
           #             br(),
           #             tabPanel("All Tasks", DT::dataTableOutput("appeearsTable7"))
           #           ))
           # ))),
                   
           conditionalPanel("false", icon("crosshair"))
      )
    )
)
