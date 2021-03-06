#' add_title_to_plot
#'
#' @param df 
#' @param x_title_ 
#' @param y_title_ 
#' Adds a title to a plotly plot
#' @return df_
#' 
add_title_to_plot = function(df,
                             x_title_,
                             y_title_){
  
  df_ = df %>% add_annotations(
    text = x_title_,
    x = 0.5,
    y = 1,
    yref = "paper",
    xref = "paper",
    yanchor = "bottom",
    showarrow = FALSE,
    font = list(size = 15)) %>%
    layout(
      showlegend = TRUE,
      shapes = list(
        type = "rect",
        x0 = 0,
        x1 = 1,
        xref = "paper",
        y0 = 0,
        y1 = 25,
        yanchor = 1,
        yref = "paper",
        ysizemode = "pixel",
        fillcolor = toRGB("gray80"),
        line = list(color = "transparent"))) %>%
    add_annotations(
      text = y_title_,
      x = -.04,
      y = .4,
      yref = "paper",
      xref = "paper",
      yanchor = "bottom",
      showarrow = FALSE,
      textangle=-90,
      font = list(size = 12))
  return (df_)
}

#' extract_df_tds_v6
#'
#' @param pixels_ 
#' @param lats_ 
#' @param lngs_ 
#' @param tds_nc_ 
#' @param progress_bar 
#'
#' @return - data_df
#' 
extract_df_tds_v6 = function(pixels_, lats_, lngs_, tds_nc_, progress_bar = FALSE){
  # Store the transition date layers to extract for each pixel
  td_v6_names = c('Dormancy', 'Greenup', 'Maturity', 'MidGreendown', 'MidGreenup', 'Peak', 'QA_Overall', 'Senescence')
  td_fnames = c()
  data_df   = data.frame()
  # Store lon, lat, and time variables from .nc file to help create sub .nc files for each layer above
  lon_td = ncvar_get(tds_nc_, "lon")
  nlon = length(lon_td)
  lat_td = ncvar_get(tds_nc_, "lat")
  nlat = length(lat_td)
  time_td = ncvar_get(tds_nc_, 'time')
  
  start_date = as.Date('1970-01-01')
  crs = CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs+ towgs84=0,0,0")
  
  # Loop through layers and build the individual .nc files for each
  for (td_type in td_v6_names){
    nc_layer = ncvar_get(tds_nc_, td_type)[1,,,]
    nc_layer_dim = dim (ncvar_get(tds_nc_, td_type)[1,,,])
    
    lon1_td = ncdim_def("longitude", "degrees_east", lon_td)
    lat2_td = ncdim_def("latitude", "degrees_north", lat_td)
    
    time = ncdim_def("Time","days since 1970-01-01 00:00:00", time_td, unlim=TRUE)
    mv   = 32767 # Fill value
    
    var_nc = ncvar_def(td_type, "pheno_metric", list(lon1_td, lat2_td, time), 
                       longname=td_type, mv)
    
    tmp_dir   = './www/'
    var_fname = paste0(tmp_dir, td_type, '.nc')
    print (var_fname)
    td_fnames = c(td_fnames, var_fname)
    ncnew = nc_create(var_fname, list(var_nc))
    
    data = nc_layer
    data[data == mv] = NA
    ncvar_put(ncnew, var_nc, data, start=c(1,1,1), count=c(nlon,nlat,16))
    nc_close(ncnew)
  }
  
  # Loop through pixels
  for (x in c(1:length(lats_))){
    if (progress_bar == TRUE){
      incProgress(amount = (1/length(lats_))*.8)
    }
    print (paste0('pixel #: ',x))
    this_pixel_ll = c(lngs_[x], lats_[x])
    xy              = data.frame(matrix(this_pixel_ll, ncol=2))
    colnames(xy)    = c('lon', 'lat')
    coordinates(xy) = ~ lon + lat
    proj4string(xy) = crs
    
    pixel_id = pixels_[x]
    
    for (n in c(1:length(td_fnames))){
      fname   = td_fnames[n]
      td_type = td_v6_names[n]
      data_nc = raster::brick(fname)
      print (fname)
      data    = extract(data_nc, xy)
      if (td_type == 'QA_Overall'){
        v = as.integer(data)
        print (v)
        if (length(unique(v)) <2 & is.na(unique(v)[1])){
          date_data = NA
        }else {
          date_data = seq(as.Date("2001-01-01"), as.Date("2016-01-01"), by="years") 
        }
      }else{
        v = NA
        date_data = start_date + as.integer(data)
      }
      
      if (length(unique(date_data))<2 & is.na(unique(date_data)[1])){
        print (unique(date_data))
        df = data.frame(dates = as.Date(NA), layer = td_type, pixel = pixel_id, value = NA)
        print (paste0('Empty list of data in, ',td_type, '. Pixel: ', pixel_id))
      }else {
        df = data.frame(dates = date_data, layer = td_type, pixel = pixel_id, value = v)
      }
      data_df = rbind(data_df, df)
    }
  }
  
  # Remove .nc files
  for (file in td_fnames){
    file.remove(file)
  }
  return (data_df)
}


#' get_tds_modis_df
#'
#' @param pixels_ 
#' @param lats_ 
#' @param lngs_ 
#' @param netcdf_ 
#' @param progress_bar 
#' Builds a dataframe from a list of lat/lngs and the netcdf from AppEEARS with the 6 layers
#' @return - final_df
#' 
get_tds_modis_df = function(pixels_, lats_, lngs_, netcdf_, progress_bar = FALSE){
  print ('START EXTRACTION OF TDS')
  lat_td = ncvar_get(netcdf_, "lat")
  lon_td = ncvar_get(netcdf_, "lon")
  time_td = ncvar_get(netcdf_, 'time')
  
  start_date = as.Date('2001-01-01')
  
  crs = CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs+ towgs84=0,0,0")
  
  # Date Values as Integers after start date (2001-01-01)
  OGD_var = ncvar_get(netcdf_, "Onset_Greenness_Decrease")[1,,,]
  OGI_var = ncvar_get(netcdf_, "Onset_Greenness_Increase")[1,,,]
  OGMa_var = ncvar_get(netcdf_, "Onset_Greenness_Maximum")[1,,,]
  OGMi_var = ncvar_get(netcdf_, "Onset_Greenness_Minimum")[1,,,]
  
  # Integer Values from 0 to 1
  EVI_OGMa_var = ncvar_get(netcdf_, "NBAR_EVI_Onset_Greenness_Maximum")[1,,,]
  EVI_OGMi_var = ncvar_get(netcdf_, "NBAR_EVI_Onset_Greenness_Minimum")[1,,,]
  
  OGD_df = NULL
  OGI_df = NULL
  OGMa_df = NULL
  OGMi_df = NULL
  EVI_OGMa_df = NULL
  EVI_OGMi_df = NULL
  
  # Loop through each lat/lon which is the center of each selected pixel in app
  for (x in c(1:length(lats_))){
    if (progress_bar == TRUE){
      incProgress(amount = (1/length(lats_))*.8)
    }
    this_pixel_ll = c(lngs_[x], lats_[x])
    xy              = data.frame(matrix(this_pixel_ll, ncol=2))
    colnames(xy)    = c('lon', 'lat')
    coordinates(xy) = ~ lon + lat
    proj4string(xy) = crs
    
    pixel_id = pixels_[x]
    
    #-----------------------------Onset_Greenness_Decrease-----------------------------
    OGD_data = c()
    for (layer in c(1:dim(OGD_var)[3])){
      layer_raster = raster(t(OGD_var[,,layer]), xmn=min(lon_td), xmx=max(lon_td), ymn=min(lat_td), ymx=max(lat_td), crs=crs)
      values_under_polygon = extract(layer_raster, xy)
      OGD_data = c(OGD_data, values_under_polygon)
    }
    OGD_data = OGD_data[!is.na(OGD_data)]
    OGD_data = OGD_data[order(OGD_data)]
    date_data = start_date + as.integer(OGD_data)
    
    if (length(date_data)==0){
      df = data.frame(dates = as.Date(NA), layer = 'Onset_Greenness_Decrease', pixel = pixel_id, value = NA)
      print (paste0('Empty list of data in Onset_Greenness_Decrease. Pixel: ', pixel_id))
      if (is.null(OGD_df)){
        OGD_df = df
      }else {
        OGD_df = rbind(OGD_df, df)
      }
    }else {
      if (is.null(OGD_df)){
        df = data.frame(dates = date_data, layer = 'Onset_Greenness_Decrease', pixel = pixel_id, value = NA)
        OGD_df = df
      } else{
        df = data.frame(dates = date_data, layer = 'Onset_Greenness_Decrease', pixel = pixel_id, value = NA)
        OGD_df = rbind(OGD_df, df)
      }
    }
    pixel_df = df
    #-----------------------------Onset_Greenness_Increase-----------------------------
    OGI_data = c()
    for (layer in c(1:dim(OGI_var)[3])){
      layer_raster = raster(t(OGI_var[,,layer]), xmn=min(lon_td), xmx=max(lon_td), ymn=min(lat_td), ymx=max(lat_td), crs=crs)
      values_under_polygon = extract(layer_raster, xy)
      OGI_data = c(OGI_data, values_under_polygon)
    }
    OGI_data = OGI_data[!is.na(OGI_data)]
    OGI_data = OGI_data[order(OGI_data)]
    date_data = start_date + as.integer(OGI_data)
    
    if (length(date_data)==0){
      df = data.frame(dates = as.Date(NA), layer = 'Onset_Greenness_Increase', pixel = pixel_id, value = NA)
      print (paste0('Empty list of data in Onset_Greenness_Increase. Pixel: ', pixel_id))
      if (is.null(OGI_df)){
        OGI_df = df
      }else {
        OGI_df = rbind(OGI_df, df)
      }
    }else {
      if (is.null(OGI_df)){
        df = data.frame(dates = date_data, layer = 'Onset_Greenness_Increase', pixel = pixel_id, value = NA)
        OGI_df = df
      } else{
        df = data.frame(dates = date_data, layer = 'Onset_Greenness_Increase', pixel = pixel_id, value = NA)
        OGI_df = rbind(OGI_df, df)
      }
    }
    pixel_df = rbind(pixel_df, df)
    #-----------------------------Onset_Greenness_Maximum-----------------------------
    OGMa_data = c()
    EVI_OGMa_data = c()
    for (layer in c(1:dim(OGMa_var)[3])){
      layer_raster = raster(t(OGMa_var[,,layer]), xmn=min(lon_td), xmx=max(lon_td), ymn=min(lat_td), ymx=max(lat_td), crs=crs)
      values_under_polygon = extract(layer_raster, xy)
      OGMa_data = c(OGMa_data, values_under_polygon)
      
      layer_raster = raster(t(EVI_OGMa_var[,,layer]), xmn=min(lon_td), xmx=max(lon_td), ymn=min(lat_td), ymx=max(lat_td), crs=crs)
      values_under_polygon = extract(layer_raster, xy)
      EVI_OGMa_data = c(EVI_OGMa_data, values_under_polygon)
    }
    
    # Remove NA values from dates and y-values lists
    OGMa_data_1 = OGMa_data[!is.na(OGMa_data)]
    EVI_OGMa_data_1 =EVI_OGMa_data[!is.na(OGMa_data)]
    EVI_OGMa_data = EVI_OGMa_data_1[!is.na(EVI_OGMa_data_1)]
    OGMa_data = OGMa_data_1[!is.na(EVI_OGMa_data_1)]
    
    date_data = start_date + as.integer(OGMa_data)
    
    if (length(date_data)==0){
      df = data.frame(dates = as.Date(NA), layer = 'Onset_Greenness_Maximum', pixel = pixel_id, value = NA)
      print (paste0('Empty list of data in Onset_Greenness_Maximum. Pixel: ', pixel_id))
      if (is.null(OGMa_df)){
        OGMa_df = df
      }else {
        OGMa_df = rbind(OGMa_df, df)
      }
    }else {
      if (is.null(OGMa_df)){
        df = data.frame(dates = date_data, layer = 'Onset_Greenness_Maximum', pixel = pixel_id, value = EVI_OGMa_data)
        OGMa_df = df
      } else{
        df = data.frame(dates = date_data, layer = 'Onset_Greenness_Maximum', pixel = pixel_id, value = EVI_OGMa_data)
        OGMa_df = rbind(OGMa_df, df)
      }
    }
    pixel_df = rbind(pixel_df, df)
    #-----------------------------Onset_Greenness_Minimum-----------------------------
    OGMi_data = c()
    EVI_OGMi_data = c()
    for (layer in c(1:dim(OGMi_var)[3])){
      layer_raster = raster(t(OGMi_var[,,layer]), xmn=min(lon_td), xmx=max(lon_td), ymn=min(lat_td), ymx=max(lat_td), crs=crs)
      values_under_polygon = extract(layer_raster, xy)
      OGMi_data = c(OGMi_data, values_under_polygon)
      
      layer_raster = raster(t(EVI_OGMi_var[,,layer]), xmn=min(lon_td), xmx=max(lon_td), ymn=min(lat_td), ymx=max(lat_td), crs=crs)
      values_under_polygon = extract(layer_raster, xy)
      EVI_OGMi_data = c(EVI_OGMi_data, values_under_polygon)
    }
    
    # Remove NA values from dates and y-values lists
    OGMi_data_1 = OGMi_data[!is.na(OGMi_data)]
    EVI_OGMi_data_1 =EVI_OGMi_data[!is.na(OGMi_data)]
    EVI_OGMi_data = EVI_OGMi_data_1[!is.na(EVI_OGMi_data_1)]
    OGMi_data = OGMi_data_1[!is.na(EVI_OGMi_data_1)]
    
    date_data = start_date + as.integer(OGMi_data)
    
    if (length(date_data)==0){
      df = data.frame(dates = as.Date(NA), layer = 'Onset_Greenness_Minimum', pixel = pixel_id, value = NA)
      print (paste0('Empty list of data in Onset_Greenness_Minimum. Pixel: ', pixel_id))
      if (is.null(OGMi_df)){
        OGMi_df = df
      }else {
        OGMi_df = rbind(OGMi_df, df)
      }
    }else {
      if (is.null(OGMi_df)){
        df = data.frame(dates = date_data, layer = 'Onset_Greenness_Minimum', pixel = pixel_id, value = EVI_OGMi_data)
        OGMi_df = df
      } else{
        df = data.frame(dates = date_data, layer = 'Onset_Greenness_Minimum', pixel = pixel_id, value = EVI_OGMi_data)
        OGMi_df = rbind(OGMi_df, df)
      }
    }
    pixel_df = rbind(pixel_df, df)
    if (length(pixel_df)==0){
      print ('Might raise error')
    }
  }
  final_df = rbind(OGI_df, OGD_df, OGMa_df, OGMi_df)
  print ('START EXTRACTION OF TDS')
  return (final_df)
}# END BUILD TRANSITION DATE DATAFRAME FOR MODIS DATA


#' get_site_roi_csvs
#'
#' @param name 
#' @param roi_files_ 
#' @param metrics_ 
#' @param percentile_ 
#' @param roi_type_ 
#' Grabs the list of 3_day or 1_day csv data from phenocam website with spring and fall

#' @return the list of 3_day or 1_day csv data from phenocam website with spring and fall
#' 
get_site_roi_csvs = function(name, roi_files_, 
  metrics_ = c("gcc_mean","gcc_50", "gcc_75","gcc_90")){
  
  unix = "1970-01-01"
  # Get rows that = Site and = roi_type
  site_roi_rows = subset(roi_files_, roi_files_$site == name)
  unique_pfts = unique(site_roi_rows$roitype)
  # All data in a list
  all_phenocam_data = list()
  this_pc_list      = list()
  
  print ('unique pfts')
  print (unique_pfts)
  
  
  
  # Download everything, aka Fall/Spring for 1day and 3day and Transition dates
  for (pft in unique_pfts){
    roi_seq_num = subset(site_roi_rows, site_roi_rows$roitype == pft)$sequence_number
    # Gcc
    pheno_ts_df_1day = data.frame()
    pheno_ts_df_3day = data.frame()
    # Transition dates
    pheno_td_df_1day = data.frame()
    pheno_td_df_3day = data.frame()
    print ('this pft')
    print (pft)
    print ('all roi_seq_nums')
    print (roi_seq_num)
    for (seq in roi_seq_num){
      # 1 Day data
      frequency_ = 1
      # Download 1 day gcc data
      day1_df = phenocamapi::get_pheno_ts(name, pft, seq, '1day')
      # Download 1 day gcc transition dates
      url = paste0("https://phenocam.sr.unh.edu/data/archive/", name, "/ROI/", name,"_", pft, "_", seq, "_", frequency_,"day_transition_dates.csv")
      print (url)
      url_data = as.data.frame(data.table::fread(url), stringsAsFactors = FALSE)
      day1_tds_df = subset(url_data, url_data$gcc_value == metrics_)
      
      if (length(pheno_ts_df_1day)==0){
        pheno_ts_df_1day = day1_df
        pheno_td_df_1day = day1_tds_df
      }else {
        pheno_ts_df_1day = rbind(pheno_ts_df_1day, day1_df)
        pheno_td_df_1day = rbind(pheno_td_df_1day, day1_tds_df)
      }
      
      # 3 Day data
      frequency_ = 3
      # Download 3 day gcc data
      day3_df = phenocamapi::get_pheno_ts(name, pft, seq, '3day')
      # Download 3 day gcc transition dates
      url = paste0("https://phenocam.sr.unh.edu/data/archive/", name, "/ROI/", name,"_", pft, "_", seq, "_", frequency_,"day_transition_dates.csv")
      print (url)
      url_data = as.data.frame(data.table::fread(url), stringsAsFactors = FALSE)
      day3_tds_df = subset(url_data, url_data$gcc_value == metrics_)
      if (length(pheno_ts_df_3day)==0){
        pheno_ts_df_3day = day3_df
        pheno_td_df_3day = day3_tds_df
      }else {
        pheno_ts_df_3day = rbind(pheno_ts_df_3day, day3_df)
        pheno_td_df_3day = rbind(pheno_td_df_3day, day3_tds_df)
      }
    }
    
    print ('Smoothing 3day gcc')
    pheno_gcc_3day = smooth_ts(pheno_ts_df_3day, metrics = metrics_, force = TRUE, 3)
    print ('Smoothing 1day gcc')
    pheno_gcc_1day = smooth_ts(pheno_ts_df_1day, metrics = metrics_, force = TRUE, 1)
    
    this_pc_list[paste0(pft,'_tds_3day')] = list(pheno_td_df_3day)
    this_pc_list[paste0(pft,'_gcc_3day')] = list(pheno_gcc_3day)
    this_pc_list[paste0(pft,'_tds_1day')] = list(pheno_td_df_1day)
    this_pc_list[paste0(pft,'_gcc_1day')] = list(pheno_gcc_1day)
    
    # this_pc_list = list(paste0(pft,'_tds_3day') = pheno_td_df_3day, paste0(pft,'_gcc_3day') = pheno_ts_df_3day, 
    #   paste0(pft,'_gcc_1day') = pheno_ts_df_1day, paste0(pft,'_tds_1day') = pheno_td_df_1day)
    all_phenocam_data[pft] = list(this_pc_list)
  }
  return(this_pc_list)
}



#' smooth_ts
#'
#' @param data 
#' @param metrics 
#' @param force 
#' @param frequency 
#' Smoothes ndvi, evi or gccc data  (uses the optimal span function)
#' @return - data
#' 
smooth_ts = function(data,
                     metrics = c("gcc_mean",
                                 "gcc_50",
                                 "gcc_75",
                                 "gcc_90",
                                 "rcc_mean",
                                 "rcc_50",
                                 "rcc_75",
                                 "rcc_90"),
                     force = TRUE, frequency) {
  
  
  
  # split out data from read in or provided data
  df = data
  
  # maximum allowed gap before the whole stretch is
  # flagged as too long to be reliably interpolated
  maxgap = 14
  
  # create convenient date vector
  # (static for all data)
  dates = as.Date(df$date)
  
  # create output matrix
  output = matrix(NA, length(dates), length(metrics) * 2 + 1)
  output = as.data.frame(output)
  column_names = c(sprintf("smooth_%s", metrics),
                   sprintf("smooth_ci_%s", metrics),
                   "int_flag")
  colnames(output) = column_names
  
  # loop over all metrics that need smoothing
  for (i in metrics) {
    
    # get the values to use for smoothing
    v=is.element(colnames(df), i)
    values = df[, ..v]
    
    # flag all outliers as NA
    # if the metric is gcc based
    if (grepl("gcc", i)) {
      outliers = df[, which(colnames(df) == sprintf("outlierflag_%s", i))]
      values[outliers == 1] = NA
    }
    
    # create yearly mean values and fill in time series
    # with those, keep track of which values are filled
    # using the int_flag data
    nr_years = length(unique(df$year))
    
    # find the location of the original NA values
    # to use to fill these gaps later
    na_orig = which(is.na(values))
    
    # na locations (default locations for 3-day product)
    # this to prevent inflation of the number of true
    # values in the 3-day product
    loc = seq(2,366,3)
    loc = (df$doy %in% loc)
    
    # Calculate the locations of long NA gaps.
    # (find remaining NA values after interpolation,
    # limited to 2 weeks in time)
    long_na = which(is.na(zoo::na.approx(
      values, maxgap = maxgap, na.rm = FALSE
    )))
    
    # also find the short gaps (inverse long gaps)
    # to smooth spikes
    short_na = which(!is.na(zoo::na.approx(
      values, maxgap = maxgap, na.rm = FALSE
    )))
    short_na = which(short_na %in% is.na(values))
    
    # this routine takes care of gap filling large gaps
    # using priors derived from averaging values across
    # years or linearly interpolating. The averaging over
    # years is needed to limit artifacts at the beginning
    # and end of cycles in subsequent phenophase extraction
    if (nr_years >= 2) {
      
      # used to be 3, fill values using those of the remaining year
      
      # calculate the mean values for locations
      # where there are no values across years
      fill_values = by(values,INDICES = df$doy, mean, na.rm = TRUE)
      doy_fill_values = as.numeric(names(fill_values))
      #doy_na = df$doy[na_orig]
      doy_na = df$doy[long_na]
      
      # calculate the interpolated data based on
      # the whole dataset
      int_data = unlist(lapply(doy_na,
                               function(x,...) {
                                 fv = fill_values[which(doy_fill_values == x)]
                                 if (length(fv) == 0) {
                                   return(NA)
                                 }else{
                                   return(fv)
                                 }
                               }))
      
      # gap fill the original dataset using
      # the interpolated values
      gap_filled_prior = values
      #gap_filled_prior[na_orig] = int_data
      gap_filled_prior[long_na] = int_data
      
      # reset NA short sections to NA and interpolate these linearly
      # only long NA periods merit using priors
      gap_filled_prior[short_na] = NA
      gap_filled_linear = zoo::na.approx(gap_filled_prior, na.rm = FALSE)
      
      # the above value should be independent of the ones used in the carry
      # forward / backward exercise
      
      # traps values stuck at the end in NA mode, use carry
      # forward and backward to fill these in! These errors
      # don't pop up when using a fitting model (see above)
      gap_filled_forward = zoo::na.locf(gap_filled_linear,
                                        na.rm = FALSE)
      gap_filled_backward = zoo::na.locf(gap_filled_linear,
                                         na.rm = FALSE,
                                         fromLast = TRUE)
      
      # drop in values at remaining NA places
      gap_filled_forward[is.na(gap_filled_forward)] = gap_filled_backward[is.na(gap_filled_forward)]
      gap_filled_backward[is.na(gap_filled_backward)] = gap_filled_forward[is.na(gap_filled_backward)]
      
      # take the mean of the carry forward and backward run
      # this should counter some high or low biases by using the
      # average of last or first value before or after an NA stretch
      gap_filled_linear = ( gap_filled_forward + gap_filled_backward ) / 2
      gap_filled = apply(cbind(gap_filled_prior,gap_filled_linear),1,max,na.rm=TRUE)
      
    }else{
      
      # for short series, where averaging over years isn't possible
      # linearly interpolate the data for gap filling
      # it's not ideal (no priors) but the best you have
      gap_filled = zoo::na.approx(values, na.rm = FALSE)
      
      # traps values stuck at the end in NA mode, use carry
      # forward and backward to fill these in! These errors
      # don't pop up when using a fitting model (see above)
      gap_filled = zoo::na.locf(gap_filled, na.rm = FALSE)
      gap_filled = zoo::na.locf(gap_filled, na.rm = FALSE, fromLast = TRUE)
    }
    
    # the gap_filled object is used in the subsequent analysis
    # to calculate the ideal fit, down weighing those areas
    # which were interpolated
    
    # create weight vector for original NA
    # values and snow flag data
    weights = rep(1,nrow(values))
    weights[na_orig] = 0.001
    #weights[df$snow_flag == 1] = 0.001
    
    # smooth input series for plotting
    # set locations to NA which would otherwise not exist in the
    # 3-day product, as not to inflate the number of measurements
    if (frequency == 3){
      
      optim_span = suppressWarnings(
        optimal_span(x = as.numeric(dates[loc]),
                     y = gap_filled[loc],
                     plot = FALSE))
      
      fit = suppressWarnings(
        stats::loess(gap_filled[loc] ~ as.numeric(dates[loc]),
                     span = optim_span,
                     weights = weights[loc]))
      
    } else { # 1-day product
      
      optim_span = suppressWarnings(
        optimal_span(x = as.numeric(dates),
                     y = gap_filled,
                     plot = FALSE))
      
      fit = suppressWarnings(
        stats::loess(gap_filled ~ as.numeric(dates),
                     span = optim_span,
                     weights = weights))
      
    }
    
    # make projections based upon the optimal fit
    fit = suppressWarnings(stats::predict(fit, as.numeric(dates), se = TRUE))
    
    # grab the smoothed series and the CI (from SE)
    # set to 0 if no SE is provided
    values_smooth = fit$fit
    
    # calculate the CI (from SE)
    values_ci = 1.96 * fit$se
    
    # cap CI values to 0.02
    values_ci[values_ci > 0.02] = 0.02
    
    # trap trailing and starting NA values
    values_smooth = zoo::na.locf(values_smooth,
                                 na.rm=FALSE)
    values_smooth = zoo::na.locf(values_smooth,
                                 fromLast = TRUE,
                                 na.rm=FALSE)
    
    # set values for long interpolated values to 0
    # these are effectively missing or inaccurate
    # (consider setting those to NA, although this
    # might mess up plotting routines)
    values_ci[long_na] = 0.02
    
    # trap values where no CI was calculated and
    # assign the fixed value
    values_ci[is.nan(fit$se)] = 0.02
    values_ci[is.na(fit$se)] = 0.02
    values_ci[is.infinite(fit$se)] = 0.02
    
    # set values to NA if interpolated
    # max gap is 'maxgap' days, to avoid flagging periods where
    # you only lack some data
    # this is redundant should only do this once (fix)
    int = zoo::na.approx(values, maxgap = maxgap, na.rm = FALSE)
    
    # put everything in the output matrix
    output$int_flag[which(is.na(int))] = 1
    output[, which(colnames(output) == sprintf("smooth_%s", i))] = round(values_smooth,5)
    output[, which(colnames(output) == sprintf("smooth_ci_%s", i))] = round(values_ci,5)
    
    cols = rep("red",length(gap_filled))
    cols[long_na] = "green"
  }
  
  # drop previously smoothed data from
  # a data frame
  # dropvar = is.element(names(df), column_names)  #maybe break here
  # df = df[,!dropvar]
  df = cbind(df, output)
  
  # put data back into the data structure
  data= df
  
  # write the data to the original data frame or the
  # original file (overwrites the data!!!)
  
  return(data) #data,
}










#' optimal_span
#'
#' @param y 
#' @param x 
#' @param weights 
#' @param step 
#' @param label 
#' @param plot 
#' Calculates optimal span for smooth
#' @return check if the fit failed if so return NA else return myAIC(fit)
#' 
optimal_span = function(y,
                        x = NULL,
                        weights = NULL,
                        step = 0.01,
                        label = NULL,
                        plot = FALSE){
  
  # custom AIC function which accepts loess regressions
  myAIC = function(x){
    
    if (!(inherits(x, "loess"))){
      stop("Error: argument must be a loess object")
    }
    
    # extract loess object parameters
    n = x$n
    traceL = x$trace.hat
    sigma2 = sum( x$residuals^2 ) / (n-1)
    delta1 = x$one.delta
    delta2 = x$two.delta
    enp = x$enp
    
    # calculate AICc1
    # as formulated by Clifford M. Hurvich; Jeffrey S. Simonoff; Chih-Ling Tsai (1998)
    AICc1 = n*log(sigma2) + n* ( (delta1/delta2)*(n+enp) / ((delta1^2/delta2)-2))
    
    if(is.na(AICc1) | is.infinite(AICc1)){
      return(NA)
    }else{
      return(AICc1)
    }
  }
  
  # create numerator if there is none
  if (is.null(x)){
    x = 1:length(y)
  }
  
  # return AIC for a loess function with a given span
  loessAIC = function(span){
    # check if there are weights, if so use them
    if ( is.null(weights) ){
      fit = suppressWarnings(try(stats::loess(y ~ as.numeric(x),
                                              span = span),
                                 silent = TRUE))
    } else {
      fit = suppressWarnings(try(stats::loess(y ~ as.numeric(x),
                                              span = span,
                                              weights = weights),
                                 silent = TRUE))
    }
    
    # check if the fit failed if so return NA
    if (inherits(fit, "try-error")){
      return(NA)
    }else{
      return(myAIC(fit))
    }
  }
  
  # parameter range
  span = seq(0.01, 1, by = step)
  
  # temporary AIC matrix, lapply loop
  # (instead of for loop) cleaner syntax
  tmp = unlist(lapply(span, loessAIC))
  
  # find the optimal span as the minimal AICc1 value
  # in the calculated range (span variable)
  opt_span = span[which(tmp == min(tmp, na.rm = TRUE))][1]
  
  # plot the optimization if requested
  if (plot == TRUE){
    
    graphics::par(mfrow = c(2,1))
    plot(as.numeric(x),y,
         xlab = 'value',
         ylab = 'Gcc',
         type = 'p',
         pch = 19,
         main = label)
    
    col = grDevices::rainbow(length(span),alpha = 0.5)
    
    for (i in 1:length(span)){
      fit = stats::loess(y ~ as.numeric(x),
                         span = span[i])
      graphics::lines(fit$x,
                      fit$fitted,
                      lwd = 1,
                      col = col[i])
    }
    
    fit = stats::loess(y ~ as.numeric(x),
                       span = opt_span)
    
    graphics::lines(fit$x,
                    fit$fitted,
                    lwd = 3,
                    col = 'black',
                    lty = 1)
    
    plot(span,
         tmp,
         pch = 19,
         type = 'p',
         ylab = 'AICc1',
         col = col)
    
    graphics::abline(v = opt_span,col = 'black')
    
  }
  
  # trap error and return optimal span
  if (is.na(opt_span)) {
    return(NULL)
  } else {
    return(opt_span)
  }
}