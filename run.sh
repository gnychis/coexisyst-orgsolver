#!/bin/bash
./data_translate.rb -d "$1" && zimpl spectrum_optimization.zpl && scip -f spectrum_optimization.lp
