#! /bin/bash
set -x
set -e

DATALOC=$1
SCRPTLOC=$2
DBS=$3

# insert into Student Table 

for file in `ls $DATALOC/Form?.csv`
do
   grep "KEY" $file > Key.csv
   grep -v "KEY" $file > Result.csv

   Rscript FirstConvert.R Result.csv Key.csv qs.RData
   Rscript WidetoLong.R qs.RData Long
   sed 's/\"//g' Long > Students
   awk -F " " -f $SCRPTLOC/insert_template_students.awk Students > read_students.sql

# Take care of the domain link to the file at the same time
   DM_LTR=`basename $file | sed -e 's/.csv//;s/Form//'`
   sed '1d' $DATALOC/Domains_Form$DM_LTR.csv > Domains
   dos2unix Domains
   ./Get_Dm_nam.sh $DM_LTR Domains
   
   cut -d , -f 3,4 Domains | awk -F, -v form=$DM_LTR -f $SCRPTLOC/insert_template_Qust_Cat.awk >> read_students.sql

   mysql $DBS < read_students.sql
done
exit
