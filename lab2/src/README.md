RSACore256 testbench guideline
===

## TAs have provide tb.sv for testing.

## But if you want to test Rsa256Core.sv with some simple data, using tb_yu.sv


### To generate test data
```
cd ./src/pc_python 
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

Since in tb_yu, the value of N, d are determined(N=3901, 3),
You can modify value of d to generate other test data

Suppose that :
RSA256MONT(N=3901, y=   8, d=3):  512
RSA256MONT(N=3901, y=  19, d=3): 2958
RSA256MONT(N=3901, y=3577, d=3):  595

Then edit following file in ./src/pc_python/golden
e_yu.txt(value of y)    d_yu.txt(value of y^d mod N)
8                       512        
19                      2958          
3577                    595
```
### To run testbench
```
cd ./src/tb_verilog

for tb_yu.sv: 
ncverilog tb_yu.sv Rsa256Core.sv +access+r

for tb.sv: 
ncverilog tb.sv Rsa256Core.sv +access+r
``` 