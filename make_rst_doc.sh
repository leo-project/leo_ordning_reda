#!/bin/sh

rm -rf doc/rst && mkdir doc/rst
make doc
pandoc --read=html --write=rst doc/leo_ordning_reda_api.html -o doc/rst/leo_ordning_reda_api.rst
pandoc --read=html --write=rst doc/leo_ordning_reda_server.html -o doc/rst/leo_ordning_reda_server.rst
