#! /bin/bash
#set -x
DM_LTR=$1
file=$2
#SCRPTLOC=$2


#    DM_LTR=`basename $file | sed -e 's/.csv//;s/Domains_Form//'`
#    sed '1d' $file | cut -d, -f 2,3 | sort |uniq > D_$DM_LTR
    cat $file | cut -d, -f 2,3 | sort |uniq > D_$DM_LTR

#    diff DomMst D_$DM_LTR > Dif_with_mst
#    if ! ( [[ -s D_$DM_LTR ]] && cmp -s DomMst D_$DM_LTR 2>/dev/null 1>&2 )
    if ! ( [[ -s D_$DM_LTR ]] && cmp -s DomMst D_$DM_LTR )
      then
       echo "Categories and Names donot match Master Categories and Names anymore!!!" 
       exit 1001 
    fi
exit

