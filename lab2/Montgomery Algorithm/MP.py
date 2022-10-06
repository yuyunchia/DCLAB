

def mont_preprocess(a, n):
    """return a*2^(256) % n"""
    for i in range(256):
        a <<= 1
        if a >= n:
            a -= n
    # or, equivalent to this
    # return (a<<256)%n
    return a







N = 3901
a = 2



"""
"""

"""
MA(a, N)  = (   722,  3901) => 794
MA(a, N)  = (  1583,  3901) => 3405
MA(a, N)  = (    26,  3901) => 396
MA(a, N)  = (     2,  3901) => 2131
"""


print(f"MP(a={a}, N={N}): {mont_preprocess(a, N)}")



