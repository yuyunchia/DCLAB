

def MP(N, a, b, k): # Modulo Product
    t = b  
    m = 0
    for i in range(k):
        if (a%2 ==1):
            if (m+t >= N):
                m = m + t - N
            else: 
                m = m + t
        if (t > N): # Added
            t = (2*t)%N
        elif (2*t > N):
            t = 2*t -N
        else: 
            t = 2*t
        a = a >> 1
        
    return m

def MA(N, a, b): # MontAlg
    m = 0
    for i in range(256):
        if (a%2 == 1):
            m = m + b
        if (m%2 == 1):
            m = m + N
        
        m = m >> 1
        a = a >> 1
        # print(m)
    if (m >= N):
        m = m - N
    return m



def EXSQ(N, y, d):
    t = y
    m = 1
    for i in range(256):
        if d%2 == 1:
            m = MP(N, m, t, len(bin(m))-2) # m = m*t mod N
        t = MP(N, t, t, len(bin(t))-2) # t = t^2 mod N
        d = d>>1
    return m

def RSA256MONT(N, y, d):
    t = MP(N, 1<<256, y, 257) # t = y << 256
    # t = MA(N, y, 1<<256) # t = y << 256
    m = 1
    print(f"t:{hex(t)},  {t}")
    for i in range(256):
        if d%2 == 1:
            m = MA(N, m, t)
            print(f"m:{hex(m)},  {m}")
        t = MA(N, t, t)
        print(f"t:{hex(t)},  {t}")
        d = d>>1
        

    return m



N = 7
a = 722
b = 722
k = len(bin(a))-2
# ans = MP(N, a, b, k)
# ans2 = MA(N, a, b, k)
y = 2
d = 5




N = 0xCA3586E7EA485F3B0A222A4C79F7DD12E85388ECCDEE4035940D774C029CF831
d = 0xB6ACE0B14720169839B15FD13326CF1A1829BEAFC37BB937BEC8802FBCF46BD9
y = 89880192937653710598380335437431847203866094229526865542213091600506423557627


"""
if N < t in MP , cause loop

if N is even, cause false

"""

"""


MA(N, a, b)  = (   7,  3,  5 ) => 4
MA(N, a, b)  = (   7,  2,  4 ) => 4
MA(N, a, b)  = (1731, 97, 57 ) => 1227


# (N, y ,d ) = (6 , 7 , 5) wrong
# (N, y ,d ) = (8 , 7 , 5) wrong
# (N, y ,d ) = (10 , 7 , 5) wrong
# (N, y ,d ) = (5 , 7 , 5) wrong loop fix
# (N, y ,d ) = (5 , 6 , 1) wrong loop fix

# (N, y ,d ) = (1741 , 2 , 5) Good
# (N, y ,d ) = (7 , 2 , 5) Good, but MA != MP 
# (N, y ,d ) = (19 , 2 , 5) Good, but MA != MP 

# (N, y, d, a, b) = (1731, 41, 37, 97, 57)
"""

# print("=====================================")
# print(f"MP(N, a, b, k):      {MP(N, a, b, k)}")
# print(f"MA(N, a, b<<256):    {MA(N, a, b<<256)}")
# print(f"MA(N, a<<256, b):    {MA(N, a<<256, b)}")
# print(f"MA(N, a, b):         {MA(N, a, b)}")
print("=====================================")
# print(f"EXSQ      (N={N}, y={y}, d={d}): {EXSQ(N, y, d)}")
# print(f"RSA256MONT(N={N}, y={y}, d={d}): {RSA256MONT(N, y, d)}")

print(hex(RSA256MONT(N, y, d)))


# print(f"n: {int('CA3586E7EA485F3B0A222A4C79F7DD12E85388ECCDEE4035940D774C029CF831',16)}")
# print(f"d: {int('B6ACE0B14720169839B15FD13326CF1A1829BEAFC37BB937BEC8802FBCF46BD9',16)}")


