#!/usr/bin/env bash
######################################################################
# To use this, put the following in your .hg/hgrc with your GOROOT:
#
# [hooks]
# precommit.gofmt = <GOROOT>/misc/hg/hooks/hg-gofmt-precommit.sh
#
# It will not prevent you from committing, it will simply tell you
# how many files are being formatted.
######################################################################

### Get a list of all go source files in the hg repository
GOFILES=`hg st --all | grep '^[MAC].*\.go$' | cut -c 3-`
[[ -z "$GOFILES" ]] && exit 0

### Count how many of these files aren't up to gofmt standard
NEEDFIX=`gofmt -l $GOFILES | wc -l`
[[ $((0+NEEDFIX)) -eq 0 ]] && exit 0

### Format the files that need it
echo "****** Re-formatting $NEEDFIX files ******" >&2
gofmt -w $GOFILES && exit 0

### If we get here, something bad happened.
echo "****** Error running gofmt ******" >&2
exit 1
