#!/bin/bash

convert original.jpg -resize "1024x500^" -gravity South -crop 1024x500+0+60 +repage scaled.jpg
