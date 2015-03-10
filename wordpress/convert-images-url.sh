#!/bin/bash
for f in _posts/*.html; do
 mv $f $f.old
 sed 's/https:\/\/vdupain\.files\.wordpress\.com\/[0-9]*\/[0-9]*/\{\{ site.url \}\}\/assets/g' $f.old > $f
 #src="assets
 mv $f $f.old
 sed 's/src=\"assets/src=\"\{\{ site.url \}\}\/assets/g' $f.old > $f
 rm -f $f.old
done
