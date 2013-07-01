#!/bin/bash

tar xzvf scipoptsuite-3.0.1.tgz -C /opt/src/
cd /opt/src/scipoptsuite-3.0.1
make
make test
make install
cp /opt/src/scipoptsuite-3.0.1/zimpl-3.3.1/bin/zimpl /usr/local/bin/
cp /opt/src/scipoptsuite-3.0.1/soplex-1.7.1/bin/soplex /usr/local/bin/
cp /opt/src/scipoptsuite-3.0.1/scip-3.0.1/bin/scip /usr/local/bin/
