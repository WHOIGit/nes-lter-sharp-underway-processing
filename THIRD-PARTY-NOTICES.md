# Third-party notices

This repository incorporates third-party software. Each component is listed
below with its origin and license. All are MIT-licensed and compatible with
this repository's own MIT license (see `LICENSE`).

## R/tw.R — COAPS/FSU SAMOS true-wind algorithm

`R/tw.R` is a translation into R of the true-wind computation distributed by
the Center for Ocean-Atmospheric Prediction Studies (COAPS), Florida State
University, as part of the SAMOS initiative.

The original algorithm was developed by Shawn R. Smith and Mark A. Bourassa
and programmed by Mylene Remigio. It was ported from C to MATLAB, then from
MATLAB to Python by David Pablo Cohn (2017), with a later input-length check
added by Homer McMillan (2021). It was translated from that Python reference
implementation to R in 2026 for this repository.

The full provenance chain, including the R translation, is recorded in the
header comment of `R/tw.R`. That header carries the copyright and permission
notice reproduced below and must be retained in any redistribution of the
file.

Licensed as follows:

    Copyright 2021 Florida State University

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to permit
    persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
