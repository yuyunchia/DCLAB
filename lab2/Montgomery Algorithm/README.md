Small Module Testbench Guideline
===
## Test MA (MontAlg)
### To generate test data
```
cd ./Montgomery Algotithm
python MA.py
```
```
Terminal will shows something like:

============================================
MP(N, a, b, k):      2451
MA(N, a, b<<256):    517383
MA(N, a<<256, b):    0
MA(N, a, b):         1875
=====================================
EXSQ      (N=3901, y=19, d=3): 2958
RSA256MONT(N=3901, y=19, d=3): 2958
=============================================

You can modify value of N, y, d to generate other test data

Suppose that :
MA(N=    7, a= 2, b= 4):    4 
MA(N=    7, a= 3, b= 5):    4 
MA(N= 1731, a=97, b=57): 1227  

Then edit following file in ./Montgomery Algotithm/golden
n.txt       MA_a.txt,   MA_b.txt,   MA_o.txt
7           2           4           4           
7           3           5           4           
1731        97          57          1227        
```
### To run testbench
```
cd ./Montgomery Algotithm
ncverilog tb_MA.sv MA.sv +access+rw
```

## Test MP 
### To generate test data
```
cd ./Montgomery Algotithm
python MP.py
```
```
Terminal will shows something like:

============================================
MP(a=2, N=3901): 2131
=============================================

You can modify value of N, y, d to generate other test data

Suppose that :
MP(a=2, N=3901): 2131 

Then edit following file in ./Montgomery Algotithm/golden
MP_a.txt    MP_n.txt,   MP_o.txt
2           3901        2131                 
```
### To run testbench
```
cd ./Montgomery Algotithm
ncverilog tb_MP.sv MP.sv +access+rw
``` 












