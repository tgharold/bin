#!/bin/sh

BRANCH=master

git fetch upstream && \
git checkout "${BRANCH}" && \
git merge --ff-only "upstream/${BRANCH}" && \
git push origin "${BRANCH}"
