#!/bin/sh
set -e
dirname "$(dirname "$(readlink -f "$(which javac || which java)")")";
