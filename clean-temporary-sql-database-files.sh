#!/bin/sh

# Clean up temporary databases created by xUnit tests (using SQL Server Express)

echo "BEFORE"
df -h
echo ""
find ~/ -maxdepth 1 -regextype posix-egrep -regex '^.*\/([0-9a-f]){32}(_log.ldf|.mdf)$' -exec rm {} \;
echo "AFTER"
df -h
echo ""
