"""
dtaidistance.dtw_cc_omp
~~~~~~~~~~~~~~~~~~~~~~~

Dynamic Time Warping (DTW), C implementation, with OpenMP support.

:author: Wannes Meert
:copyright: Copyright 2020 KU Leuven, DTAI Research Group.
:license: Apache License, Version 2.0, see LICENSE for details.

"""
from cpython cimport array
import array
from dtw_cc cimport DTWSeriesMatrix, DTWSeriesPointers, DTWSettings, DTWBlock
from dtw_cc import dtw_series_from_data
cimport dtaidistancec
cimport dtaidistancec_omp


def distance_matrix(cur, block=None, **kwargs):
    """Compute a distance matrix between all sequences given in `cur`.
    This method calls a pure c implementation of the dtw computation that
    avoids the GIL.

    Assumes C-contiguous arrays.

    :param cur: DTWSeriesMatrix or DTWSeriesPointers
    :param block: see DTWBlock
    :param kwargs: Settings (see DTWSettings)
    :return: The distance matrix as a list representing the triangular matrix.
    """
    cdef DTWSeriesMatrix matrix
    cdef DTWSeriesPointers ptrs
    cdef int length = 0
    cdef int block_rb=0
    cdef int block_re=0
    cdef int block_cb=0
    cdef int block_ce=0
    cdef ri = 0
    if block is not None and block != 0.0:
        block_rb = block[0][0]
        block_re = block[0][1]
        block_cb = block[1][0]
        block_ce = block[1][1]

    settings = DTWSettings(**kwargs)
    cdef DTWBlock dtwblock = DTWBlock(rb=block_rb, re=block_re, cb=block_cb, ce=block_ce)
    length = dtaidistancec.dtw_distances_length(&dtwblock._block, len(cur))

    cdef array.array dists = array.array('d')
    array.resize(dists, length)

    if isinstance(cur, DTWSeriesMatrix) or isinstance(cur, DTWSeriesPointers):
        pass
    elif cur.__class__.__name__ == "SeriesContainer":
        cur = cur.c_data()
    else:
        cur = dtw_series_from_data(cur)

    if isinstance(cur, DTWSeriesPointers):
        ptrs = cur
        dtaidistancec_omp.dtw_distances_ptrs_parallel(
            ptrs._ptrs, ptrs._nb_ptrs, ptrs._lengths,
            dists.data.as_doubles, &dtwblock._block, &settings._settings)
    elif isinstance(cur, DTWSeriesMatrix):
        matrix = cur
        dtaidistancec_omp.dtw_distances_matrix_parallel(
            &matrix._data[0,0], matrix.nb_rows, matrix.nb_cols,
            dists.data.as_doubles, &dtwblock._block, &settings._settings)

    return dists