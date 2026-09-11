# The array layout convention: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer".

"""
    LAYOUT

The array layout convention every field obeys: cells the first (fastest)
dimension, levels the second, so consecutive threads touch consecutive
addresses with the vertical loop inside the thread (decision 0011). `Fields`
reads this constant rather than restating the convention.
"""
const LAYOUT = (:cells, :levels)
