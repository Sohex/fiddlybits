# A read one past the end of a three-element array, behind @inbounds. Under
# --check-bounds=auto the annotation stands and the read returns whatever is there;
# under --check-bounds=yes the annotation is overridden and it raises. That difference
# is the whole reason the nightly carries the flag.
#
# A read and not a write: a write past the end is the fault worth catching, and it is
# also the one that corrupts the process running the fixture.

function out_of_range()
    v = [1.0, 2.0, 3.0]
    @inbounds return v[5]
end

out_of_range()
