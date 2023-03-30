#! /bin/bash
set -x

DATALOC=$1
SCRPTLOC=$2
DBS=$3

# Initalize Student Table

echo "USE $DBS;" > read_students.sql
echo "DROP TABLE IF EXISTS Students;" >>read_students.sql

cat $SCRPTLOC/table_schema_students.sql >> read_students.sql
echo "DROP TABLE IF EXISTS Dom_nam;" >>read_students.sql
echo "DROP TABLE IF EXISTS Qust_Cat;" >>read_students.sql
cat $SCRPTLOC/table_schema_domains.sql >> read_students.sql

mysql $DBS < read_students.sql

exit
