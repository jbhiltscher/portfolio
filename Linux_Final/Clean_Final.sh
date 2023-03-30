final_file="Final_Output"
junk_folder="junk"
respace2_installed=0
dos2unix_installed=0
if [ -e "$junk_folder" ]; then
  rm -r "$junk_folder"
  echo " Deleted $junk_folder"
fi
[ -e "$final_file" ] && rm "$final_file"
INDIR=$1
PATTERN=$2
if [ ! -d "$INDIR" ]; then
  echo "No Input Directory"
  exit 1
fi
if [ -z "$PATTERN" ]; then
  echo "No Pattern Provided"
  exit 2
fi
echo " $INDIR/$PATTERN*"
for file in `ls $INDIR/$PATTERN*`
do
echo " $file"
./scripts/Check_config.sh $INDIR `echo "$file" | sed "s|$INDIR/||"`
if [ $? -eq 0 ]; then
    echo "Command found $INDIR and File for $file"
else
    echo "Command Failed for $file"
    if [ $? -eq 1 ]; then
        echo "No Input Directory"
        exit 1
    else
        echo "No Input File in Input Directory"
        exit 2
    fi
fi
echo " myfile $file"
DOMAIN=`echo $file | sed "s/Form/Domains_Form/"`
if [ -z "$DOMAIN" ]; then
  echo "Error: sed command failed or did not produce a result."
  exit 1
fi
echo " $DOMAIN"
grep "KEY" $file > AK
grep -v "KEY" $file > STU
if [ $reshape2_installed=0 ]; then
  if ! Rscript -e 'if (!require("reshape2")) { q(status=1) }' &> /dev/null; then
    echo "reshape2 package not found. Installing..."
    R -e 'install.packages("reshape2")'
    reshape2_installed=1
  else
    echo "reshape2 package already installed."
    reshape2_installed=1
  fi
fi
Rscript FirstConvert.R STU AK FCO
Rscript WidetoLong.R FCO WLO
sed 's/"//g' WLO > NewWLO
awk -f Numeric.awk NewWLO > QS
sed '1d' $DOMAIN > DNH
cut -d $',' -f3,4 DNH > DR
sed 's/,/ /g' DR > spaceDR
if [ $dos2unix_installed=0 ]; then
  if which dos2unix >/dev/null; then
    dos2unix -o spaceDR
    dos2unix_installed=1
  else
    sed -i 's/^M//' spaceDR
    dos2unix_installed=1
  fi
fi
awk -f Numeric_Domain.awk spaceDR >DS
join -1 3 -2 2 -o 1.1,1.2,1.3,2.1,1.4 QS DS >> Final_Output
done
if [ ! -d "$junk_folder" ]; then
  mkdir "$junk_folder"
fi
for file in *; do
  if [ "$file" != "$final_file" ] && [ "$file" != "$1" ] && [ "$file" != "$0" ] && [[ ! "$file" =~ \. ]] && [ "$file" != "$junk_folder" ] && [ "$file" != "scripts" ]; then
    mv "$file" "$junk_folder"
  fi
done
wc Final_Output
