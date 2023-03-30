{
	if(length($2) < 2) second="00"$2       #Do the same thing for the third field.
	
	else if(length($2) < 3)second="0"$2
	
	else second=$2
	
	print $1,second               #prints new columns in the correct order with columns 2 and 4.
}
