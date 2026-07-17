#!/usr/bin/env Rscript

# Copyright 2021 Florida State University
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

###########################################################################
# Calculate true winds from vessel speed, course and relative wind
#
# These routines will compute meteorological true winds (direction from
# which wind is blowing, relative to true north; and speed relative to
# the fixed earth).
#
# Created: 12/17/96
# Comments updated: 10/01/97
# Last updated:  4/12/2021
# Developed by: Shawn R. Smith and Mark A. Bourassa
# Programmed by: Mylene Remigio
# Converted to Matlab from C true wind computation code truewind.c .
# Converted to python from Matlab with SMOP 0.1
# Direct questions to:  samos@coaps.fsu.edu
#
# 9/30/2014 : If the true wind has speed and its coming from the north
#	      then its direction should be 360deg. The problem was fixed
#	      in which the program's output showed 0deg instead of 360deg.
# 8/08/2017 : Converted from Matlab to python by David Pablo Cohn
#             (david.cohn@gmail.com); verified on python 2.7-3.5
# 4/12/2021 : Added a check to ensure the input lists to truewinds() have the
#             same length. Change made by Homer McMillan (hmcmillan@coaps.fsu.edu)
# 2026      : Converted from python to R using Claude Code with Opus 4.8
#             contact: (jfutrelle@whoi.edu)

DEFAULT_ZLR <- 0.0  # clockwise angle between bow and anemometer reference line
DEFAULT_MISSING_VALUES <- c(-1111.0,  # missing val for course_over_ground
                            -9999.0,  # missing val for speed_over_ground
                            1111.0,   # missing val for wind_dir
                            9999.0,   # missing val for wind_speed
                            5555.0)   # missing val for heading

###########################################################################
# FUNCTION truew() - calculates true winds from vessel speed, course and
# relative wind
#
# INPUTS
#
# crse	real	Course TOWARD WHICH the vessel is moving over
#			the ground. Referenced to true north and the
#                       fixed earth.
# cspd	real	Speed of vessel over the ground. Referenced
#			to the fixed earth.
# hd	real	Heading toward which bow of vessel is pointing.
#			Referenced to true north.
# zlr	real		Zero line reference -- angle between bow and
#			zero line on anemometer.  Direction is clockwise
#			from the bow.  (Use bow=0 degrees as default
#			when reference not known.)
# wdir 	real	Wind direction measured by anemometer,
#			referenced to the ship.
# wspd	real	Wind speed measured by anemometer, referenced to
#			the vessel's frame of reference.
# wmis	real	Five element array containing missing values for
#			crse, cspd, wdir, wspd, and hd. In the output,
#                       the missing value for tdir is identical to the
#                       missing value specified in wmis for wdir.
#                       Similarly, tspd uses the missing value assigned
#			to wmis for wspd.
#
# *** WDIR MUST BE METEOROLOGICAL (DIRECTION FROM)! CRSE AND CSPD MUST
#     BE RELATIVE TO A FIXED EARTH! ***
#
# OUTPUT VALUES (named list):
#
# tdir	real	True wind direction - referenced to true north
#                       and the fixed earth with a direction from which
#			the wind is blowing (meteorological).
# tspd	real	True wind speed - referenced to the fixed earth.
# adir	real	Apparent wind direction (direction measured by
#			wind vane, relative to true north). IS
#                       REFERENCED TO TRUE NORTH & IS DIRECTION FROM
#                       WHICH THE WIND IS BLOWING. Apparent wind
#			direction is the sum of the ship relative wind
#                       direction (measured by wind vane relative to the
#                       bow), the ship's heading, and the zero-line
#			reference angle.  NOTE:  The apparent wind speed
#			has a magnitude equal to the wind speed measured
#		  	by the anemometer.
#
# DIAGNOSTIC OUTPUT:
#
# nw	integer		Number of observation times for which tdir and
#                       tspd were calculated (without missing values)
# nwpm	integer		Number of observation times with some values
#  			(crse, cspd, wdir, wspd, hd) missing.  tdir,
#			tspd set to missing value.
# nwam	integer		Number of observation times with all values
#  			(crse, cspd, wdir, wspd, hd) missing. tdir,
#			tspd set to missing value.
# nwf	integer		Number of observation times where the program
#			fails -- at least one of the values (crse, cspd,
#			wdir, wspd, hd) is invalid

truew <- function(crse, cspd, wdir, zlr = DEFAULT_ZLR, hd, wspd,
                  wmis = DEFAULT_MISSING_VALUES) {
  # INITIALIZE VARIABLES
  adir <- 0
  nw <- 0
  nwam <- 0
  nwpm <- 0
  nwf <- 0
  dtor <- pi / 180

  # Check course, ship speed, heading, wind direction, and
  # wind speed for valid values (i.e. neither missing nor
  # outside physically acceptable ranges).
  if (((crse < 0 || crse > 360) && crse != wmis[1]) ||
      (cspd < 0 && cspd != wmis[2]) ||
      ((wdir < 0 || wdir > 360) && wdir != wmis[3]) ||
      (wspd < 0 && wspd != wmis[4]) ||
      ((hd < 0 || hd > 360) && hd != wmis[5])) {
    # When some or all of input data fails range check, true
    # winds are set to missing. Step index for input
    # value(s) being out of range
    nwf <- nwf + 1
    tdir <- wmis[3]
    tspd <- wmis[4]
    if (crse != wmis[1] && cspd != wmis[2] && wdir != wmis[3] &&
        wspd != wmis[4] && hd != wmis[5]) {
      # Step index for all input values being non-missing
      nw <- nw + 1
    } else if (crse != wmis[1] || cspd != wmis[2] || wdir != wmis[3] ||
               wspd != wmis[4] || hd != wmis[5]) {
      # Step index for part of input values being missing
      nwpm <- nwpm + 1
    } else {
      # Step index for all input values being missing
      nwam <- nwam + 1
    }
  } else {
    # When course, ship speed, heading, wind direction, and wind speed
    # are all in range and non-missing, then compute true winds.
    if (crse != wmis[1] && cspd != wmis[2] && wdir != wmis[3] &&
        wspd != wmis[4] && hd != wmis[5]) {
      nw <- nw + 1
      # Convert from navigational coordinates to
      # angles commonly used in mathematics
      mcrse <- 90 - crse
      # Keep the value between 0 and 360 degrees
      if (mcrse <= 0.0) {
        mcrse <- mcrse + 360.0
      }
      # Check zlr for valid value.  If not valid, set equal to 0
      if (zlr < 0.0 || zlr > 360.0) {
        zlr <- 0.0
      }
      # Calculate apparent wind direction
      adir <- hd + wdir + zlr
      # Keep adir between 0 and 360 degrees
      while (adir >= 360.0) {
        adir <- adir - 360.0
      }

      # Convert from meteorological coordinates to angles
      # commonly used in mathematics
      mwdir <- 270.0 - adir
      # Keep mwdir between 0 and 360 degrees
      if (mwdir <= 0.0) {
        mwdir <- mwdir + 360.0
      }
      if (mwdir > 360.0) {
        mwdir <- mwdir - 360.0
      }
      # Determine the east-west vector component and the
      # north-south vector component of the true wind
      x <- wspd * cos(mwdir * dtor) + cspd * cos(mcrse * dtor)
      y <- wspd * sin(mwdir * dtor) + cspd * sin(mcrse * dtor)
      # Use the two vector components to calculate the true wind
      # speed
      tspd <- sqrt(x * x + y * y)
      calm_flag <- 1
      # Determine the angle for the true wind
      if (abs(x) > 1e-05) {
        mtdir <- atan2(y, x) / dtor
      } else if (abs(y) > 1e-05) {
        mtdir <- 180.0 - (90.0 * y) / abs(y)
      } else {
        # The true wind speed is essentially zero: winds
        # are calm and direction is not well defined
        mtdir <- 270.0
        calm_flag <- 0
      }
      # Convert from the common mathematical angle coordinate to
      # the meteorological wind direction
      tdir <- 270.0 - mtdir
      # Make sure that the true wind angle is between
      # 0 and 360 degrees
      while (tdir < 0.0) {
        tdir <- (tdir + 360.0) * calm_flag
      }

      while (tdir > 360.0) {
        tdir <- (tdir - 360.0) * calm_flag
      }

      # Ensure wmo convention for tdir = 360 for wind
      # from north and tspd > 0
      if (calm_flag == 1 && tdir < 0.0001) {
        tdir <- 360.0
      }
    } else if (crse != wmis[1] || cspd != wmis[2] || wdir != wmis[3] ||
               wspd != wmis[4] || hd != wmis[5]) {
      nwpm <- nwpm + 1
      tdir <- wmis[3]
      tspd <- wmis[4]
    } else {
      # When course, ship speed, apparent direction, and
      # wind speed are all in range but all of these input
      # values are missing, then set true wind direction and
      # speed to missing.
      nwam <- nwam + 1
      tdir <- wmis[3]
      tspd <- wmis[4]
    }
  }

  list(tdir = tdir, tspd = tspd, adir = adir,
       nw = nw, nwam = nwam, nwpm = nwpm, nwf = nwf)
}

###########################################################################
###########################################################################
# FUNCTION truewinds() - calculates true winds for a vector of inputs
#
# INPUT VALUES:
#
# sel	integer		Sets option for diagnostic output.  There are
#			four settings:
#
#			Option 4:  Calculates true winds from input
#				   arrays with no diagnostic output or
#				   warnings. NOT RECOMMENDED.
#			Option 3:  [DEFAULT] Diagnostic output lists the
#                                  array index and corresponding
#				   variables that either violate the
#    				   range checks or are equal to the
#				   missing value. An additional table
#                                  lists the number of observation times
#                                  with no missing values, some (but not
#				   all)  missing values, and all missing
#				   values; as well as similar totals for
#				   the observation times that fail the
#				   range checks. Range checks identify
#				   negative input values and verify
#				   directions to be between 0 and 360
#				   degrees.
#			Option 2:  In addition to the default
#				   diagnostics (option 3), a table of
#				   all input and output values for
#				   observation times with missing data
#                                  is provided.
#			Option 1:  Full diagnostics -- In addition to
#				   the diagnostics provided by option 2
#				   and 3, a complete data chart is
#                                  output. The table contains input and
#                                  output values for all observation
#                                  times passed to truewind.
#
# crse	real vector	Course TOWARD WHICH the vessel is moving over
#			the ground. Referenced to true north and the
#                       fixed earth.
# cspd	real vector	Speed of vessel over the ground. Referenced
#			to the fixed earth.
# hd	real vector	Heading toward which bow of vessel is pointing.
#			Referenced to true north.
# zlr	real		Zero line reference -- angle between bow and
#			zero line on anemometer.  Direction is clockwise
#			from the bow.  (Use bow=0 degrees as default
#			when reference not known.)
# wdir 	real vector	Wind direction measured by anemometer,
#			referenced to the ship.
# wspd	real vector	Wind speed measured by anemometer, referenced to
#			the vessel's frame of reference.
# wmis	real vector	Five element array containing missing values for
#			crse, cspd, wdir, wspd, and hd.
#
# OUTPUT VALUES (named list): tdir, tspd, adir (vectors) and the
# diagnostic counts nw, nwam, nwpm, nwf.
###########################################################################
###########################################################################

truewinds <- function(sel, crse, cspd, wdir, zlr, hd, wspd, wmis) {
  # INITIALIZE VARIABLES
  n <- length(crse)
  tdir <- numeric(n)
  tspd <- numeric(n)
  adir <- numeric(n)
  nw <- 0
  nwam <- 0
  nwpm <- 0
  nwf <- 0

  if (!all(vapply(list(cspd, wdir, hd, wspd), length, integer(1)) == n)) {
    stop("All input vectors must have the same length!")
  }

  for (i in seq_len(n)) {
    res <- truew(crse = crse[i], cspd = cspd[i], wdir = wdir[i], zlr = zlr,
                 hd = hd[i], wspd = wspd[i], wmis = wmis)
    tdir[i] <- res$tdir
    tspd[i] <- res$tspd
    adir[i] <- res$adir
    nw <- nw + res$nw
    nwam <- nwam + res$nwam
    nwpm <- nwpm + res$nwpm
    nwf <- nwf + res$nwf
  }

  #   OUTPUT SELECTION PROCESS
  if (identical(sel, 1) || identical(sel, 1L)) {
    full(crse, cspd, wdir, zlr, hd, adir, wspd, tdir, tspd)
    missing_values(crse, cspd, wdir, hd, wspd, tdir, tspd, wmis)
    truerr(crse, cspd, hd, wdir, wspd, wmis, nw, nwpm, nwam, nwf)
  } else if (identical(sel, 2) || identical(sel, 2L)) {
    missing_values(crse, cspd, wdir, hd, wspd, tdir, tspd, wmis)
    truerr(crse, cspd, hd, wdir, wspd, wmis, nw, nwpm, nwam, nwf)
  } else if (identical(sel, 3) || identical(sel, 3L)) {
    truerr(crse, cspd, hd, wdir, wspd, wmis, nw, nwpm, nwam, nwf)
  } else {
    cat("Selection not valid. Using selection #3 by default. \n")
    truerr(crse, cspd, hd, wdir, wspd, wmis, nw, nwpm, nwam, nwf)
  }

  list(tdir = tdir, tspd = tspd, adir = adir,
       nw = nw, nwam = nwam, nwpm = nwpm, nwf = nwf)
}

###########################################################################
###########################################################################
# **********************************************************************
#                      OUTPUT SUBROUTINES
# **********************************************************************

# Function:  FULL
#  Purpose:  Produces a complete data table with all values.
#            Accessed only when selection #1 is chosen.

full <- function(crse, cspd, wdir, zlr, hd, adir, wspd, tdir, tspd) {
  cat("\n------------------------------------------------------------------------------------\n\n")
  cat("                                   FULL TABLE\n")
  cat("                                  ************\n")
  cat("  index  course  sspeed  windir  zeroln  shiphd |  appspd |  appdir  trudir  truspd\n")
  for (j in seq_along(tdir)) {
    cat(sprintf("%7d %7.1f %7.1f %7.1f %7.1f %7.1f | %7.1f | %7.1f %7.1f %7.1f\n",
                j, crse[j], cspd[j], wdir[j], zlr, hd[j], wspd[j],
                adir[j], tdir[j], tspd[j]))
  }

  cat("\n                   NOTE:  Wind speed measured by anemometer is identical\n")
  cat("                          to apparent wind speed (appspd).\n")
  cat("\n------------------------------------------------------------------------------------\n\n")
  invisible(NULL)
}

# **********************************************************************
#    Function:  MISSING_VALUES
#    Purpose:  Produces a data table of the data with missing values.
#              Accessed when selection #1 or #2 is chosen.

missing_values <- function(crse, cspd, wdir, hd, wspd, tdir, tspd, wmis) {
  cat("                               MISSING DATA TABLE\n")
  cat("                              ********************\n")
  cat("          index  course  sspeed  windir  shiphd  appspd  trudir  truspd\n")
  for (j in seq_along(tdir)) {
    if (crse[j] != wmis[1] && cspd[j] != wmis[2] && wdir[j] != wmis[3] &&
        wspd[j] != wmis[4] && hd[j] != wmis[5]) {
      next
    }
    cat(sprintf("        %7d %7.1f %7.1f %7.1f %7.1f %7.1f %7.1f %7.1f\n",
                j, crse[j], cspd[j], wdir[j], hd[j], wspd[j], tdir[j], tspd[j]))
  }

  cat("\n------------------------------------------------------------------------------------\n\n")
  invisible(NULL)
}

# **********************************************************************
#    Function:  TRUERR
#    Purpose:  List of where range tests fail and where values are
#               invalid.  Also prints out number of records which are
#               complete, incomplete partially, incomplete entirely, and
#               where range tests fail.  Accessed when selection #1, #2,
#               #3, or the default is chosen.

truerr <- function(crse, cspd, hd, wdir, wspd, wmis, nw, nwpm, nwam, nwf) {
  cat("                               TRUEWINDS ERRORS\n")
  cat("                              ******************\n")
  for (i in seq_along(crse)) {
    if ((crse[i] < 0 || crse[i] > 360) && crse[i] != wmis[1]) {
      cat(sprintf("        Truewinds range test failed.  Course value #%d invalid.\n", i))
    }
    if (cspd[i] < 0 && cspd[i] != wmis[2]) {
      cat(sprintf("        Truewinds range test failed.  Vessel speed value #%d invalid.\n", i))
    }
    if ((wdir[i] < 0 || wdir[i] > 360) && wdir[i] != wmis[3]) {
      cat(sprintf("        Truewinds range test failed.  Wind direction value #%d invalid.\n", i))
    }
    if (wspd[i] < 0 && wspd[i] != wmis[4]) {
      cat(sprintf("        Truewinds range test failed.  Wind speed value #%d invalid.\n", i))
    }
    if ((hd[i] < 0 || hd[i] > 360) && hd[i] != wmis[5]) {
      cat(sprintf("        Truewinds range test failed.  Ship heading value #%d invalid.\n", i))
    }
  }

  cat("\n")
  for (i in seq_along(crse)) {
    if (crse[i] == wmis[1]) {
      cat(sprintf("        Truewinds data test:  Course value #%d missing.\n", i))
    }
    if (cspd[i] == wmis[2]) {
      cat(sprintf("        Truewinds data test:  Vessel speed value #%d missing.\n", i))
    }
    if (wdir[i] == wmis[3]) {
      cat(sprintf("        Truewinds data test:  Wind direction value #%d missing.\n", i))
    }
    if (wspd[i] == wmis[4]) {
      cat(sprintf("        Truewinds data test:  Wind speed value #%d missing.\n", i))
    }
    if (hd[i] == wmis[5]) {
      cat(sprintf("        Truewinds data test:  Ship heading value #%d missing.\n", i))
    }
  }

  cat("\n------------------------------------------------------------------------------------\n\n")
  cat("                                 DATA REVIEW\n")
  cat("                                *************\n")
  cat(sprintf("                            no data missing = %4d\n", nw))
  cat(sprintf("                       part of data missing = %4d\n", nwpm))
  cat(sprintf("                           all data missing = %4d\n", nwam))
  cat(sprintf("                         failed range tests = %4d\n", nwf))
  invisible(NULL)
}
