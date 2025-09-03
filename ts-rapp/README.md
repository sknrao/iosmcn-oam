# Traffic Steering rApp

This directory includes support stuff and implementation of TS-rApp, but without the actual traffic steering algorithm that computes offset values. Such algorithm was used, but since was proprietary, couldn't be included.

Implementation can work in two modes: 1) with Viavi simulator 2) with O1 IF simulator ([link](https://github.com/o-ran-sc/sim-o1-ofhmp-interfaces)). It can be switched by USE_O1_SIMULATOR env variable. However, the 2) was not tested for some time, thus it is possible it would require some adjustments.

File main.py hold the implementation. For it to be functional, one needs to provide an algorithm for offset computation. See TODO at the top of the file.