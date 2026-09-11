module Hierarchy

nvertices(L::Integer) = 10 * 4^L + 2

children(i::Integer) = (4i - 3):(4i)

end
